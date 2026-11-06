# Carga dinámica de programas

## 1. Objetivo

El procesador debe poder recibir un programa desde una PC, almacenarlo en la memoria de instrucciones y ejecutarlo sin volver a sintetizar ni generar un nuevo bitstream para la FPGA.

El programa fuente se escribe en lenguaje ensamblador, pero el procesador ejecuta palabras de lenguaje máquina de 32 bits. Por este motivo se separan claramente dos responsabilidades:

- **Software de la PC:** traduce el programa ensamblador a instrucciones de 32 bits, resuelve labels y genera la secuencia de datos que será enviada.
- **FPGA:** recibe bytes, interpreta el protocolo de carga, reconstruye las palabras de 32 bits y las escribe en la Instruction Memory.

La FPGA no necesita interpretar texto ensamblador.

---

## 2. Flujo general

El flujo previsto para la programación dinámica es:

```text
programa ensamblador
        |
        v
assembler / software de PC
        |
        v
palabras de lenguaje máquina de 32 bits
        |
        v
transmisión por UART
        |
        v
UART RX
        |
        v
bytes recibidos
        |
        v
Program Loader
        |
        v
puerto de programación
        |
        v
Instruction Memory
        |
        v
procesador segmentado
```

La comunicación UART es el mecanismo de transporte. La interpretación de los bytes recibidos y la escritura de memoria pertenecen al `program_loader`.

En la implementación actual, la etapa física UART todavía no está conectada. Los testbenches generan directamente `rx_byte_valid` y `rx_byte_data`, simulando la salida que posteriormente deberá producir `uart_rx`.

---

## 3. Ensamblador, lenguaje máquina y memoria de instrucciones

Una instrucción escrita como:

```asm
add x3, x1, x2
```

es lenguaje ensamblador.

Su representación ejecutable es una palabra de 32 bits:

```text
0x002081B3
```

La Instruction Memory almacena estas palabras de 32 bits.

El procesador utiliza direcciones en bytes:

```text
PC = 0, 4, 8, 12, ...
```

mientras que la memoria se organiza por palabras:

```text
memory[0], memory[1], memory[2], memory[3], ...
```

La relación es:

```text
word_index = address >> 2
```

Por ejemplo:

```text
PC = 20  ->  memory[5]
```

La memoria implementada posee actualmente 256 palabras de 32 bits:

```text
256 x 32 bits = 8192 bits = 1024 bytes
```

Por lo tanto, las direcciones de instrucciones válidas se encuentran entre `0` y `1020`, siempre alineadas a cuatro bytes.

---

## 4. Instruction Memory programable

Originalmente la memoria de instrucciones sólo poseía el camino de lectura utilizado por IF.

La interfaz fue ampliada con un puerto de programación:

```systemverilog
input logic        clk;
input logic        program_write_enable;
input logic [31:0] program_write_address;
input logic [31:0] program_write_data;
```

Se mantienen dos comportamientos diferentes:

- **lectura del procesador:** combinacional;
- **escritura del cargador:** síncrona en el flanco positivo del clock.

Conceptualmente:

```text
                          +----------------------+
PC ---------------------> |                      | ---> instruction
                          |  Instruction Memory  |
program_write_address --> |                      |
program_write_data -----> |                      |
program_write_enable ---> |                      |
                          +----------------------+
```

La memoria de instrucciones **no se borra con el reset del core**. Esto es necesario para poder:

1. cargar un programa;
2. resetear el procesador para colocarlo en un estado inicial conocido;
3. conservar las instrucciones cargadas;
4. comenzar la ejecución desde `PC = 0`.

---

## 5. Protocolo abstracto de carga

Se definió un protocolo simple basado en tres comandos.

| Comando | Byte | ASCII | Función |
|---|---:|---|---|
| BEGIN LOAD | `0x4C` | `L` | Inicia una carga e informa la cantidad de instrucciones |
| WRITE WORD | `0x57` | `W` | Escribe una palabra de 32 bits en una dirección |
| END LOAD | `0x45` | `E` | Finaliza y valida la carga |

### 5.1 BEGIN LOAD

Formato:

```text
'L'
N[15:8]
N[7:0]
```

`N` representa la cantidad de instrucciones que se espera recibir.

Ejemplo para cuatro instrucciones:

```text
4C 00 04
```

El loader rechaza:

- `N = 0`;
- cantidades mayores a la profundidad de Instruction Memory.

---

## 6. Escritura de una instrucción

Cada escritura utiliza:

```text
'W'
ADDR[15:8]
ADDR[7:0]
DATA[31:24]
DATA[23:16]
DATA[15:8]
DATA[7:0]
```

La dirección se expresa en **bytes**, igual que el PC.

Ejemplo:

```text
57 00 08 00 20 81 B3
```

representa:

```text
address = 0x0008
data    = 0x002081B3
```

por lo tanto:

```text
memory[2] = 0x002081B3
```

El loader valida que la dirección:

- sea múltiplo de cuatro;
- esté dentro del rango de Instruction Memory;
- no se reciba una cantidad de escrituras mayor a la anunciada en `BEGIN LOAD`.

