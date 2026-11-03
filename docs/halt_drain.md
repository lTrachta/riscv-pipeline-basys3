# Paso 16 — HALT y vaciado final del pipeline

## 1. Objetivo

El objetivo de este paso fue incorporar un mecanismo explícito de finalización de programa al procesador RISC-V segmentado.

El trabajo práctico exige que:

- el programa posea una instrucción HALT o equivalente;
- la ejecución pueda finalizar;
- al finalizar, el pipeline se encuentre completamente vacío.

Para cumplir estos requisitos se implementó:

- una codificación propia de HALT;
- detección de HALT en ID;
- una máquina de estados de ejecución;
- detención de nuevos fetches;
- vaciado progresivo de las instrucciones anteriores;
- detección de pipeline vacío;
- prioridad de redirects sobre HALT;
- señalización explícita del estado final HALTED.

---

## 2. Decisión de diseño

Se definió una instrucción propia:

```text
HALT = 32'h0000000B
```

Esta codificación no corresponde a ninguna de las instrucciones soportadas por el subconjunto implementado.

HALT se utiliza exclusivamente como marcador de finalización del programa.

No realiza:

- operaciones de ALU;
- lecturas de memoria;
- escrituras de memoria;
- escrituras en Register File;
- branches;
- jumps.

---

## 3. Por qué HALT no equivale a reset

HALT y reset cumplen funciones diferentes.

Reset lleva el procesador a un estado inicial conocido.

HALT, en cambio:

- termina la ejecución del programa;
- conserva los valores finales del Register File;
- conserva la Data Memory;
- permite consultar posteriormente el estado final mediante la interfaz de debug/UART.

Por lo tanto:

```text
HALT != RESET
```

---

## 4. Detección de HALT

HALT se detecta en la etapa ID.

La condición conceptual es:

```text
halt_in_id =
    if_id_valid &&
    if_id_instruction == HALT
```

No se utiliza IF para aceptar HALT porque las instrucciones presentes en IF pueden pertenecer a un camino especulativo que luego sea descartado por un branch o jump.

---

## 5. Aceptación de HALT

Detectar el patrón de HALT no implica necesariamente aceptarlo.

Se acepta solamente cuando:

```text
estado == RUNNING
&& halt_in_id
&& !redirect_valid
```

Esto permite resolver correctamente el caso:

```text
EX : branch tomado
ID : HALT
```

El branch pertenece a una instrucción más vieja.

Por lo tanto tiene prioridad y el HALT debe ser descartado como una instrucción del camino incorrecto.

---

## 6. Prioridad de control

La prioridad conceptual implementada es:

```text
RESET
>
REDIRECT
>
HALT
>
LOAD-USE STALL
>
NORMAL
```

La relación más importante es:

```text
redirect > HALT
```

Una instrucción más vieja siempre debe poder corregir el flujo antes de aceptar una instrucción más joven.

---

## 7. Estados de ejecución

Se implementó una máquina de estados con tres estados:

```text
RUNNING
DRAINING
HALTED
```

### RUNNING

El procesador ejecuta normalmente.

- se permiten nuevos fetches;
- funcionan stalls;
- funcionan redirects;
- funciona forwarding;
- HALT puede ser detectado y aceptado.

### DRAINING

Se alcanzó y aceptó un HALT válido.

En este estado:

- no entran instrucciones nuevas;
- IF permanece detenido;
- IF/ID queda inválido;
- ID/EX queda inválido;
- las instrucciones anteriores continúan avanzando por EX/MEM/WB.

### HALTED

El HALT ya fue aceptado y todas las instrucciones anteriores finalizaron.

En este estado:

- el pipeline está vacío;
- no se realizan nuevos fetches;
- la ejecución terminó;
- se conserva el estado arquitectónico final.

---

## 8. Transiciones

Las transiciones son:

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

Reset lleva nuevamente a:

```text
RUNNING
```

---

