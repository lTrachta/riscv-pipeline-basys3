# Debug Unit

## 1. Objetivo

La Debug Unit permite observar el estado interno del procesador y transmitirlo hacia una PC mediante UART.

El enunciado requiere poder obtener:

- los 32 registros del Register File;
- los registros intermedios del pipeline;
- el contenido de la memoria de datos utilizada.

Además, esta información debe poder recuperarse tanto durante la ejecución paso a paso como al finalizar una ejecución continua.

La Debug Unit fue diseñada como un mecanismo de observación.

No modifica el estado arquitectónico del procesador.

---

## 2. Principio de funcionamiento

La arquitectura general es:

```text
                 Pipeline Core
                      |
          +-----------+-----------+
          |           |           |
          v           v           v
   Register File   Pipeline     Data Memory
          |         Latches         |
          +-----------+-------------+
                      |
                      v
                Debug Unit
                      |
                      v
             Protocol Controller
                      |
                      v
                   UART TX
                      |
                      v
                     PC
```

La Debug Unit solamente posee caminos de lectura hacia el procesador.

No puede:

- escribir registros;
- modificar Data Memory;
- modificar Instruction Memory;
- cambiar el PC;
- avanzar el pipeline.

---

## 3. Snapshot coherente

Un snapshot representa una fotografía del estado del procesador en un instante determinado.

Para evitar mezclar información perteneciente a ciclos diferentes, el procesador debe permanecer detenido mientras se obtiene el snapshot.

Esto se logra utilizando:

```text
cycle_enable
```

En modo paso a paso:

```text
STEP
 |
 v
cycle_enable = 1 durante un ciclo
 |
 v
pipeline avanza
 |
 v
cycle_enable = 0
 |
 v
snapshot
```

Durante la transmisión UART el pipeline permanece estable.

En modo continuo el snapshot final se obtiene después de:

```text
HALT
  |
  v
DRAINING
  |
  v
pipeline vacío
  |
  v
HALTED
  |
  v
snapshot
```

---

## 4. Información general

El snapshot incluye:

```text
status
flags
IF PC
```

Los flags representan:

```text
core_running
core_draining
core_halted
core_pipeline_empty
core_cycle_enable
```

Esto permite conocer simultáneamente el estado del controlador y del pipeline.

---

## 5. Register File

Se transmiten los 32 registros:

```text
x0
x1
...
x31
```

El formato de cada entrada es:

```text
REGISTER_NUMBER
DATA[31:24]
DATA[23:16]
DATA[15:8]
DATA[7:0]
```

La Debug Unit utiliza el puerto combinacional de debug incorporado al Register File.

Este puerto es independiente de los dos puertos normales utilizados por la etapa ID.

Por lo tanto, la lectura de debug no afecta la ejecución.

---

## 6. IF/ID

El registro IF/ID transmite:

```text
valid
PC
instruction
```

Esto permite identificar qué instrucción se encuentra en ID.

---

## 7. ID/EX

Se transmite:

```text
valid
PC

read_data1
read_data2
immediate

rs1
rs2
rd

opcode
funct3
funct7

alu_src_a
alu_src_b
alu_op

branch
jump_type

mem_read
mem_write

reg_write
wb_sel
```

Las señales de control se empaquetan para reducir la cantidad de bytes transmitidos.

---

## 8. EX/MEM

Se transmite:

```text
valid
PC

ALU result
store data

rs2
rd

opcode
funct3

mem_read
mem_write

reg_write
wb_sel
```

Esto permite observar el resultado producido por EX y la operación que posteriormente realizará MEM.

---

## 9. MEM/WB

Se transmite:

```text
valid
PC

ALU result
load data

rd
opcode

reg_write
wb_sel
```

Esto permite observar qué valor está disponible para Write Back.

---

## 10. Visualización del pipeline

Al incluir el PC de IF y el PC almacenado en cada registro intermedio es posible observar el desplazamiento de instrucciones.

Ejemplo:

```text
IF      PC = 16
IF/ID   PC = 12
ID/EX   PC = 8
EX/MEM  PC = 4
MEM/WB  PC = 0
```

Esto representa cinco instrucciones ocupando simultáneamente las diferentes etapas del pipeline.