Una escritura inválida activa `load_error` y no genera `imem_write_enable`.

---

## 7. Orden de bytes

UART entrega bytes de 8 bits, mientras que cada instrucción posee 32 bits.

Se necesitan cuatro bytes para reconstruir una instrucción.

El protocolo utiliza orden **MSB first**:

```text
0x00A00093
```

se transmite como:

```text
00 A0 00 93
```

y se reconstruye como:

```text
{byte_0, byte_1, byte_2, byte_3}
```

Este orden pertenece al protocolo de comunicación y no modifica la semántica interna de las instrucciones RISC-V.

---

## 8. Finalización de una carga

La PC envía:

```text
'E'
```

El loader considera exitosa la carga solamente cuando:

```text
load_error == 0
```

y:

```text
received_instructions == expected_instructions
```

En ese caso genera un pulso `load_done`.

Una carga incompleta o que haya presentado algún error no produce una finalización válida.

---

## 9. Máquina de estados del Program Loader

El módulo `program_loader` recibe:

```systemverilog
rx_byte_valid
rx_byte_data[7:0]
```

y genera:

```systemverilog
imem_write_enable
imem_write_address
imem_write_data
```

Los estados implementados son:

```text
STATE_IDLE
STATE_COUNT_HI
STATE_COUNT_LO
STATE_WAIT_COMMAND
STATE_ADDRESS_HI
STATE_ADDRESS_LO
STATE_DATA_31_24
STATE_DATA_23_16
STATE_DATA_15_8
STATE_DATA_7_0
```

### Estado IDLE

Espera el comando `L`.

Los demás bytes son ignorados, permitiendo que el protocolo vuelva a sincronizarse esperando un nuevo comienzo de carga.

### Recepción de cantidad

`STATE_COUNT_HI` y `STATE_COUNT_LO` reconstruyen `N`.

Si la cantidad es válida:

```text
load_active = 1
```

y se pasa a esperar comandos.

### Recepción de una escritura

Después de `W` se reciben:

1. dos bytes de dirección;
2. cuatro bytes de datos.

Al recibir el último byte se valida la operación y, si es correcta, se genera durante un ciclo:

```text
imem_write_enable = 1
```

### END

El comando `E` finaliza la transacción y compara la cantidad recibida con la cantidad anunciada.

---

## 10. Estado del procesador durante la programación

No se permite que el core ejecute normalmente mientras se modifica Instruction Memory.

Durante una carga se utiliza:

```text
core_reset   = 1
loader_reset = 0
```

De esta manera:

- el PC permanece en cero;
- los registros del pipeline quedan vacíos;
- el Register File queda en su estado de reset;
- el Program Loader continúa funcionando;
- Instruction Memory puede recibir escrituras.

Cuando la carga termina correctamente:

```text
core_reset = 0
```

y el procesador comienza a ejecutar desde `PC = 0`.

Esto evita que el procesador lea una mezcla entre instrucciones del programa anterior y palabras que todavía están siendo cargadas.

---

## 11. Reprogramación dinámica

La reprogramación no requiere borrar toda la Instruction Memory.

Ejemplo:

```text
Programa A: 4 instrucciones
Programa B: 3 instrucciones
```

Al cargar el programa B se sobrescriben:

```text
memory[0]
memory[1]
memory[2]
```

mientras que:

```text
memory[3]
```

puede conservar el valor anterior.

Esto no genera un problema siempre que el programa nuevo posea un HALT alcanzable antes de ejecutar contenido residual.

El flujo utilizado es:

```text
cargar programa A
        |
        v
ejecutar programa A
        |
        v
HALT
        |
        v
pipeline vacío
        |
        v
activar reset del core
        |
        v
cargar programa B
        |
        v
liberar reset del core
        |
        v
ejecutar programa B
```

No existe una nueva síntesis entre ambas ejecuciones.

---

## 12. Relación con HALT

La instrucción de parada adoptada por diseño es:

```text
HALT = 32'h0000000B
```

HALT no pertenece a las 32 instrucciones RISC-V exigidas por el enunciado. Es una extensión propia utilizada como mecanismo explícito de finalización.

Su función es diferente de `END LOAD`:

- `END LOAD` finaliza la **transferencia del programa**;
- `HALT` finaliza la **ejecución del programa**.

Al aceptar HALT:

1. se detiene el ingreso de instrucciones nuevas;
2. el procesador entra en `DRAINING`;
3. las instrucciones anteriores continúan avanzando;
4. se alcanza `HALTED` solamente cuando el pipeline queda vacío.

Si el programa no contiene un HALT alcanzable, el procesador continúa ejecutando indefinidamente hasta que una acción externa, como reset, interrumpa la ejecución.

---

## 13. Política de reset y memorias

Para la reprogramación se adoptaron las siguientes decisiones.

### Register File

El reset del core lleva los registros a su estado inicial.

Esto permite que un programa nuevo no herede resultados arquitectónicos del programa anterior.

### Pipeline

El reset limpia los registros intermedios.