## 9. Vaciado del pipeline

Cuando HALT se encuentra en ID pueden existir instrucciones anteriores en:

```text
EX
MEM
WB
```

Estas instrucciones no pueden descartarse porque pueden tener efectos arquitectónicos pendientes.

Ejemplos:

- una operación ALU todavía debe llegar a WB;
- un load todavía debe escribir su resultado;
- un store todavía debe escribir en Data Memory.

Por este motivo HALT no congela inmediatamente todas las etapas.

En cambio:

```text
se detiene la entrada de instrucciones nuevas
+
las instrucciones anteriores continúan avanzando
```

hasta que desaparece la última instrucción válida.

---

## 10. Tratamiento del propio HALT

HALT no atraviesa el pipeline como una instrucción normal.

Cuando se acepta:

```text
flush_if_id = 1
flush_id_ex = 1
```

Esto provoca:

- eliminación de la instrucción joven que estaba en IF;
- eliminación del propio HALT antes de EX.

No se flushean:

```text
EX/MEM
MEM/WB
```

porque contienen instrucciones anteriores al HALT que deben completar su ejecución.

---

## 11. Cierre del fetch

Durante ejecución normal:

```text
if_enable =
    running &&
    !load_use_stall &&
    !halt_accept
```

Al aceptar HALT, el fetch deja de avanzar.

Durante DRAINING:

```text
running = 0
```

por lo que no se introducen nuevas instrucciones al pipeline.

---

## 12. Pipeline vacío

Se definió:

```text
pipeline_empty =
    !if_id_valid
    &&
    !id_ex_valid
    &&
    !ex_mem_valid
    &&
    !mem_wb_valid
```

Esto indica exclusivamente que no existen instrucciones válidas dentro de los registros del pipeline.

---

## 13. Pipeline vacío no significa programa terminado

Es importante distinguir:

```text
pipeline_empty
```

de:

```text
halted
```

Por ejemplo, inmediatamente después de reset:

```text
pipeline_empty = 1
halted         = 0
```

Por lo tanto el procesador solamente entra en HALTED si previamente pasó por DRAINING.

Conceptualmente:

```text
HALTED =
    HALT previamente aceptado
    &&
    pipeline vacío
```

---

## 14. HALT wrong-path

Se validó específicamente:

```text
EX : BEQ tomado
ID : HALT
```

En este caso:

```text
redirect_valid = 1
halt_accept    = 0
```

El HALT se descarta.

La ejecución continúa desde el target del branch.

Posteriormente, si aparece un HALT válido en el camino correcto, éste sí puede ser aceptado.

---

## 15. Programa sin HALT

Se tomó como decisión de diseño que no existe timeout automático.

Si un programa nunca ejecuta un HALT válido:

```text
running = 1
halted  = 0
```

y el procesador continúa ejecutando.

Esto evita utilizar conceptos ambiguos como "inactividad".

Un programa podría ejecutar legítimamente un loop infinito sin realizar escrituras externas y seguir siendo una ejecución válida.

Por lo tanto, todo programa que deba finalizar debe contener un HALT alcanzable.

---

## 16. Nueva unidad

Se agregó:

```text
rtl/execution_control_unit.sv
```

Responsabilidades:

- detectar HALT;
- aceptar o rechazar HALT;
- administrar RUNNING;
- administrar DRAINING;
- administrar HALTED;
- utilizar pipeline_empty para finalizar el drain.

---

## 17. Cambios en pipeline_core

Se agregaron las salidas:

```text
running
draining
halted
pipeline_empty
```

Estas señales serán útiles posteriormente para:

- UART;
- modo continuo;
- modo paso a paso;
- debug;
- software de control.

También se integró la unidad:

```text
execution_control_unit
```

con los controles existentes de:

- fetch;
- stalls;
- redirects;
- flushes.

---

## 18. Test unitario

Se agregó:

```text
tb/execution_control_unit_tb.sv
```

