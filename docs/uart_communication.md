# Comunicación UART y protocolo de control

## 1. Objetivo

El sistema incorpora comunicación serie UART entre una PC y el procesador implementado en FPGA.

La comunicación permite:

- cargar dinámicamente programas en Instruction Memory;
- iniciar la ejecución continua;
- avanzar el procesador exactamente un ciclo;
- consultar el estado general;
- leer registros del Register File;
- leer palabras de Data Memory;
- solicitar un snapshot completo de debug;
- recibir confirmaciones y códigos de error.

La arquitectura se diseñó de forma modular para separar claramente:

1. transporte físico UART;
2. interpretación del protocolo;
3. carga de programas;
4. control de ejecución;
5. acceso de debug;
6. generación de snapshots.

---

## 2. Arquitectura general

El flujo completo es:

```text
PC
 |
 | UART
 v
+---------+
| uart_rx |
+---------+
     |
     | rx_byte_data
     | rx_byte_valid
     v
+----------------------------+
| system_protocol_controller |
+----------------------------+
     |           |           |
     |           |           |
     v           v           v
program_loader  core     Debug Unit
     |                       |
     v                       |
    IMEM                     |
                             |
                             v
                    Register File / DMEM
                             |
                             v
                    snapshot_byte_data
                             |
                             v
+----------------------------+
| system_protocol_controller |
+----------------------------+
             |
             | tx_byte_data
             | tx_byte_valid
             v
        +---------+
        | uart_tx |
        +---------+
             |
             | UART
             v
             PC
```

El módulo de integración es:

```text
rtl/processor_system.sv
```

---

## 3. Configuración UART

La configuración adoptada es:

```text
clock FPGA      = 100 MHz
baud rate       = 115200
data bits       = 8
parity          = none
stop bits       = 1
oversampling RX = 16
```

La configuración UART se expresa como:

```text
115200 8N1
```

La línea permanece en nivel lógico alto durante reposo.

Cada trama contiene:

```text
START + D0 + D1 + D2 + D3 + D4 + D5 + D6 + D7 + STOP
```

UART transmite los bits de cada byte en orden:

```text
LSB first
```

Por lo tanto:

```text
D0 -> D1 -> ... -> D7
```

---

## 4. Baud generator

El módulo:

```text
rtl/baud_gen.sv
```

genera un pulso periódico llamado:

```text
baud_tick
```

No genera un nuevo clock.

Con:

```text
BAUD_RATE    = 115200
OVERSAMPLING = 16
```

la frecuencia de referencia es:

```text
115200 * 16 = 1843200 ticks/s
```

Para un clock de 100 MHz se obtiene aproximadamente:

```text
100000000 / 1843200 ~= 54 clocks
```

El divisor se redondea al entero más cercano.

El testbench:

```text
tb/baud_gen_tb.sv
```

verificó seis intervalos consecutivos.

Resultado:

```text
Tests run    : 6
Tests passed : 6
Tests failed : 0
PASS: baud_gen
```

---

## 5. Receptor UART

El módulo:

```text
rtl/uart_rx.sv
```

transforma la señal serie en:

```systemverilog
rx_byte_data[7:0]
rx_byte_valid
```

También genera:

```systemverilog
rx_frame_error
```

si el bit de parada no es válido.

### Sincronización

La entrada UART proviene del exterior y es asíncrona respecto del clock de la FPGA.

Por este motivo la señal RX atraviesa un sincronizador de dos flip-flops antes de ser interpretada por la FSM.

### FSM de recepción

La máquina de estados utiliza:

```text
IDLE
START
DATA
STOP
```

La secuencia es:

1. en `IDLE` se espera línea en reposo;
2. una transición hacia cero inicia una posible trama;
3. en `START` se espera aproximadamente medio bit;
4. si la línea sigue en cero se confirma el start bit;
5. en `DATA` se toma una muestra aproximadamente cada 16 ticks;
6. se reconstruyen D0 a D7;
7. en `STOP` se verifica nivel lógico alto;
8. si la trama es válida se genera un pulso `rx_byte_valid`.

### Oversampling

El oversampling por 16 no significa almacenar 16 copias de cada bit.

Significa disponer de una referencia temporal con 16 posiciones aproximadas dentro del tiempo correspondiente a un bit.

