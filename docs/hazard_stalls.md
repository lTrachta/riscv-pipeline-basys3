# Hazards de datos, stalls y forwarding de stores

## 1. Objetivo

En esta etapa se incorporó al procesador RISC-V segmentado el tratamiento automático de dependencias de datos que no pueden resolverse únicamente mediante forwarding.

En particular se implementaron:

- detección de hazards `load-use`;
- congelamiento de PC e IF/ID;
- inserción de burbujas en ID/EX;
- forwarding posterior desde MEM/WB hacia EX;
- bypass WB → ID dentro del Register File;
- forwarding especial WB → MEM para datos de instrucciones store;
- optimización del caso `load → store-data`, evitando un stall innecesario.

La arquitectura resultante permite distinguir entre dependencias que requieren detener el pipeline y dependencias que pueden solucionarse únicamente reenviando datos.

---

# 2. Problema del hazard load-use

Considérese:

```asm
lw  x5, 0(x1)
add x6, x5, x2
```

La instrucción `add` necesita el nuevo valor de `x5` en su etapa EX.

Sin stalls:

```text
Ciclo        1     2     3     4     5     6

lw           IF    ID    EX    MEM   WB
add                IF    ID    EX    MEM   WB
```

Durante el ciclo 4 ocurre:

```text
lw  -> MEM
add -> EX
```

El problema es que el dato cargado por `lw` recién aparece durante MEM.

La instrucción `add`, en cambio, necesita ese valor durante EX.

No existe un camino válido que permita enviar un dato producido en MEM hacia una etapa EX que está ocurriendo simultáneamente en ese mismo ciclo.

Por lo tanto, el forwarding normal no alcanza.

---

# 3. Solución mediante un stall de un ciclo

La solución utilizada es detener durante un ciclo las instrucciones jóvenes y permitir que el load continúe avanzando.

El cronograma pasa a ser:

```text
Ciclo        1     2     3     4       5     6     7

lw           IF    ID    EX    MEM      WB
add                IF    ID    ID       EX    MEM   WB
                              STALL
```

En el ciclo del stall:

```text
PC       -> HOLD
IF/ID    -> HOLD
ID/EX    -> BUBBLE
EX/MEM   -> AVANZA
MEM/WB   -> AVANZA
```

La instrucción dependiente permanece en ID.

El load continúa hacia MEM.

Se introduce una burbuja en EX.

Un ciclo después:

```text
lw  -> WB
add -> EX
```

El valor cargado ya está disponible en MEM/WB y puede utilizarse mediante forwarding:

```text
MEM/WB -> EX
```

De esta manera se necesita solamente un ciclo de penalización.

---

# 4. Por qué no se congela ID/EX

Cuando se detecta un load-use hazard no se debe conservar la instrucción actual dentro de ID/EX.

Si ID/EX se congelara:

```text
ID/EX.enable = 0
```

el load permanecería dentro de EX.

La Hazard Detection Unit volvería a detectar exactamente la misma dependencia durante el ciclo siguiente y el pipeline podría quedar detenido indefinidamente.

Por este motivo se utiliza:

```text
IF/ID -> HOLD
ID/EX -> FLUSH
```

El `flush` convierte el contenido nuevo de ID/EX en una burbuja mientras el load anterior puede avanzar normalmente a EX/MEM.

---

# 5. Hazard Detection Unit

Se agregó el módulo:

```text
rtl/hazard_detection_unit.sv
```

Su función es detectar cuándo la instrucción actualmente en EX es un load cuyo registro destino es necesario por la instrucción que se encuentra en ID.

La condición conceptual es:

```text
load_in_ex =
    id_ex_valid
    && id_ex_mem_read
    && id_ex_rd != x0
```

Después se comprueba si el registro destino coincide con alguna fuente realmente utilizada por la instrucción de ID.

Conceptualmente:

```text
hazard_rs1 =
    uses_rs1_ex
    && id_ex_rd == if_id_rs1

hazard_rs2 =
    uses_rs2_ex
    && id_ex_rd == if_id_rs2
```

Finalmente:

```text
stall =
    load_in_ex
    && if_id_valid
    && (hazard_rs1 || hazard_rs2)
```

---

# 6. Uso real de rs1 y rs2

No alcanza con comparar ciegamente los campos físicos `rs1` y `rs2`.