---

## 11. Memoria de datos utilizada

No se considera que una posición de memoria esté utilizada simplemente porque su contenido sea distinto de cero.

Una posición puede haber sido escrita con cero y seguir siendo una posición utilizada.

Por esta razón se implementó un bitmap:

```text
used_memory_bitmap
```

con un bit por palabra de Data Memory.

Cuando una instrucción válida realiza realmente un:

```text
load
```

o:

```text
store
```

se marca:

```text
used_memory_bitmap[address >> 2] = 1
```

El bitmap no vuelve a contar una dirección ya utilizada.

Por ejemplo:

```text
store address 64
load  address 64
```

produce:

```text
used_memory_count = 1
```

aunque hayan ocurrido dos accesos.

---

## 12. Acceso real a memoria

Una dirección sólo se registra como utilizada cuando la operación realmente alcanza MEM y el pipeline avanza.

La condición incluye:

```text
ex_mem_valid
mem_enable
operación load/store válida
alineación correcta
no reset
```

Esto evita registrar repetidamente la misma operación mientras el procesador permanece pausado.

---

## 13. Limpieza del mapa de memoria

Cuando comienza la carga de un nuevo programa:

```text
memory_usage_clear = 1
```

Esto reinicia:

```text
used_memory_bitmap
used_memory_count
```

Por lo tanto, cada programa posee su propio conjunto de direcciones utilizadas.

El contenido físico de Data Memory no necesita ser borrado.

---

## 14. Congelamiento de la fotografía

Al recibirse:

```text
snapshot_start
```

la Debug Unit copia los latches del pipeline hacia registros internos:

```text
snapshot_if_id_*
snapshot_id_ex_*
snapshot_ex_mem_*
snapshot_mem_wb_*
```

También copia:

```text
used_memory_bitmap
used_memory_count
```

De esta forma primero se toma la fotografía y después se transmite.

Los valores del pipeline no se leen progresivamente durante la transmisión.

---

## 15. Register File y Data Memory durante snapshot

No es necesario copiar físicamente los 32 registros ni toda Data Memory dentro de la Debug Unit.

Como el procesador permanece pausado, estos elementos son estables.

La Debug Unit los recorre mediante sus puertos combinacionales de lectura:

```text
debug_register_address
debug_register_data

debug_memory_address
debug_memory_data
```

Durante un snapshot estos puertos quedan asignados a la Debug Unit.

Fuera del snapshot pueden seguir siendo utilizados por los comandos individuales de lectura.

---

## 16. Comando D

Se agregó al protocolo:

```text
D = 0x44
```

La PC envía:

```text
'D'
```

y la respuesta es directamente el stream completo del snapshot.

No se envía un ACK previo.

El primer byte del stream identifica la respuesta:

```text
'd' = 0x64
```

---

## 17. Snapshot durante RUN

No se permite iniciar un snapshot mientras el procesador está avanzando continuamente.

Si se intenta enviar un comando diferente de QUERY mientras RUN está activo, el controlador responde:

```text
NACK
ERR_INVALID_STATE
```

Código:

```text
0x15 0x05
```

Esto garantiza que la información enviada pertenezca a un único estado estable.

---

## 18. Formato del snapshot

La versión actual es:

```text
version = 0x01
```

El paquete contiene:

```text
HEADER

REGISTER FILE

IF/ID

ID/EX

EX/MEM

MEM/WB

USED DATA MEMORY

END
```

Tags utilizados:

```text
'd'  snapshot
'R'  Register File
'I'  IF/ID
'X'  ID/EX
'E'  EX/MEM
'B'  MEM/WB
'M'  Data Memory
0x7E fin
```

Los valores multibyte del protocolo se envían MSB first.

---

## 19. Tamaño del snapshot

La parte fija ocupa:

```text
246 bytes
```

Cada palabra de Data Memory utilizada agrega:

```text
6 bytes
```

correspondientes a:

```text
address[15:8]
address[7:0]

data[31:24]
data[23:16]
data[15:8]
data[7:0]
```

Por lo tanto:

```text
snapshot_size =
246 + 6 * used_memory_count
```

---