Después de detectar el comienzo del start bit se esperan aproximadamente:

```text
8 ticks
```

para llegar a su centro.

Luego se esperan:

```text
16 ticks
```

entre los centros de bits consecutivos.

---

## 6. Verificación de uart_rx

El testbench:

```text
tb/uart_rx_tb.sv
```

envió tramas UART simuladas para:

```text
0x4C
0xA5
0x00
0xFF
```

También se verificó un falso start cuya duración era menor a medio bit.

Resultado:

```text
RX bytes      : 4
Frame errors  : 0
Tests run     : 5
Tests passed  : 5
Tests failed  : 0
PASS: uart_rx
```

---

## 7. Transmisor UART

El módulo:

```text
rtl/uart_tx.sv
```

realiza el camino inverso.

Su interfaz principal utiliza:

```systemverilog
tx_start
tx_data[7:0]
tx
tx_busy
tx_done
```

La FSM utiliza:

```text
IDLE
START
DATA
STOP
```

### Funcionamiento

En reposo:

```text
tx = 1
```

Cuando se recibe:

```text
tx_start = 1
```

el módulo captura `tx_data` y transmite:

```text
START
D0
D1
D2
D3
D4
D5
D6
D7
STOP
```

Mientras se transmite:

```text
tx_busy = 1
```

Al finalizar:

```text
tx_busy = 0
tx_done = 1
```

`tx_done` es un pulso de un solo ciclo.

---

## 8. Verificación de uart_tx

El testbench:

```text
tb/uart_tx_tb.sv
```

verificó:

- estado de reposo;
- start bit;
- D0 a D7;
- orden LSB first;
- stop bit;
- `tx_busy`;
- finalización de cada trama.

Se probaron:

```text
0x4C
0xA5
0x00
0xFF
```

Resultado:

```text
Tests run    : 45
Tests passed : 45
Tests failed : 0
PASS: uart_tx
```

---

## 9. Loopback UART

El testbench:

```text
tb/uart_loopback_tb.sv
```

conecta directamente:

```text
uart_tx.tx -> uart_rx.rx
```

El objetivo es comprobar que un byte paralelo puede:

1. convertirse en una trama serie;
2. atravesar la conexión;
3. reconstruirse nuevamente como el mismo byte.

Se verificaron:

```text
4C -> 4C
A5 -> A5
00 -> 00
FF -> FF
```

Resultado:

```text
RX bytes      : 4
Frame errors  : 0
Tests run     : 5
Tests passed  : 5
Tests failed  : 0
PASS: uart_loopback
```

---

## 10. Integración UART RX con Program Loader

El testbench:

```text
tb/uart_program_loader_tb.sv
```

ya no entrega bytes directamente al cargador.

Genera una señal UART real simulada:

```text
bits UART
   |
   v
uart_rx
   |
   v
rx_byte_data + rx_byte_valid
   |
   v
program_loader
   |
   v
Instruction Memory
```

El programa transmitido fue:

```asm
addi x1, x0, 10
addi x2, x0, 20
add  x3, x1, x2
HALT
```

Se enviaron:

```text
32 bytes UART
```

y se verificaron:

```text
UART bytes   : 32
Frame errors : 0
IMEM writes  : 4
Load done    : 1
```

Resultado:

```text
Tests run    : 12
Tests passed : 12
Tests failed : 0
PASS: uart_program_loader
```

Las palabras cargadas fueron:

```text
IMEM[0]  = 00A00093
IMEM[4]  = 01400113
IMEM[8]  = 002081B3
IMEM[12] = 0000000B
```

---

## 11. Protocolo del sistema

UART solamente transporta bytes.

El significado de cada byte pertenece al protocolo del sistema.

Los comandos definidos son:

| Comando | Hex | Función |
|---|---:|---|
| `L` | `0x4C` | iniciar carga |
| `W` | `0x57` | escribir palabra durante carga |
| `E` | `0x45` | finalizar carga |
| `R` | `0x52` | ejecución continua |
| `S` | `0x53` | avanzar un ciclo |
| `G` | `0x47` | leer registro |
| `M` | `0x4D` | leer memoria |
| `Q` | `0x51` | consultar estado |
| `D` | `0x44` | obtener snapshot completo de debug |

Las respuestas principales son:

| Respuesta | Hex | Significado |
|---|---:|---|
| ACK | `0x06` | comando aceptado |
| NACK | `0x15` | comando rechazado |
| `g` | `0x67` | respuesta de registro |
| `m` | `0x6D` | respuesta de memoria |
| `q` | `0x71` | respuesta de estado |
| `d` | `0x64` | inicio de snapshot completo |

---

## 12. Protocolo LOAD

La carga conserva el protocolo previamente definido.

Inicio:

```text
'L'
COUNT[15:8]
COUNT[7:0]
```

Escritura:

```text
'W'
ADDR[15:8]
ADDR[7:0]
DATA[31:24]
DATA[23:16]
DATA[15:8]
DATA[7:0]
```

Finalización:

```text
'E'
```

El orden entre bytes de campos multibyte es:

```text
MSB first
```

Esto es independiente del hecho de que UART transmita los bits de cada byte en orden LSB first.

Cuando la carga finaliza correctamente:

```text
FPGA -> PC
ACK
```

Si la carga es inválida:

```text
FPGA -> PC
NACK ERR_LOAD
```

---

## 13. Comando RUN

Formato:

```text
PC -> FPGA
'R'
```

Si existe un programa válido y el core puede ejecutarse:

```text
FPGA -> PC
ACK
```

Después el controlador mantiene:

```text
core_cycle_enable = 1
```

continuamente.

La ejecución continúa hasta alcanzar HALT.

Cuando el core llega a:

```text
HALTED
```

el controlador desactiva automáticamente el modo RUN.

---

## 14. Comando STEP

Formato:

```text
PC -> FPGA
'S'
```

STEP significa:

```text
avanzar exactamente un ciclo del procesador
```

No significa ejecutar una instrucción completa.

Esto es necesario porque el procesador es segmentado y en un mismo ciclo pueden encontrarse instrucciones diferentes en IF, ID, EX, MEM y WB.

Para implementar STEP no se genera un clock derivado.

Se agregó al core:

```systemverilog
cycle_enable
```

Los registros internos del pipeline continúan utilizando el clock principal, pero sólo avanzan cuando:

```text
cycle_enable = 1
```

Durante STEP este enable permanece activo exactamente un ciclo.

Al finalizar se responde:

```text
ACK
```

---

## 15. Pausa segura del pipeline

La incorporación de STEP requiere que el procesador pueda permanecer congelado entre comandos.

Por ese motivo:

```text
IF
ID
EX
MEM
WB
```

respetan el control global de avance.

La unidad de control de HALT también respeta este enable.

Además, la escritura del Register File desde WB se habilita solamente cuando:

```text
wb_write_enable_raw && cycle_enable
```

Esto evita que un valor de WB sea escrito repetidamente mientras el pipeline está detenido.

No se gatea físicamente el clock.

Esta decisión mantiene el diseño completamente síncrono y utiliza enables sobre el estado secuencial.

---

## 16. Lectura de registros

Comando:

```text
'G'
REGISTER
```

Los registros válidos son:

```text
0x00 ... 0x1F
```

Ejemplo:

```text
47 05
```

solicita:

```text
x5
```

La respuesta es:

```text
'g'
REGISTER
DATA[31:24]
DATA[23:16]
DATA[15:8]
DATA[7:0]
```

Por ejemplo:

```text
67 05 00 00 00 07
```

representa:

```text
x5 = 7
```

Se agregó un puerto de lectura de debug independiente al Register File.

Ese puerto es combinacional y no interfiere con los dos puertos normales de lectura utilizados por ID.

---

## 17. Lectura de Data Memory

Comando:

```text
'M'
ADDR[15:8]
ADDR[7:0]
```

La dirección se expresa en bytes.

La operación devuelve una palabra completa de 32 bits y exige:

```text
dirección alineada a 4 bytes
dirección dentro del rango de DMEM
```

La respuesta es:

```text
'm'
ADDR[15:8]
ADDR[7:0]
DATA[31:24]
DATA[23:16]
DATA[15:8]
DATA[7:0]
```

Data Memory posee un puerto combinacional de debug independiente del puerto normal utilizado por MEM.

---

## 18. Consulta de estado

Comando:

```text
'Q'
```

Respuesta:

```text
'q'
STATE
```

Los códigos son:

```text
0x00 READY
0x01 LOADING
0x02 RUNNING
0x03 DRAINING
0x04 HALTED
0x05 ERROR
```

Esto permite que el software de PC determine el estado actual sin observar señales internas de FPGA.

---

## 19. Comando de snapshot completo

El comando:

```text
'D' = 0x44
```

solicita a la Debug Unit una fotografía completa del estado observable del procesador.

El snapshot incluye:

- los 32 registros del Register File;
- el PC actual de IF;
- el registro IF/ID;
- el registro ID/EX;
- el registro EX/MEM;
- el registro MEM/WB;
- las posiciones utilizadas de Data Memory.

La respuesta comienza directamente con:

```text
'd' = 0x64
```

No se envía un ACK previo.

El paquete finaliza con:

```text
0x7E
```

Durante la generación y transmisión del snapshot el procesador permanece detenido.

Esto garantiza que todos los valores enviados correspondan a un mismo estado coherente.

### Snapshot en modo paso a paso

El flujo previsto es:

```text
STEP
 |
 v
pipeline avanza un ciclo
 |
 v
ACK
 |
 v
D
 |
 v
snapshot completo
```

De esta forma el software de PC puede mostrar el estado del procesador después de cada ciclo.

### Snapshot al finalizar RUN

El flujo es:

```text
RUN
 |
 v
ejecución continua
 |
 v
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
D
 |
 v
snapshot final
```

### Restricción durante RUN

No se permite iniciar un snapshot mientras el procesador está avanzando continuamente.

Durante `RUN`, los comandos que no están permitidos se rechazan con:

```text
NACK
ERR_INVALID_STATE
```

equivalente a:

```text
0x15 0x05
```

Esto evita generar una fotografía incoherente mientras el pipeline cambia en cada ciclo.

### Formato general

El snapshot utiliza formato binario y está versionado.

La versión actual es:

```text
0x01
```

La estructura general es:

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

Los tags principales son:

```text
'd'  = snapshot
'R'  = Register File
'I'  = IF/ID
'X'  = ID/EX
'E'  = EX/MEM
'B'  = MEM/WB
'M'  = Data Memory
0x7E = fin
```

La parte fija ocupa:

```text
246 bytes
```

Cada palabra utilizada de Data Memory agrega:

```text
6 bytes
```

Por lo tanto:

```text
snapshot_size = 246 + 6 * used_memory_count
```

El formato completo y la implementación interna se documentan en:

```text
docs/debug_unit.md
```

---

## 20. Códigos de error

Cuando un comando no puede ejecutarse se responde:

```text
NACK
ERROR_CODE
```

Los códigos definidos son:

```text
0x01 comando desconocido
0x02 argumento inválido
0x03 dirección inválida
0x04 error de carga
0x05 operación no permitida en el estado actual
```

Ejemplos:

```text
G 20
```

produce:

```text
15 02
```

porque no existe el registro x32.

Una lectura de memoria desalineada como:

```text
M 00 02
```

produce:

```text
15 03
```

---

## 21. Controlador de protocolo

El módulo:

```text
rtl/system_protocol_controller.sv
```

es responsable de interpretar bytes ya reconstruidos por UART.

No interpreta bits físicos.

Sus responsabilidades principales son:

- redirigir el flujo LOAD hacia `program_loader`;
- controlar `RUN`;
- generar un pulso efectivo de un ciclo para `STEP`;
- seleccionar direcciones de debug para `G` y `M`;
- iniciar snapshots mediante `D`;
- conectar el stream de la Debug Unit con UART TX;
- construir respuestas normales;
- emitir ACK/NACK;
- reportar estado;
- rechazar operaciones no permitidas.

Las respuestas normales del protocolo utilizan un pequeño buffer interno.

La mayor respuesta normal almacenada en ese buffer contiene siete bytes:

```text
m + addr16 + data32
```

El snapshot completo no se almacena en ese buffer.

Durante:

```text
STATE_DEBUG_SNAPSHOT
```

el stream generado por la Debug Unit se conecta directamente al handshake de transmisión UART.

---

## 22. Integración de UART TX con el protocolo

El controlador expone:

```systemverilog
tx_byte_valid
tx_byte_data
```

y recibe:

```systemverilog
tx_byte_ready
```

