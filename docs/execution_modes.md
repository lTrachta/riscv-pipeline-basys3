# Modos de ejecución continuo y paso a paso

## 1. Objetivo

El sistema debe permitir controlar la ejecución del procesador de dos formas:

- ejecución continua mediante el comando `RUN`;
- ejecución de exactamente un ciclo del procesador mediante el comando `STEP`.

Al mismo tiempo, el clock físico del sistema no debe ser detenido, modificado ni generado a partir de señales de control provenientes del protocolo UART.

La solución implementada mantiene un único clock limpio para todo el diseño y controla el avance del estado mediante una señal de habilitación denominada:

```text
cycle_enable
```

De esta manera, el clock continúa funcionando permanentemente, mientras que el estado del procesador sólo cambia cuando existe un ciclo de ejecución habilitado.

---

## 2. Por qué no se interviene el clock

Una posible implementación incorrecta sería construir manualmente un nuevo clock a partir del clock original y una señal de ejecución:

```systemverilog
assign cpu_clk = clk & run;
```

Aunque conceptualmente esto parece permitir detener o activar el procesador, no es una solución apropiada para una FPGA.

El clock es una señal especial del sistema y debe distribuirse utilizando los recursos dedicados de clock del dispositivo.

Modificarlo mediante lógica combinacional puede generar problemas como:

- pulsos de clock no deseados;
- glitches;
- diferencias en los tiempos de llegada del clock;
- problemas de timing;
- comportamiento diferente entre simulación y hardware físico.

Por ese motivo, el diseño mantiene:

```text
clk
```

funcionando continuamente.

El control se realiza sobre el avance de los registros:

```systemverilog
always_ff @(posedge clk) begin
    if (reset)
        state <= INITIAL_STATE;
    else if (enable)
        state <= next_state;
end
```

Cuando:

```text
enable = 0
```

el flanco de clock continúa existiendo, pero el registro conserva su valor.

---

## 3. Señal global `cycle_enable`

El procesador recibe una señal:

```text
cycle_enable
```

que determina si durante un determinado flanco debe avanzar el estado del core.

En el controlador del protocolo se genera mediante:

```systemverilog
core_cycle_enable =
    run_active ||
    (state == STATE_STEP_EXECUTE);
```

Por lo tanto existen tres situaciones principales.

### Procesador pausado

```text
run_active = 0
state != STATE_STEP_EXECUTE
```

Entonces:

```text
core_cycle_enable = 0
```

El clock continúa funcionando, pero el procesador permanece congelado.

### STEP

Durante:

```text
STATE_STEP_EXECUTE
```

se genera:

```text
core_cycle_enable = 1
```

durante un único ciclo de ejecución.

Después el controlador vuelve a esperar comandos y:

```text
core_cycle_enable = 0
```

### RUN

Cuando la PC envía el comando `RUN`:

```text
run_active = 1
```

y por lo tanto:

```text
core_cycle_enable = 1
```

de forma continua hasta que el programa alcanza su finalización mediante HALT.

---

## 4. Qué se congela cuando `cycle_enable = 0`

La pausa debe afectar a todo el estado arquitectónico y microarquitectónico del procesador.

No alcanza con detener únicamente el PC.

Cuando:

```text
cycle_enable = 0
```

deben conservarse:

- Program Counter;
- IF/ID;
- ID/EX;
- EX/MEM;
- MEM/WB;
- Register File;
- Data Memory;
- estado de ejecución RUNNING/DRAINING/HALTED.

La lógica del pipeline genera habilitaciones para cada etapa.

Por ejemplo:

```systemverilog
assign if_enable =
    cycle_enable &&
    running &&
    !load_use_stall &&
    !halt_accept;
```

y:

```systemverilog
assign id_enable  = cycle_enable && !halted;
assign ex_enable  = cycle_enable && !halted;
assign mem_enable = cycle_enable && !halted;
```

Además, la escritura del Register File también está condicionada por el ciclo de ejecución:

```systemverilog
assign wb_write_enable =
    wb_write_enable_raw &&
    cycle_enable;
```

Esto evita que una instrucción detenida en MEM/WB vuelva a realizar repetidamente el mismo write-back mientras el procesador está pausado.

Las escrituras en Data Memory también dependen de:

```text
mem_enable
```

por lo que un store detenido en MEM no escribe repetidamente mientras el sistema espera otro comando.

---

## 5. Modo paso a paso

El comando utilizado es:

```text
'S' = 0x53
```

