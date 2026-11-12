# Validación end-to-end del sistema

## Objetivo

Antes de utilizar la Basys 3 física se realizó una validación end-to-end para comprobar que las capas desarrolladas de forma independiente funcionaran correctamente al integrarse.

La validación abarca desde el programa escrito en assembly hasta la ejecución del procesador y el retorno de la información de debug hacia el software de PC.

La cadena completa validada es:

```text
Assembly
    ↓
Assembler Python
    ↓
ProcessorClient
    ↓
SerialLink / pySerial
    ↓
Puerto serie virtual
    ↓
UART RX RTL
    ↓
Controlador de protocolo
    ↓
Program Loader
    ↓
Procesador RISC-V segmentado
    ↓
Debug Unit
    ↓
UART TX RTL
    ↓
Parser de snapshot
    ↓
TUI
```

## Diferencia respecto de las pruebas anteriores

Las pruebas unitarias de software utilizaban transportes simulados en Python.

En esta validación el software utiliza `SerialLink`, exactamente igual que lo hará posteriormente con la placa física.

Los bytes son enviados hacia un pseudo-terminal de Linux y transformados en una señal UART 8N1. De esta forma atraviesan `uart_rx.sv`, el controlador de protocolo y todos los módulos reales del sistema.

Las respuestas recorren el camino inverso mediante `uart_tx.sv`.

Por lo tanto, Python no simula el comportamiento del procesador: el procesador ejecutado es el RTL real dentro de XSim.

## Puerto serie virtual

Linux permite crear un pseudo-terminal o PTY.

Durante la prueba se crea un enlace estable:

```text
/tmp/riscv_pipeline_uart
```

que apunta a un dispositivo `/dev/pts/N`.

Para pySerial este dispositivo se comporta como un puerto serie convencional.

Esto permite mantener la misma arquitectura del software para simulación y hardware:

```text
Simulación:
SerialLink -> /tmp/riscv_pipeline_uart

Placa:
SerialLink -> /dev/ttyUSB... o equivalente
```

Las capas superiores del software no necesitan conocer la diferencia.

## Timing acelerado

Simular una UART de 115200 baud junto con un clock de 100 MHz requiere una gran cantidad de ciclos de XSim por cada byte.

Por este motivo se creó `processor_system_virtual_top.sv`, utilizado exclusivamente durante esta prueba.

Los parámetros empleados son:

```text
CLK_FREQ = 1 MHz
BAUD_RATE = 62500
OVERSAMPLING = 16
```

Esto genera 16 clocks exactos por bit.

No se modificó el RTL productivo ni el protocolo.

La configuración destinada a la Basys 3 continúa siendo 100 MHz y 115200 baud.

## Prueba mínima del enlace

Antes de ejecutar programas completos se realizó un smoke test utilizando el comando `Q`.

El recorrido verificado fue:

```text
Python
→ puerto virtual
→ UART RX RTL
→ controlador
→ respuesta q
→ UART TX RTL
→ Python
```

El procesador respondió correctamente con estado `READY`.

Esto permitió comprobar el enlace antes de incorporar carga de programas y snapshots.

## Validación automática completa

La prueba `simulation/e2e_rtl.py` utiliza directamente:

```text
assemble_program()
SerialLink
ProcessorClient
parse_snapshot()
```

y se comunica con el RTL simulado a través del mismo protocolo utilizado por la placa.

### Carga y ejecución

Se verificó:

```text
assembly
→ código máquina
→ L
→ W
→ E
→ ACK
→ READY
```

Posteriormente se utilizaron comandos STEP y RUN.

### STEP

Se comprobó que cada comando `S` produzca exactamente un ciclo del pipeline.

Después de cada STEP se solicitaron snapshots para verificar PC y latches.

Entre otros resultados:

```text
STEP 1:
IF PC = 4
IF/ID PC = 0

STEP 2:
IF PC = 8
ID/EX PC = 0
```

### RUN, HALT y vaciado

El programa pudo continuar desde el estado alcanzado mediante STEP utilizando RUN.

Se verificó la llegada a HALT y que el procesador finalice con:

```text
status = HALTED
pipeline_empty = 1
```

Esto confirma que HALT no descarta instrucciones anteriores todavía presentes en el pipeline.

### Registros y memoria

Se verificaron los valores finales mediante el snapshot completo y también mediante los comandos individuales `G` y `M`.

Esto valida dos caminos independientes de observación del estado.

### Reprogramación

Luego de finalizar un programa se cargó otro sin reiniciar ni recompilar el RTL.

El segundo programa ejecutó correctamente.

También se comprobó que el registro de memoria utilizada del Debug Unit se reinicie al comenzar una nueva carga.

Esto demuestra el mecanismo de programación dinámica requerido por el trabajo.

### Control de flujo

Se ejecutó un programa representativo con:

```text
BNE
loop
JAL
JALR
flush
HALT
```

Los valores finales demostraron que las instrucciones ubicadas en caminos incorrectos fueron eliminadas correctamente.

### Errores de protocolo

También se inyectaron errores reales a través de la UART.

Se comprobaron:

```text
NACK 01 -> comando desconocido
NACK 02 -> argumento inválido
NACK 03 -> dirección inválida
NACK 04 -> error de carga
NACK 05 -> operación no permitida en el estado actual
```

### Programa sin HALT

Se cargó un programa con un loop infinito.

Después de RUN, una consulta Q confirmó que el sistema permanecía en:

```text
RUNNING
```

También se verificó que comandos no permitidos durante ejecución fueran rechazados.

Este comportamiento es deliberado: el procesador no intenta detectar automáticamente el final de un programa que no contiene HALT.

## Validación con la TUI

Además de la prueba automática se utilizó manualmente la aplicación Textual contra el RTL ejecutándose en XSim.

La TUI detectó:

```text
/tmp/riscv_pipeline_uart - UART virtual XSim
```

y permitió realizar:

```text
Conectar
LOAD
STEP
STEP
SNAPSHOT
RUN
```

La interfaz mostró correctamente:

```text
estado del procesador
PC
IF/ID
ID/EX
EX/MEM
MEM/WB
32 registros
memoria utilizada
```

Luego de RUN se observó estado `HALTED` y pipeline vacío.

Por lo tanto también quedó validada la integración visual completa del sistema de debug.

## Regresión posterior

Luego de agregar la infraestructura de simulación se repitieron las pruebas existentes para comprobar que no hubiera regresiones.

Los resultados fueron:

```text
Software Python:
38 / 38 tests PASS

processor_system_uart_tb:
27 / 27 checks PASS

debug_uart_snapshot_tb:
45 / 45 checks PASS

execution_modes_tb:
88 / 88 checks PASS

End-to-end PC ↔ RTL:
PASS
```

También se verificaron cero errores de framing UART en los testbenches correspondientes.

## Evaluación de una Basys 3 virtual

Se evaluó utilizar un simulador visual específico de Basys 3.

Se decidió no incorporarlo como requisito de validación debido a que la integración funcional relevante para este proyecto ya se encuentra cubierta por XSim.

Los simuladores visuales de placa resultan principalmente útiles para representar periféricos como:

```text
switches
botones
LEDs
displays
```

pero no sustituyen la validación física de:

```text
constraints XDC
pines
clock de 100 MHz
USB-UART
síntesis
place and route
timing
bitstream
comportamiento eléctrico
```

Incorporar un segundo simulador tampoco aumentaría significativamente la cobertura del pipeline, UART, protocolo o software, que ya fueron probados en conjunto.

Por este motivo se conserva como posible herramienta opcional para visualizar el futuro top de placa, pero no forma parte del criterio de aprobación funcional.

## Resultado

Después de esta etapa se considera validada en simulación la cadena:

```text
software real de PC
↕
puerto UART virtual
↕
UART RTL
↕
protocolo
↕
loader
↕
pipeline
↕
Debug Unit
```

Por lo tanto, el paso hacia la Basys 3 física queda concentrado principalmente en aspectos propios de implementación hardware:

```text
top de placa
constraints
clock físico
UART física
síntesis
implementación
timing
generación de bitstream
programación de FPGA
prueba eléctrica real
```