Resultado:

```text
Tests run    : 17
Tests passed : 17
Tests failed : 0

PASS: execution_control_unit
```

Se validó:

- estado RUNNING después de reset;
- pipeline vacío sin HALT no genera HALTED;
- detección de HALT;
- rechazo de HALT wrong-path;
- prioridad de redirect;
- aceptación de HALT real;
- transición a DRAINING;
- permanencia en DRAINING mientras el pipeline esté ocupado;
- transición a HALTED;
- retorno a RUNNING mediante reset.

---

## 19. Test integrado HALT/drain

Se agregó:

```text
tb/pipeline_core_halt_tb.sv
```

Resultado:

```text
Tests run    : 38
Tests passed : 38
Tests failed : 0

PASS: pipeline_core_halt
```

---

## 20. Validación de drain

Se verificó un programa con:

```text
addi
addi
store
addi
HALT
instrucción posterior
```

Resultados:

- los valores anteriores a HALT fueron escritos correctamente;
- el store anterior a HALT llegó a memoria;
- la instrucción ALU anterior a HALT llegó a WB;
- la instrucción posterior a HALT fue descartada;
- el pipeline terminó completamente vacío.

---

## 21. Validación de HALT wrong-path

Se verificó:

```text
addi
addi
beq tomado
HALT wrong-path
instrucción wrong-path
target
HALT real
```

Resultados:

- se observó el HALT wrong-path;
- no fue aceptado;
- el procesador permaneció RUNNING;
- se realizó el redirect;
- el target se ejecutó;
- posteriormente se aceptó el HALT real;
- el programa terminó correctamente.

---

## 22. Validación de programa sin HALT

También se ejecutó un programa sin HALT.

Después de múltiples ciclos:

```text
running  = 1
draining = 0
halted   = 0
```

confirmando que no existe finalización automática.

---

## 23. Regresión de control hazards

Resultado:

```text
Tests run    : 31
Tests passed : 31
Tests failed : 0
Redirects    : 8
Stalls       : 2

PASS: pipeline_core_control_hazards
```

El nuevo mecanismo de HALT no alteró:

- BEQ;
- BNE;
- JAL;
- JALR;
- flushes;
- forwarding hacia branches/jumps;
- stalls load-use asociados a control.

---

## 24. Regresión de forwarding

Resultado:

```text
Tests run    : 10
Tests passed : 10
Tests failed : 0

PASS: pipeline_core_forwarding
```

---

## 25. Regresión load-use

Resultado:

```text
Tests run    : 22
Tests passed : 22
Tests failed : 0
Stalls       : 4

PASS: pipeline_core_load_use
```

---

## 26. Regresión store forwarding

Resultado:

```text
Tests run    : 12
Tests passed : 12
Tests failed : 0
Stalls       : 1

PASS: pipeline_core_store_forwarding
```

---

## 27. Regresión de memoria

Se verificaron:

- escritura de registros;
- store;
- load;
- resultado final de Data Memory.

Resultado:

```text
PASS: pipeline_core_memory
```

---

## 28. Regresión general del pipeline

El pipeline volvió a alcanzar ocupación completa:

```text
IF
ID
EX
MEM
WB
```

Las cinco instrucciones del test completaron correctamente sus escrituras.

Resultado:

```text
PASS: pipeline_core
```

---

## 29. Resultado final del Paso 16

El procesador ahora puede distinguir correctamente entre:

```text
ejecución normal
final solicitado
pipeline drenándose
ejecución finalizada
```

La política final es:

```text
RUNNING
    |
    | HALT válido en ID
    v
DRAINING
    |
    | todos los valid = 0
    v
HALTED
```

Además:

```text
redirect > HALT
```

y:

```text
pipeline_empty != HALTED
```

si nunca se aceptó previamente una instrucción HALT.

Con esto el procesador cumple el requisito de finalizar un programa dejando el pipeline completamente vacío.