## 20. Verificación aislada de Debug Unit

Testbench:

```text
tb/debug_unit_tb.sv
```

Se verificaron:

- conteo de memoria utilizada;
- eliminación de duplicados;
- memoria utilizada con valor cero;
- los 32 registros;
- IF/ID;
- ID/EX;
- EX/MEM;
- MEM/WB;
- congelamiento del snapshot;
- tamaño del paquete;
- limpieza del bitmap.

Resultado:

```text
Tests run    : 46
Tests passed : 46
Tests failed : 0
Snapshot bytes: 258

PASS: debug_unit
```

---

## 21. Integración Debug Unit + Pipeline Core

Testbench:

```text
tb/debug_core_integration_tb.sv
```

Se ejecutó un programa real:

```asm
addi x1, x0, 64
addi x2, x0, 85
sw   x2, 0(x1)
lw   x3, 0(x1)
addi x4, x3, 1
HALT
```

Después de cuatro ciclos se pausó el core.

El snapshot mostró:

```text
IF      PC = 16
IF/ID   PC = 12
ID/EX   PC = 8
EX/MEM  PC = 4
MEM/WB  PC = 0
```

Después se continuó la ejecución hasta HALT.

Resultados finales:

```text
x1 = 64
x2 = 85
x3 = 85
x4 = 86

DMEM[64] = 85

used_memory_count = 1

halted         = 1
pipeline_empty = 1
```

Resultado:

```text
Tests run    : 35
Tests passed : 35
Tests failed : 0

PASS: debug_core_integration
```

---

## 22. Verificación end-to-end por UART

Testbench:

```text
tb/debug_uart_snapshot_tb.sv
```

Se simuló una sesión completa desde una PC.

Flujo:

```text
PC
 |
 | UART LOAD
 v
FPGA
 |
 | cuatro STEP
 v
pipeline parcialmente ocupado
 |
 | D
 v
snapshot intermedio por UART
 |
 | RUN
 v
HALT
 |
 | D
 v
snapshot final por UART
 |
 v
PC
```

El snapshot intermedio verificó:

```text
IF      PC = 16
IF/ID   PC = 12
ID/EX   PC = 8
EX/MEM  PC = 4
MEM/WB  PC = 0
```

El snapshot final verificó:

```text
status = HALTED

x1 = 64
x2 = 85
x3 = 85
x4 = 86

IF/ID  invalid
ID/EX  invalid
EX/MEM invalid
MEM/WB invalid

DMEM[64] = 85
```

No se observaron errores de trama UART.

Resultado:

```text
Tests run    : 45
Tests passed : 45
Tests failed : 0

UART bytes received: 504

PASS: debug_uart_snapshot
```

---

## 23. Regresión completa

Después de incorporar la Debug Unit se ejecutó nuevamente toda la suite del proyecto.

Resultado:

```text
PASSED: 52
FAILED: 0
TOTAL : 52
```

Entre las nuevas pruebas se encuentran:

```text
debug_unit_tb
debug_core_integration_tb
debug_uart_snapshot_tb
```

Los 49 testbenches existentes anteriormente continuaron pasando.

Por lo tanto, la incorporación de la Debug Unit no introdujo regresiones en el procesador, la carga dinámica ni la comunicación UART.

---

## 24. Decisiones de diseño principales

Las principales decisiones fueron:

- la Debug Unit es exclusivamente de observación;
- no se utiliza acceso jerárquico como mecanismo funcional;
- el core expone señales explícitas de debug;
- los latches del pipeline se congelan al comenzar el snapshot;
- Register File y Data Memory se recorren mediante puertos de lectura;
- el procesador permanece pausado durante la transmisión;
- las posiciones de memoria utilizadas se registran mediante un bitmap;
- una dirección utilizada sigue siendo válida aunque su contenido sea cero;
- múltiples accesos a la misma palabra cuentan una sola vez;
- el comando `D` solicita el snapshot completo;
- el formato está versionado;
- la transmisión utiliza el mismo UART TX ya implementado;
- el pipeline no modifica su estado durante la inspección.

Con estas decisiones se cumple el requisito de recuperar desde la PC el estado completo necesario para inspeccionar el procesador.
