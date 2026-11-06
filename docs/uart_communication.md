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
- recibir confirmaciones y códigos de error.

La arquitectura se diseñó de forma modular para separar claramente:

1. transporte físico UART;
2. interpretación del protocolo;
3. carga de programas;
4. control de ejecución;
5. acceso de debug.

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
     |           |          |
     |           |          |
     v           v          v
program_loader  core       debug
     |                       |
     v                       |
    IMEM                     |
                             |
                             v
                    Register File / DMEM
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
clock FPGA  = 100 MHz
baud rate   = 115200
data bits   = 8
parity      = none
stop bits   = 1
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

Las respuestas principales son:

| Respuesta | Hex | Significado |
|---|---:|---|
| ACK | `0x06` | comando aceptado |
| NACK | `0x15` | comando rechazado |
| `g` | `0x67` | respuesta de registro |
| `m` | `0x6D` | respuesta de memoria |
| `q` | `0x71` | respuesta de estado |

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
```

respetan `cycle_enable`.

La unidad de control de HALT también respeta este enable.

Además, la escritura del Register File desde WB se habilita solamente cuando:

```text
wb_write_enable_raw && cycle_enable
```

Esto evita que un valor de WB sea escrito repetidamente mientras el pipeline está detenido.

No se gatea físicamente el clock.

Esta decisión mantiene el diseño completamente síncrono y utiliza los enables existentes de los registros.

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

La operación actual devuelve una palabra completa de 32 bits y exige:

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

## 19. Códigos de error

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

## 20. Controlador de protocolo

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
- seleccionar direcciones de debug;
- construir respuestas;
- emitir ACK/NACK;
- reportar estado;
- rechazar operaciones no permitidas.

La respuesta máxima actual contiene siete bytes:

```text
m + addr16 + data32
```

por lo que se utiliza un pequeño buffer interno de respuesta.

---

## 21. Integración de UART TX con el protocolo

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

---

## 22. Verificación aislada del protocolo

El testbench:

```text
tb/system_protocol_controller_tb.sv
```

verificó:

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

## 23. Verificación end-to-end

El testbench:

```text
tb/processor_system_uart_tb.sv
```

simula una sesión completa PC-FPGA.

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
comando desconocido -> NACK
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

## 24. Regresión completa

Después de incorporar:

- `baud_gen`;
- `uart_rx`;
- `uart_tx`;
- controlador de protocolo;
- `cycle_enable`;
- puertos de debug;
- integración superior;
- nuevos testbenches;

se ejecutó nuevamente toda la suite.

Resultado:

```text
FULL REGRESSION SUMMARY
PASSED: 49
FAILED: 0
TOTAL : 49
```

Entre los testbenches UART se encuentran:

```text
baud_gen_tb
uart_rx_tb
uart_tx_tb
uart_loopback_tb
uart_program_loader_tb
system_protocol_controller_tb
processor_system_uart_tb
```

Los testbenches anteriores del procesador también continuaron pasando.

Esto demuestra que la incorporación de UART y del control RUN/STEP no introdujo regresiones sobre las funcionalidades ya verificadas.

---

## 25. Decisiones de diseño principales

Las decisiones más importantes son:

- UART y protocolo son capas diferentes;
- UART solamente convierte entre bits y bytes;
- el protocolo asigna significado a cada byte;
- RX utiliza oversampling por 16;
- RX sincroniza la entrada asíncrona mediante dos flip-flops;
- TX y RX comparten la misma referencia de `baud_tick`;
- los campos multibyte del protocolo se transmiten MSB first;
- los bits dentro de cada byte UART se transmiten LSB first;
- el Program Loader permanece separado del controlador general;
- `RUN` habilita el core continuamente;
- `STEP` habilita exactamente un ciclo;
- no se utiliza clock gating;
- Register File y Data Memory poseen puertos de debug independientes;
- el protocolo utiliza respuestas explícitas y códigos de error;
- HALT sigue siendo responsable de terminar la ejecución y vaciar el pipeline.

Esta separación modular permite verificar cada capa independientemente y facilita la futura conexión con la interfaz de software de la PC y con la placa Basys 3.