El módulo superior convierte este handshake en:

```systemverilog
tx_start
tx_data
```

para `uart_tx`.

El siguiente byte sólo se acepta cuando el transmisor está disponible.

Así pueden enviarse respuestas de múltiples bytes sin superponer tramas.

Para las respuestas normales:

```text
response_buffer
      |
      v
protocol controller
      |
      v
uart_tx
```

Durante un snapshot:

```text
Debug Unit
    |
    | snapshot_byte_valid
    | snapshot_byte_data
    v
protocol controller
    |
    v
uart_tx
```

El handshake asegura que la Debug Unit no avance al byte siguiente hasta que UART TX pueda aceptar el byte actual.

---

## 23. Arbitraje de los puertos de debug

Los comandos individuales:

```text
G
M
```

y el snapshot completo:

```text
D
```

utilizan los mismos puertos combinacionales de lectura del Register File y Data Memory.

Por este motivo `processor_system` implementa arbitraje de las direcciones de debug.

Fuera de un snapshot:

```text
system_protocol_controller
            |
            v
RF / DMEM debug address
```

Durante un snapshot:

```text
Debug Unit
    |
    v
RF / DMEM debug address
```

La selección se realiza utilizando:

```text
snapshot_busy
```

Todos estos caminos son exclusivamente de lectura.

---

## 24. Memoria de datos utilizada

La Debug Unit mantiene un mapa de las palabras de Data Memory realmente utilizadas por el programa.

No se utiliza la condición:

```text
data != 0
```

porque una dirección puede haber sido utilizada y contener cero.

En cambio, cuando una instrucción válida ejecuta realmente un load o store se marca la palabra correspondiente.

Conceptualmente:

```text
used_memory_bitmap[address >> 2] = 1
```

Si una misma palabra es utilizada varias veces se cuenta una sola vez.

Ejemplo:

```text
store address 64
load  address 64
```

produce:

```text
used_memory_count = 1
```

Al comenzar la carga de un nuevo programa se limpia este mapa.

Esto no implica borrar físicamente Data Memory.

---

## 25. Verificación aislada del protocolo

El testbench:

```text
tb/system_protocol_controller_tb.sv
```

verificó, entre otros casos:

- RUN sin programa;
- forwarding del comando LOAD;
- ACK de carga;
- programa marcado como cargado;
- STEP exactamente un ciclo;
- lectura de registro;
- lectura de memoria;
- estado DRAINING;
- RUN continuo;
- detención al llegar a HALT;
- estado HALTED;
- registro inválido;
- comando desconocido.

Resultado:

```text
Tests run    : 30
Tests passed : 30
Tests failed : 0
PASS: system_protocol_controller
```

---

## 26. Verificación UART del sistema

El testbench:

```text
tb/processor_system_uart_tb.sv
```

simula una sesión PC-FPGA.

El programa transmitido fue:

```asm
addi x1, x0, 64
addi x2, x0, 85
sw   x2, 0(x1)
addi x3, x0, 33
HALT
```

La secuencia probada fue:

```text
LOAD
ACK

STEP
ACK

RUN
ACK

HALT
pipeline vacío

Q
q HALTED

G x1
x1 = 64

G x2
x2 = 85

G x3
x3 = 33

M 64
DMEM[64] = 85
```

También se verificaron:

```text
dirección de memoria desalineada -> NACK
comando desconocido              -> NACK
```

Resultado:

```text
Tests run    : 27
Tests passed : 27
Tests failed : 0
Responses RX : 34
Core cycles  : 10
PASS: processor_system_uart
```

No se detectaron errores de trama en las respuestas UART.

---

## 27. Verificación aislada de Debug Unit

El testbench:

```text
tb/debug_unit_tb.sv
```

verificó:

- conteo de memoria utilizada;
- eliminación de accesos duplicados;
- memoria utilizada cuyo contenido final es cero;
- lectura de los 32 registros;
- IF/ID;
- ID/EX;
- EX/MEM;
- MEM/WB;
- congelamiento de la fotografía;
- tamaño del paquete;
- limpieza del mapa de memoria utilizada.

Resultado:

```text
Tests run    : 46
Tests passed : 46
Tests failed : 0
Snapshot bytes: 258

PASS: debug_unit
```

---

## 28. Verificación Debug Unit + Pipeline Core