Por lo tanto, antes de una nueva ejecución no quedan instrucciones del programa anterior circulando por IF/ID, ID/EX, EX/MEM o MEM/WB.

### Data Memory

No es necesario borrar automáticamente la memoria de datos para cargar un nuevo programa.

El contenido puede conservarse entre ejecuciones. Si un programa requiere determinadas posiciones inicializadas, deberá escribirlas explícitamente o utilizarse un mecanismo específico de inicialización.

### Instruction Memory

No se borra con reset.

Durante una nueva carga sólo se sobrescriben las direcciones recibidas.

Esta decisión evita borrar el programa recién transferido antes de ejecutarlo y elimina ciclos de limpieza innecesarios.

---

## 14. Verificación aislada del cargador

Testbench:

```text
tb/program_loader_imem_tb.sv
```

Se verificaron:

- reset del loader;
- `BEGIN LOAD`;
- cantidad esperada;
- recepción de cuatro bytes por instrucción;
- reconstrucción de palabras de 32 bits;
- escritura de Instruction Memory;
- direcciones en bytes;
- orden MSB first;
- finalización válida;
- reprogramación con un programa más corto;
- conservación de posiciones no sobrescritas;
- detección de dirección desalineada;
- rechazo de una carga inválida.

Resultado:

```text
Tests run    : 19
Tests passed : 19
Tests failed : 0
Load done    : 2
```

---

## 15. Verificación integrada con el procesador

Testbench:

```text
tb/pipeline_program_loading_tb.sv
```

### Programa A

Se cargó dinámicamente:

```asm
addi x1, x0, 10
addi x2, x0, 20
add  x3, x1, x2
HALT
```

Resultados:

```text
x1 = 10
x2 = 20
x3 = 30
```

El programa alcanzó HALT con el pipeline vacío.

### Reprogramación

Se activó reset solamente sobre el core.

Se comprobó que:

- `x1`, `x2` y `x3` regresaron a cero;
- Instruction Memory conservó el programa cargado.

Luego se escribió dinámicamente:

```asm
addi x5, x0, 7
addi x6, x5, 8
HALT
```

Resultados:

```text
x5 = 7
x6 = 15
```

Los registros utilizados por el programa anterior permanecieron en cero.

Resultado total:

```text
Tests run    : 31
Tests passed : 31
Tests failed : 0
Load done    : 2
```

Esto demuestra la reprogramación de Instruction Memory y la ejecución de dos programas diferentes sin resintetizar el procesador.

---

## 16. Regresión completa

La incorporación de la programación dinámica modificó la interfaz de Instruction Memory, IF y `pipeline_core`.

Además, algunos testbenches antiguos todavía asumían interfaces o comportamientos anteriores, por ejemplo:

- ALU Control basado directamente en opcode;
- WB basado directamente en opcode;
- flush que invalidaba `valid` pero conservaba datos;
- etapas sin las señales actuales de control pipelineado.

Estos testbenches fueron actualizados para comprobar el RTL vigente, sin modificar el comportamiento del procesador para satisfacer pruebas obsoletas.

Resultado de la regresión completa:

```text
PASSED: 42
FAILED: 0
```

De esta manera se comprobó que la incorporación del cargador y del puerto de programación no produjo regresiones sobre la funcionalidad existente.

---

## 17. Integración con UART

La capa de carga dinámica ya se encuentra integrada con la recepción UART.

El camino validado es:

```text
señal UART
     |
     v
   uart_rx
     |
     v
rx_byte_valid / rx_byte_data
     |
     v
Program Loader
     |
     v
Instruction Memory
     |
     v
Pipeline Core
```

El testbench:

```text
tb/uart_program_loader_tb.sv
```

transmitió un programa completo como tramas UART reales simuladas y verificó:

```text
UART bytes   : 32
Frame errors : 0
IMEM writes  : 4
Load done    : 1
Tests        : 12/12 PASS
```

La arquitectura UART completa, junto con RUN, STEP, consultas de estado y puertos de debug, se documenta en:

```text
docs/uart_communication.md
```

---

## 18. Decisiones de diseño principales

Las decisiones adoptadas son:

- el ensamblado se realiza en la PC y no dentro de la FPGA;
- UART transporta bytes, no instrucciones textuales;
- cada instrucción requiere cuatro bytes;
- el protocolo utiliza orden MSB first;
- las direcciones enviadas son direcciones en bytes;
- `BEGIN LOAD` informa la cantidad de instrucciones;
- cada `WRITE WORD` incluye explícitamente dirección y palabra;
- `END LOAD` valida la cantidad efectivamente recibida;
- el core permanece en reset durante la carga;
- el loader posee reset independiente;
- Instruction Memory no se borra con reset;
- una nueva carga sobrescribe únicamente las posiciones indicadas;
- HALT y END LOAD son mecanismos diferentes;
- la ejecución solamente termina después de HALT y del vaciado completo del pipeline.

Estas decisiones mantienen separado el transporte, la programación de memoria y la ejecución del procesador, facilitando la verificación y la futura integración con UART.