Por ejemplo:

```asm
addi x6, x2, 5
```

La instrucción utiliza:

```text
rs1 = x2
```

pero no utiliza `rs2`.

Los bits que físicamente ocupan la posición `24:20` forman parte del inmediato.

Si esos bits casualmente fueran iguales al número del registro destino de un load anterior, una implementación que compare siempre contra `rs2` podría generar un stall falso.

Por este motivo la Hazard Detection Unit clasifica qué fuentes necesita cada tipo de instrucción.

La política utilizada es:

| Clase | rs1 necesario en EX | rs2 necesario en EX |
|---|---:|---:|
| R-Type | Sí | Sí |
| I-ALU | Sí | No |
| LOAD | Sí | No |
| STORE | Sí | No |
| BRANCH | Sí | Sí |
| LUI | No | No |
| JAL | No | No |
| JALR | Sí | No |

El caso STORE merece una explicación adicional.

---

# 7. Dependencias en instrucciones store

Una instrucción:

```asm
sw x5, 0(x2)
```

utiliza dos registros:

```text
x2 -> base para calcular la dirección
x5 -> dato que se escribirá en memoria
```

Sin embargo, no necesita ambos registros en la misma etapa.

La base:

```text
rs1 = x2
```

es necesaria en EX:

```text
dirección = x2 + inmediato
```

El dato:

```text
rs2 = x5
```

recién se necesita en MEM.

Esta diferencia permite optimizar ciertos hazards.

---

# 8. Load seguido de store usando el resultado como base

Ejemplo:

```asm
lw x5, 0(x1)
sw x7, 0(x5)
```

El store necesita `x5` para calcular su dirección efectiva:

```text
dirección = x5 + 0
```

Ese cálculo ocurre en EX.

El dato cargado por `lw` todavía no está disponible cuando el store debería entrar en EX.

Por lo tanto:

```text
lw -> sw base
```

requiere un stall de un ciclo.

Después del stall el valor puede llegar desde MEM/WB hacia EX mediante el forwarding normal.

---

# 9. Load seguido de store usando el resultado como dato

Ejemplo:

```asm
lw x5, 0(x1)
sw x5, 0(x2)
```

En este caso el store no necesita `x5` durante EX.

Durante EX solamente calcula:

```text
dirección = x2 + 0
```

`x5` recién es necesario durante MEM, cuando se escribe efectivamente la Data Memory.

Sin stall:

```text
Ciclo        1     2     3     4     5     6

lw           IF    ID    EX    MEM   WB
sw                 IF    ID    EX    MEM   WB
```

Durante el ciclo 5:

```text
lw -> WB
sw -> MEM
```

El valor cargado ya está disponible en WB justo cuando el store lo necesita.

Por este motivo se agregó un camino específico:

```text
WB -> MEM store-data
```

Así:

```asm
lw x5, 0(x1)
sw x5, 0(x2)
```

puede ejecutarse sin stall.

---

# 10. Store Data Forwarding Unit

Se agregó:

```text
rtl/store_data_forwarding_unit.sv
```

La unidad compara:

```text
ex_mem_rs2
```

correspondiente al registro que contiene el dato del store, contra:

```text
wb_write_register
```

correspondiente al registro escrito por la instrucción actualmente en WB.

Si:

```text
EX/MEM contiene un store válido
WB escribe un registro válido
WB.rd == EX/MEM.rs2
```

entonces:

```text
store_data = wb_write_data
```

En caso contrario:

```text
store_data = ex_mem_store_data
```

El camino conceptual es:

```text
EX/MEM.store_data ----\
                       > MUX -> Store Unit -> Data Memory
WB.write_data --------/
```

La señal:

```text
store_data_forwarded
```

permite además observar durante simulación cuándo se seleccionó el camino de forwarding.

---

# 11. Transporte de rs2 hasta MEM

Antes de esta modificación, EX/MEM conservaba el valor:

```text
store_data
```

pero no conservaba la identidad del registro fuente que produjo ese dato.

Para realizar la comparación:

```text
WB.rd == STORE.rs2
```

fue necesario transportar también:

```text
rs2
```

a través del registro EX/MEM.

Por lo tanto se agregó:

```text
id_ex_rs2
    |
    v
EX
    |
    v
ex_mem_rs2
    |
    v
MEM
```