El testbench:

```text
tb/debug_core_integration_tb.sv
```

ejecutó el programa:

```asm
addi x1, x0, 64
addi x2, x0, 85
sw   x2, 0(x1)
lw   x3, 0(x1)
addi x4, x3, 1
HALT
```

Después de cuatro ciclos se pausó el procesador.

El snapshot intermedio mostró:

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

## 29. Verificación end-to-end del snapshot por UART

El testbench:

```text
tb/debug_uart_snapshot_tb.sv
```

verifica todo el recorrido:

```text
PC simulada
    |
    | UART RX
    v
system_protocol_controller
    |
    v
pipeline_core
    |
    v
Debug Unit
    |
    v
system_protocol_controller
    |
    v
uart_tx
    |
    v
PC simulada
```

Primero se cargó dinámicamente el programa:

```asm
addi x1, x0, 64
addi x2, x0, 85
sw   x2, 0(x1)
lw   x3, 0(x1)
addi x4, x3, 1
HALT
```

Después se enviaron cuatro comandos STEP.

El snapshot intermedio verificó:

```text
IF      PC = 16
IF/ID   PC = 12
ID/EX   PC = 8
EX/MEM  PC = 4
MEM/WB  PC = 0
```

Posteriormente se ejecutó:

```text
RUN
```

hasta HALT.

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

También se verificó:

```text
UART TX frame errors = 0
```

Resultado:

```text
Tests run    : 45
Tests passed : 45
Tests failed : 0

UART bytes received: 504

PASS: debug_uart_snapshot
```

Esto demuestra que la información recuperada por la PC atravesó realmente el enlace serie simulado y no fue obtenida mediante acceso interno del testbench.

---

## 30. Regresión completa

Después de incorporar:

- `baud_gen`;
- `uart_rx`;
- `uart_tx`;
- controlador de protocolo;
- `cycle_enable`;
- puertos de debug;
- Debug Unit;
- comando `D`;
- snapshot completo;
- seguimiento de memoria utilizada;
- integración superior;
- nuevos testbenches;

se ejecutó nuevamente toda la suite.

Resultado:

```text
FULL REGRESSION SUMMARY
PASSED: 52
FAILED: 0
TOTAL : 52
```

Entre los testbenches relacionados con UART y debug se encuentran:

```text
baud_gen_tb
uart_rx_tb
uart_tx_tb
uart_loopback_tb
uart_program_loader_tb
system_protocol_controller_tb
processor_system_uart_tb
debug_unit_tb
debug_core_integration_tb
debug_uart_snapshot_tb
```

Los testbenches anteriores del procesador también continuaron pasando.

Por lo tanto, la incorporación de la Debug Unit y del snapshot completo no produjo regresiones sobre las funcionalidades previamente verificadas.

---

## 31. Decisiones de diseño principales

Las decisiones más importantes son:

- UART y protocolo son capas diferentes;
- UART solamente convierte entre bits y bytes;
- el protocolo asigna significado a cada byte;
- RX utiliza oversampling por 16;
- RX sincroniza la entrada asíncrona mediante dos flip-flops;
- TX y RX utilizan la misma referencia de baud;
- los campos multibyte del protocolo se transmiten MSB first;
- los bits dentro de cada byte UART se transmiten LSB first;
- el Program Loader permanece separado del controlador general;
- `RUN` habilita el core continuamente;
- `STEP` habilita exactamente un ciclo;
- no se utiliza clock gating;
- Register File y Data Memory poseen puertos de debug independientes;
- la Debug Unit solamente observa el estado del procesador;
- los latches se congelan al iniciar un snapshot;
- la memoria utilizada se registra mediante un bitmap;
- una posición utilizada puede contener cero;
- accesos repetidos a una misma palabra cuentan una sola vez;
- `D` solicita el snapshot completo;
- no se permite tomar snapshots durante RUN;
- las respuestas normales utilizan el buffer del protocolo;
- el snapshot utiliza un stream directo hacia UART TX;
- HALT sigue siendo responsable de terminar la ejecución y vaciar el pipeline;
- el protocolo utiliza respuestas explícitas y códigos de error.

Esta separación modular permite verificar cada capa independientemente y facilita la implementación del software de PC y la futura conexión física con la placa Basys 3.