Cuando el controlador recibe un `STEP` válido pasa temporalmente a:

```text
STATE_STEP_EXECUTE
```

Durante ese estado:

```text
core_cycle_enable = 1
```

y el procesador realiza exactamente un ciclo de evolución.

Después se genera:

```text
ACK = 0x06
```

y el controlador vuelve a esperar comandos.

Conceptualmente:

```text
WAIT_COMMAND
     |
     | S
     v
STEP_EXECUTE
     |
     | un ciclo habilitado
     v
WAIT_COMMAND
```

El clock físico nunca se detiene.

---

## 6. STEP representa un ciclo, no una instrucción

Una característica fundamental es que un comando `STEP` representa:

```text
un ciclo del procesador
```

y no:

```text
una instrucción completa
```

Esto es necesario para poder observar el funcionamiento real de un pipeline.

Por ejemplo, una instrucción puede necesitar varios STEP para recorrer:

```text
IF
ID
EX
MEM
WB
```

Además, un STEP puede corresponder a un ciclo donde aparece:

- forwarding;
- un stall;
- una burbuja;
- un flush;
- un redirect;
- draining.

Por lo tanto no se exige que el PC cambie después de cada STEP.

---

## 7. STEP durante un load-use hazard

Consideremos:

```asm
lw  x3, 0(x1)
add x4, x3, x2
```

Cuando el `lw` se encuentra en EX y el `add` dependiente está en ID, aparece un hazard load-use.

La solución requiere:

```text
PC      HOLD
IF/ID   HOLD
ID/EX   BUBBLE
```

durante un ciclo.

Si la ejecución se realiza mediante STEP, ese ciclo también debe existir.

Por lo tanto:

```text
STEP
```

puede producir:

```text
PC antes    = X
PC después  = X
```

sin que eso signifique que el STEP no se ejecutó.

El ciclo fue consumido correctamente por la resolución del hazard.

---

## 8. Problema descubierto al validar STEP

La implementación inicial utilizaba señales combinacionales como:

```text
load_use_stall
redirect_valid
```

directamente para producir flushes y redirects.

Por ejemplo:

```systemverilog
assign flush_id_ex =
    load_use_stall |
    redirect_valid |
    halt_accept;
```

El problema aparece porque:

```text
load_use_stall
```

es combinacional.

Supongamos que después de un STEP el pipeline queda pausado en esta situación:

```text
ID/EX = load
IF/ID = instrucción dependiente
```

Entonces:

```text
load_use_stall = 1
cycle_enable   = 0
```

Aunque el procesador estaba pausado, el clock físico seguía funcionando.

Como `flush_id_ex` permanecía en `1`, el siguiente flanco físico podía convertir ID/EX en una burbuja incluso sin haber recibido otro STEP.

Eso violaba la propiedad fundamental:

```text
cycle_enable = 0
→ el estado del procesador no debe cambiar
```

El mismo problema podía ocurrir con un branch tomado detenido en EX, porque:

```text
redirect_valid = 1
```

podía continuar activo combinacionalmente mientras el procesador estaba pausado.

---

## 9. Señales de control efectivas

Para resolver el problema se separó:

```text
condición combinacional detectada
```

de:

```text
efecto autorizado sobre el estado
```

Se agregaron:

```systemverilog
logic redirect_effective;
logic load_use_stall_effective;
```

con:

```systemverilog
assign redirect_effective =
    cycle_enable &&
    redirect_valid;

assign load_use_stall_effective =
    cycle_enable &&
    load_use_stall;
```

De esta manera puede existir:

```text
load_use_stall = 1
```

mientras el pipeline está pausado, pero:

```text
load_use_stall_effective = 0
```

hasta que llegue un nuevo STEP o se esté ejecutando RUN.

Lo mismo sucede con:

```text
redirect_valid
```

y:

```text
redirect_effective
```

---

## 10. Flushes protegidos por `cycle_enable`

Después de la corrección:

```systemverilog
assign flush_if_id =
    redirect_effective |
    halt_accept;
```

y:

```systemverilog
assign flush_id_ex =
    load_use_stall_effective |
    redirect_effective |
    halt_accept;
```

Esto garantiza que un hazard detectado combinacionalmente no pueda modificar un latch del pipeline mientras:

```text
cycle_enable = 0
```

---

## 11. Redirect protegido durante una pausa

Anteriormente `if_stage` recibía directamente:

```text
redirect_valid
```

La etapa IF contiene la lógica:

```systemverilog
pc_enable =
    if_enable |
    redirect_valid;
```

Por lo tanto un branch tomado detenido en EX podía mantener:

```text
redirect_valid = 1
```

y permitir que el PC se modificara aunque el procesador estuviera pausado.

La integración fue corregida para que IF reciba:

```text
redirect_effective
```

en lugar de:

```text
redirect_valid
```

Por lo tanto:

```text
cycle_enable = 0
redirect_valid = 1
```

produce:

```text
redirect_effective = 0
```

y el PC permanece congelado.

Cuando llega un STEP:

```text
cycle_enable = 1
redirect_valid = 1
```

entonces:

```text
redirect_effective = 1
```

y el redirect se realiza exactamente durante ese ciclo.

---

## 12. `redirect_valid` sigue existiendo

No se reemplazó completamente `redirect_valid`.

La señal original sigue siendo necesaria para describir la condición combinacional real producida por EX.

También es utilizada por la lógica de HALT para resolver correctamente el caso:

```text
EX = branch/jump tomado
ID = HALT
```

Como la instrucción de EX es más vieja, el redirect tiene prioridad y el HALT que estaba en el camino incorrecto no debe ser aceptado.

Por eso la separación queda conceptualmente así:

```text
redirect_valid
      |
      +----> Execution Control
      |      decisión conceptual branch/jump vs HALT
      |
      v
cycle_enable
      |
      v
redirect_effective
      |
      +----> PC
      +----> flush IF/ID
      +----> flush ID/EX
```

---

## 13. Modo continuo

El comando de ejecución continua es:

```text
'R' = 0x52
```

Cuando la PC envía `RUN`, el controlador activa:

```text
run_active = 1
```

Entonces:

```text
core_cycle_enable = 1
```

en todos los ciclos siguientes.

Conceptualmente:

```text
RUN
 |
 v
cycle_enable = 1
 |
 v
clk 1 → ciclo
clk 2 → ciclo
clk 3 → ciclo
clk 4 → ciclo
...
```

No se necesita recibir un nuevo comando por cada ciclo.

El procesador continúa automáticamente hasta alcanzar HALT.

---

## 14. Diferencia entre `run_active` y `core_running`

Estas dos señales representan conceptos diferentes.

### `run_active`

Pertenece al controlador del sistema.

Indica:

```text
la PC solicitó ejecución continua
```

Mientras:

```text
run_active = 1
```

el protocolo mantiene:

```text
core_cycle_enable = 1
```

### `core_running`

Pertenece a la máquina de estados interna del procesador.

Indica que la `execution_control_unit` se encuentra en:

```text
RUNNING
```

Es decir, todavía no se aceptó un HALT.

Por lo tanto pueden existir situaciones como:

```text
run_active   = 0
core_running = 1
```

cuando el procesador está listo para ejecutar pero la PC todavía no solicitó RUN.

También puede existir:

```text
run_active    = 1
core_running  = 0
core_draining = 1
```

después de detectar HALT durante una ejecución continua.

El controlador sigue manteniendo habilitados los ciclos para permitir que el pipeline termine de vaciarse.

---

## 15. Máquina de estados interna del core

La ejecución del procesador utiliza tres estados:

```text
RUNNING
DRAINING
HALTED
```

### RUNNING

El procesador acepta nuevas instrucciones normalmente.

### DRAINING

Ya se aceptó HALT.

No se permite introducir nuevas instrucciones, pero las instrucciones más viejas que ya estaban dentro del pipeline deben terminar.

### HALTED

El pipeline está completamente vacío y la ejecución terminó.

La transición conceptual es:

```text
RUNNING
   |
   | HALT aceptado
   v
DRAINING
   |
   | pipeline_empty
   v
HALTED
```

---

## 16. HALT durante RUN

Durante ejecución continua:

```text
run_active = 1
```

y por lo tanto:

```text
cycle_enable = 1
```

Cuando HALT es aceptado:

```text
RUNNING → DRAINING
```

IF deja de introducir instrucciones nuevas.

Sin embargo, las etapas posteriores continúan avanzando porque todavía existen instrucciones anteriores a HALT.

Por ejemplo:

```text
MEM  = instrucción A
EX   = instrucción B
ID   = HALT
```

Las instrucciones A y B deben completar sus efectos antes de finalizar.

Durante DRAINING:

```text
cycle_enable = 1
```

en modo RUN, así que el pipeline se vacía automáticamente.

Cuando:

```text
IF/ID  valid = 0
ID/EX  valid = 0
EX/MEM valid = 0
MEM/WB valid = 0
```

se obtiene:

```text
pipeline_empty = 1
```

y se alcanza:

```text
HALTED
```

---

## 17. HALT durante STEP

En modo paso a paso el comportamiento es diferente porque después de cada STEP:

```text
cycle_enable = 0
```

Supongamos que un STEP acepta HALT.

El estado pasa:

```text
RUNNING → DRAINING
```

pero las instrucciones anteriores pueden seguir dentro del pipeline.

El procesador queda pausado en DRAINING.

Aunque ocurran muchos clocks físicos:

```text
cycle_enable = 0
```

y por lo tanto el pipeline no continúa vaciándose.

La PC debe enviar nuevos STEP:

```text
STEP
STEP
STEP
...
```

hasta eliminar todas las instrucciones pendientes.

Finalmente:

```text
pipeline_empty = 1
```

y otro ciclo habilitado permite:

```text
DRAINING → HALTED
```

Esto permite observar ciclo por ciclo también el proceso de vaciado final del pipeline.

---

## 18. Estados del sistema y estados del core

El diseño no utiliza una única máquina de estados gigante.

Se separaron dos responsabilidades.

### Controlador del protocolo

Gestiona acciones provenientes de la PC, por ejemplo:

```text
WAIT_COMMAND
LOAD_MODE
STEP_EXECUTE
DEBUG_SNAPSHOT
```

y además mantiene:

```text
run_active
```

### Control de ejecución del core

Gestiona:

```text
RUNNING
DRAINING
HALTED
```

Esta separación permite responder dos preguntas distintas.

El controlador del sistema responde:

```text
¿Qué solicitó la PC?
```

La unidad de ejecución responde:

```text
¿En qué estado interno se encuentra el procesador?
```

---

## 19. Equivalencia con los modos funcionales del sistema

Conceptualmente, los estados requeridos pueden asociarse con nuestra implementación así:

| Función | Implementación |
|---|---|
| Esperando comando | `STATE_WAIT_COMMAND` / `STATUS_READY` |
| Cargando programa | `STATE_LOAD_MODE` / `STATUS_LOADING` |
| Ejecución continua | `run_active = 1` |
| Ejecución de un ciclo | `STATE_STEP_EXECUTE` |
| Vaciado del pipeline | `core_draining = 1` |
| Ejecución terminada | `core_halted = 1` |

No es necesario concentrar todos estos estados dentro de una única FSM, siempre que el comportamiento global sea equivalente y esté correctamente coordinado.

---

## 20. Comandos permitidos durante RUN

Mientras:

```text
run_active = 1
```

el procesador debe continuar avanzando sin que comandos externos modifiquen accidentalmente su estado.

Durante RUN se permite:

```text
Q
```

para consultar el estado.

Otros comandos se rechazan con:

```text
NACK = 0x15
ERR_INVALID_STATE = 0x05
```

Esto evita operaciones incompatibles mientras el procesador está ejecutando continuamente.

---

## 21. Estado consultable mediante `Q`

El comando:

```text
'Q' = 0x51
```

permite recuperar el estado actual.

La respuesta comienza con:

```text
'q' = 0x71
```

seguida por el código de estado.

Los estados definidos son:

| Código | Estado |
|---:|---|
| `0` | READY |
| `1` | LOADING |
| `2` | RUNNING |
| `3` | DRAINING |
| `4` | HALTED |
| `5` | ERROR |

Esto permite que el software de PC sepa en qué condición se encuentra el sistema sin modificar la ejecución.

---

## 22. Relación con Debug Unit

El modo paso a paso resulta especialmente útil en combinación con el comando:

```text
D
```

de Debug Unit.

El flujo esperado desde la futura aplicación de PC será:

```text
STEP
  |
  v
un ciclo del procesador
  |
  v
procesador vuelve a quedar pausado
  |
  v
DEBUG SNAPSHOT
```

Esto permite obtener una fotografía coherente después de cada ciclo.

La PC podrá observar:

- PC actual;
- 32 registros;
- IF/ID;
- ID/EX;
- EX/MEM;
- MEM/WB;
- memoria de datos utilizada;
- estado RUNNING/DRAINING/HALTED;
- estado de ocupación del pipeline.

Así puede seguirse visualmente el movimiento de las instrucciones por las cinco etapas.

---

## 23. Prueba específica de modos de ejecución

Se agregó:

```text
tb/execution_modes_tb.sv
```

El testbench verifica específicamente propiedades que anteriormente estaban cubiertas sólo indirectamente por otras pruebas.

Utiliza el sistema integrado:

```text
processor_system
```

y se comunica mediante UART simulada, de la misma forma que posteriormente lo hará el software de PC.

---

## 24. Prueba de pausa real

Después de cargar un programa se dejan transcurrir:

```text
50 clocks físicos
```

sin enviar RUN ni STEP.

Se comprueba que:

```text
PC = 0
IF/ID inválido
```

antes y después de esos clocks.

Esto demuestra que:

```text
clock funcionando
+
cycle_enable = 0
```

no produce avance del procesador.

---

## 25. Prueba de STEP

Los primeros comandos STEP comprueban que cada comando provoca exactamente un avance.

Por ejemplo:

```text
Estado inicial:
IF PC = 0

STEP 1:
IF PC    = 4
IF/ID PC = 0

STEP 2:
IF PC    = 8
IF/ID PC = 4
ID/EX PC = 0
```

Esto confirma el desplazamiento ciclo por ciclo del pipeline.

---

## 26. Prueba de STEP con load-use

El programa incluye:

```asm
lw  x3, 0(x1)
add x4, x3, x2
```

Cuando aparece el hazard se verifica que un STEP produzca:

```text
IF PC    HOLD
IF/ID    HOLD
ID/EX    BUBBLE
```

mientras el load avanza hacia EX/MEM.

Este test fue el que permitió detectar el bug original producido por señales combinacionales activas durante una pausa.

Después de la corrección, la prueba confirmó que la burbuja aparece únicamente cuando se ejecuta el STEP correspondiente.

---

## 27. Prueba de branch durante STEP

El programa también contiene un branch tomado.

Antes del STEP correspondiente se encuentra:

```text
branch en ID/EX
instrucción wrong-path en IF/ID
```

Después de un único STEP se comprueba:

```text
PC = target
IF/ID inválido
ID/EX inválido
```

y el branch avanza hacia EX/MEM.

Esto demuestra que:

- el redirect ocurre durante el ciclo habilitado;
- los flushes ocurren durante ese mismo ciclo;
- ninguna redirección se produce mientras el sistema está pausado.

---

## 28. Prueba de HALT y DRAINING mediante STEP

El test deja una instrucción más vieja dentro del pipeline cuando HALT es aceptado.

Se comprueba que:

```text
HALT aceptado
→ DRAINING = 1
→ HALTED = 0
```

Después se dejan transcurrir otros:

```text
50 clocks físicos
```

sin enviar STEP.

El sistema permanece:

```text
DRAINING
```

y no llega a HALTED.

Esto demuestra que DRAINING también respeta:

```text
cycle_enable
```

Posteriormente se envían STEP adicionales hasta:

```text
pipeline_empty = 1
```

y finalmente:

```text
HALTED = 1
```

---

## 29. Prueba de eliminación de wrong-path

El programa STEP contiene instrucciones que serían ejecutadas si el branch tomado no produjera correctamente los flushes.

Se utilizan valores:

```text
x5 = 99
x5 = 98
```

en el camino incorrecto.

El destino correcto escribe:

```text
x5 = 7
```

Al terminar se verifica:

```text
x5 = 7
```

confirmando que las instrucciones wrong-path nunca produjeron efectos arquitectónicos.

---

## 30. STEP después de HALT

Una vez alcanzado:

```text
HALTED
```

otro comando:

```text
S
```

es rechazado.

La respuesta esperada es:

```text
NACK
ERR_INVALID_STATE
```

es decir:

```text
15 05
```

Esto evita intentar reanudar mediante STEP un programa que ya terminó.

Para ejecutar nuevamente se deberá realizar una nueva sesión de carga/reprogramación.

---

## 31. Prueba de RUN continuo

La segunda parte del testbench carga un programa con un loop suficientemente largo como para mantener al procesador ejecutándose mientras se realizan consultas UART.

Después de:

```text
R
```

se obtiene:

```text
ACK
```

y el procesador comienza a avanzar continuamente sin nuevos comandos STEP.

---

## 32. Consulta durante RUN

Mientras el programa continúa ejecutándose se envía:

```text
Q
```

y se comprueba:

```text
RESP_STATE = 'q'
STATUS_RUNNING = 2
```

Por lo tanto el sistema permite consultar su estado durante ejecución continua.

---

## 33. Rechazo de comandos incompatibles durante RUN