Este número de registro se utiliza exclusivamente para determinar si corresponde realizar forwarding del dato del store.

---

# 12. Forwarding de stores ya existente en EX

El nuevo forwarding WB → MEM no reemplaza al forwarding que ya existía para store data en EX.

Por ejemplo:

```asm
add x5, x1, x2
sw  x5, 0(x3)
```

El `add` produce el dato suficientemente temprano.

El forwarding normal puede resolver:

```text
EX/MEM -> EX
```

y `forwarded_rs2` queda guardado como `store_data`.

Por lo tanto existen ahora dos mecanismos complementarios:

```text
EX/MEM o MEM/WB -> EX
```

para dependencias convencionales, y:

```text
WB -> MEM
```

para el caso especial donde el dato del store se necesita recién en MEM.

---

# 13. Bypass WB → ID en el Register File

Durante las pruebas de load-use apareció además otro caso de dependencia.

Una instrucción podía encontrarse en WB escribiendo un registro mientras otra instrucción en ID intentaba leer ese mismo registro durante el mismo ciclo.

El Register File originalmente utilizaba:

```text
lectura combinacional
escritura secuencial en posedge
```

Por lo tanto ID podía observar el valor antiguo justo antes de que WB actualizara el registro.

Ejemplo conceptual:

```text
WB -> escribe x2 = 10
ID -> lee x2
```

en el mismo ciclo.

Se agregó un bypass interno:

```text
si write_enable
y write_register == read_register

read_data = write_data
```

Esto produce un comportamiento equivalente a una lectura `write-first` para coincidencias entre WB e ID.

El bypass existe independientemente para ambos puertos de lectura.

También se mantiene:

```text
x0 = 0
```

en todo momento.

---

# 14. Relación entre los mecanismos

La arquitectura completa para hazards de datos utiliza distintos mecanismos según cuándo está disponible y cuándo se necesita el dato.

## Caso 1 — resultado ALU inmediatamente anterior

```asm
add x5, x1, x2
sub x6, x5, x3
```

Solución:

```text
EX/MEM -> EX forwarding
```

No hay stall.

---

## Caso 2 — resultado disponible en MEM/WB

Solución:

```text
MEM/WB -> EX forwarding
```

No hay stall si el timing ya lo permite.

---

## Caso 3 — load-use inmediato

```asm
lw  x5, 0(x1)
add x6, x5, x2
```

Solución:

```text
1 stall
+
MEM/WB -> EX forwarding
```

---

## Caso 4 — WB e ID acceden al mismo registro

Solución:

```text
WB -> ID bypass
```

No hay stall.

---

## Caso 5 — load seguido de store que usa el resultado como base

```asm
lw x5, 0(x1)
sw x7, 0(x5)
```

Solución:

```text
1 stall
+
MEM/WB -> EX forwarding
```

---

## Caso 6 — load seguido de store que usa el resultado como dato

```asm
lw x5, 0(x1)
sw x5, 0(x2)
```

Solución:

```text
WB -> MEM store-data forwarding
```

No hay stall.

---

# 15. Control generado durante un load-use stall

Cuando:

```text
load_use_stall = 1
```

el core genera:

```text
if_enable   = 0
id_enable   = 1

flush_if_id  = 0
flush_id_ex  = 1
flush_ex_mem = 0
flush_mem_wb = 0
```

El resultado es:

```text
PC          HOLD
IF/ID       HOLD
ID/EX       BUBBLE
EX/MEM      ADVANCE
MEM/WB      ADVANCE
```

Este comportamiento permite que el load siga progresando mientras la instrucción dependiente espera exactamente un ciclo.

---

# 16. Validación de Hazard Detection Unit

El test aislado:

```text
tb/hazard_detection_unit_tb.sv
```

validó 16 casos.

Resultado:

```text
Tests run    : 16
Tests passed : 16
Tests failed : 0
```

Entre los casos verificados se encuentran:

- dependencia R-Type por `rs1`;
- dependencia R-Type por `rs2`;
- operación independiente;
- load usando resultado anterior como base;
- store usando resultado anterior como base;
- branch por `rs1`;
- branch por `rs2`;
- `addi` dependiente;
- falso `rs2` en instrucciones inmediatas;
- destino `x0`;
- productor que no es load;
- instrucciones inválidas;
- LUI;
- JAL;
- store-data sin stall.

---

# 17. Validación del bypass WB → ID

El test:

```text
tb/register_file_bypass_tb.sv
```

verificó:

- lectura normal;
- bypass sobre read port 1;
- bypass sobre read port 2;
- ausencia de falso bypass;
- protección de x0.

Resultado:

```text
Tests passed : 7
Tests failed : 0
```

---

# 18. Validación de load-use

El test:

```text
tb/pipeline_core_load_use_tb.sv
```

ejecutó dependencias reales dentro del pipeline.

Se verificaron:

```text
lw -> add
lw -> sub
lw -> load usando resultado como base
lw -> store usando resultado como base
```

También se comprobó explícitamente:

```text
PC HOLD
IF/ID HOLD
ID/EX BUBBLE
load avanzando a EX/MEM
forwarding posterior MEM/WB -> EX
```

Resultado final:

```text
Tests run    : 22
Tests passed : 22
Tests failed : 0
Stalls       : 4
```

Por lo tanto cada dependencia que necesitaba el valor cargado en EX generó exactamente un stall.

---

# 19. Validación aislada del store-data forwarding

Se agregó:

```text
tb/store_data_forwarding_unit_tb.sv
```

Resultado:

```text
Tests run    : 7
Tests passed : 7
Tests failed : 0
```

Se verificaron:

- ausencia de productor;
- coincidencia WB.rd / STORE.rs2;
- registros diferentes;
- WB deshabilitado;
- store inválido;
- instrucción que no es store;
- protección de x0.

---

# 20. Validación end-to-end de load → store

El test:

```text
tb/pipeline_core_store_forwarding_tb.sv
```

incluye dos situaciones.

## Caso A

```asm
lw x5, 0(x1)
sw x5, 0(x2)
```

Resultado:

```text
dato almacenado correctamente
0 stalls asociados a esta dependencia
MEM store forwarding observado
```

## Caso B

```asm
lw x6, 4(x1)
sw x3, 0(x6)
```

Resultado:

```text
dato almacenado correctamente
1 stall
store-base stall observado
```

Resultado global:

```text
Tests run    : 12
Tests passed : 12
Tests failed : 0
Stalls       : 1
```

Esto demuestra que la Hazard Detection Unit distingue correctamente entre un valor requerido en EX y un valor requerido recién en MEM.

---

# 21. Regresiones

Después de integrar todos los mecanismos se ejecutaron nuevamente pruebas anteriores.

## Forwarding general

```text
pipeline_core_forwarding_tb
```

Resultado:

```text
10 / 10 PASS
```

Se observaron:

- forwarding EX/MEM;
- forwarding MEM/WB;
- forwarding mixto;
- forwarding de store data.

## Pipeline general

```text
pipeline_core_tb
```

Resultado:

```text
PASS: pipeline_core
```

También se comprobó nuevamente el funcionamiento simultáneo de las cinco etapas:

```text
IF
ID
EX
MEM
WB
```

## Memoria

```text
pipeline_core_memory_tb
```

Resultado:

```text
PASS: pipeline_core_memory
```

Se verificaron store y load correctamente.

## Load-use final

Después de incorporar el forwarding adicional de stores se repitió:

```text
pipeline_core_load_use_tb
```

Resultado:

```text
Tests run    : 22
Tests passed : 22
Tests failed : 0
Stalls       : 4
```

Esto confirma que la optimización del store no alteró el funcionamiento de los stalls load-use convencionales.

---

# 22. Estado final

Al finalizar esta etapa el procesador soporta:

```text
EX/MEM -> EX forwarding
MEM/WB -> EX forwarding
WB -> ID bypass
WB -> MEM store-data forwarding
load-use hazard detection
PC hold
IF/ID hold
ID/EX bubble
```

La política final es:

```text
Dependencia resoluble por forwarding
    -> no stall

Load cuyo resultado se necesita inmediatamente en EX
    -> stall de un ciclo

Load cuyo resultado es únicamente el dato de un store
    -> no stall
    -> forwarding WB -> MEM
```

Con esto quedan resueltos los hazards de datos estudiados en esta etapa del procesador segmentado.

Los hazards de control producidos por branches y jumps se implementarán en la etapa siguiente.