Durante la misma ejecución se envía:

```text
G
```

La operación es rechazada inmediatamente mediante:

```text
NACK
ERR_INVALID_STATE
```

Esto demuestra que los comandos de inspección que no están habilitados durante RUN no alteran la ejecución.

---

## 34. Finalización automática de RUN

Después de iniciar RUN no se envían comandos STEP.

El procesador continúa por sí solo hasta encontrar HALT.

El test comprueba:

```text
core_halted = 1
pipeline_empty = 1
```

sin intervención adicional desde la PC.

El estado consultado posteriormente es:

```text
HALTED
```

---

## 35. Estado final del programa RUN

El programa utilizado para RUN termina con:

```text
x1 = 0
x2 = 7
```

El snapshot final comprueba ambos valores.

También verifica:

```text
IF/ID  invalid
ID/EX  invalid
EX/MEM invalid
MEM/WB invalid
```

confirmando que el pipeline se encuentra completamente vacío al finalizar.

---

## 36. Resultado del test dedicado

La simulación:

```text
execution_modes_tb
```

finalizó con:

```text
Tests run    : 88
Tests passed : 88
Tests failed : 0
PASS: execution_modes
```

También se verificó:

```text
UART RX frame errors = 0
UART TX frame errors = 0
```

Por lo tanto quedaron validados en una misma prueba integrada:

- pausa real mediante `cycle_enable`;
- STEP de un ciclo;
- múltiples STEP consecutivos;
- load-use durante STEP;
- burbujas;
- redirect y flush durante STEP;
- HALT durante STEP;
- DRAINING controlado mediante STEP;
- pipeline vacío;
- RUN continuo;
- consultas de estado durante RUN;
- rechazo de comandos incompatibles;
- finalización automática mediante HALT;
- UART sin errores de trama.

---

## 37. Regresión completa

Después de modificar la lógica de control del pipeline se ejecutó nuevamente la regresión completa del proyecto.

Resultado:

```text
PASSED: 53
FAILED: 0
TOTAL : 53
```

La prueba incluye tanto los testbenches anteriores como:

```text
execution_modes_tb
```

Por lo tanto la corrección del control de pausa no introdujo regresiones en:

- ALU;
- decode;
- Control Unit;
- forwarding;
- load-use hazards;
- stores;
- loads;
- branches;
- jumps;
- HALT;
- programación dinámica;
- UART;
- protocolo;
- Debug Unit;
- snapshots;
- integración completa del procesador.

---

## 38. Decisiones de diseño

### El clock nunca se gatea manualmente

Se mantiene un único clock físico.

El avance se controla mediante señales de enable.

### STEP representa un ciclo

No representa una instrucción.

Esto permite observar stalls, burbujas, forwarding, flushes y draining exactamente como ocurren en el pipeline.

### RUN mantiene `cycle_enable`

Después de recibir RUN no se requieren comandos adicionales para avanzar.

### DRAINING también necesita ciclos

Aceptar HALT no significa detener instantáneamente todo el pipeline.

Las instrucciones anteriores deben terminar.

### Las señales combinacionales no pueden modificar estado durante una pausa

Se distingue entre:

```text
redirect_valid
load_use_stall
```

y sus efectos habilitados:

```text
redirect_effective
load_use_stall_effective
```

### El protocolo y el estado interno del core están separados

`run_active` representa una decisión del controlador del sistema.

`core_running`, `core_draining` y `core_halted` representan el estado interno de ejecución del procesador.

---

## 39. Resultado final

El sistema permite controlar un procesador RISC-V segmentado sin modificar físicamente su clock.

El comportamiento general es:

```text
                     clock físico
                          |
                          |
                          v
                 siempre funcionando
                          |
                          v
                    cycle_enable
                    /          \
                   /            \
                  v              v
               STEP             RUN
            un ciclo        ciclos continuos
                |                |
                v                v
             pausa             HALT
                                 |
                                 v
                             DRAINING
                                 |
                                 v
                         pipeline_empty
                                 |
                                 v
                              HALTED
```

En modo paso a paso, cada comando UART permite avanzar exactamente un ciclo y luego observar un snapshot coherente del procesador.

En modo continuo, un único comando RUN permite ejecutar el programa completo hasta HALT y vaciar automáticamente el pipeline.

Todo esto se realiza manteniendo el clock físico permanentemente activo y utilizando habilitaciones síncronas para controlar cuándo puede cambiar el estado del procesador.
