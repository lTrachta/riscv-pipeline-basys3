# Paso 24 — Integración y validación física del procesador RISC-V en Basys 3

**Asignatura:** Arquitectura de Computadoras
**Proyecto:** Procesador RISC-V segmentado de cinco etapas, Debug Unit UART e interfaz de PC
**Plataforma:** Digilent Basys 3 (Artix-7 XC7A35T-1CPG236C)
**Herramientas:** Vivado 2025.1; SystemVerilog; Python 3; pySerial; Linux
**Repositorio:** `lTrachta/riscv-pipeline-basys3`
**Estado:** integración física validada; cierre documental del paso 24

> **Alcance de las conclusiones.** Los resultados de tiempo se toman de los reportes de implementación conservados en la documentación del proyecto; las comprobaciones físicas se basan en el registro de Vivado, las capturas de la TUI, las fotografías de placa y la salida de `software.hardware_validation` aportadas durante la validación. Una prueba exitosa de los programas seleccionados no implica cobertura exhaustiva de todas las instrucciones o de todas las condiciones de hardware.

## 1. Objetivo y requisitos atendidos

Implementar en una placa Basys 3 real el sistema desarrollado y verificado previamente por simulación: un procesador RISC-V con etapas **IF, ID, EX, MEM y WB**, control de hazards y de finalización, carga dinámica de programas, comunicación USB-UART, Debug Unit y software de PC. La integración física debe permitir comprobar programación de FPGA, clock, reset, recepción/transmisión UART, ejecución `RUN` y `STEP`, recuperación del estado arquitectónico y vaciado del pipeline tras `HALT`.

El enunciado exige que el clock no sea intervenido para ejecutar paso a paso: se conserva un reloj regular y el control de avance se implementa mediante enables internos. También exige cargar y reemplazar programas por UART **sin resintetizar ni volver a programar la FPGA**.

## 2. Arquitectura integrada

```text
                         PC (Linux)
                 ensamblador y TUI Python
                           |
                         pySerial
                           |
                        USB-UART
                           |
                  FTDI en Basys 3
                           |
                    RsRx / RsTx
                           |
                uart_rx / uart_tx
                           |
              system_protocol_controller
                     /          \
               program_loader   Debug Unit
                     |              |
                   IMEM       registros / pipeline / DMEM
                     |              ^
                     v              |
                CPU RISC-V 5 etapas
                  IF-ID-EX-MEM-WB
                     |
               memoria de datos
```

La FPGA implementa `basys3_top`, `processor_system`, procesador, memorias y comunicaciones. El software de PC ensambla y carga los programas y solicita estados, pasos y snapshots a través del mismo UART utilizado en la validación automática.

## 3. Hardware y conexiones de la placa

| Recurso | Puerto RTL | Pin FPGA |
|---|---|---|
| Oscilador de entrada, 100 MHz | `CLK100MHZ` | W5 |
| Botón central de reset | `btnC` | U18 |
| UART PC → FPGA | `RsRx` | B18 |
| UART FPGA → PC | `RsTx` | A18 |
| LEDs de diagnóstico | `led[15:0]` | Archivo `constraints/basys3.xdc` |

FPGA seleccionada en Vivado: `xc7a35tcpg236-1`. Formato UART: **115200 baudios, 8 bits de datos, sin paridad y 1 bit de parada (8N1)**.

Los clocks, reset, UART y LEDs están integrados en `rtl/basys3_top.sv`, mientras que las restricciones físicas están en `constraints/basys3.xdc` con `IOSTANDARD LVCMOS33`.

## 4. Clock, camino crítico y cierre de timing

### 4.1 Primera implementación a 100 MHz

La entrada física de Basys 3 entrega **100 MHz** (período de **10 ns**). En la implementación inicial, al intentar ejecutar todo `processor_system` con ese reloj, Vivado informó:

| Métrica | Resultado inicial |
|---|---:|
| WNS (setup) | −3.558 ns |
| TNS (setup) | −1036.007 ns |
| Endpoints con violaciones de setup | 601 |
| Requirement | 10.000 ns |
| Data Path Delay del peor camino | 13.519 ns |
| Logic Levels | 25 |

El camino crítico reportado conectaba lógica de EX/MEM con la actualización del PC. Un WNS negativo indicaba que el diseño **no satisfacía la restricción de 100 MHz** y no podía considerarse cerrado a esa frecuencia.

### 4.2 Clocking Wizard y solución adoptada

Se incorporó el IP **Clocking Wizard** (`ip/clk_wiz_0/clk_wiz_0.xci`) para mantener la entrada física de 100 MHz y generar un reloj interno de **50 MHz** (período de **20 ns**). Ese clock interno alimenta el procesador, loader, Debug Unit y UART. La configuración relevante de `processor_system` es:

```systemverilog
.CLK_FREQ       (50_000_000),
.BAUD_RATE      (115_200),
.OVERSAMPLING   (16),
.IMEM_DEPTH     (256),
.DATA_MEM_DEPTH (256)
```

El reset del sistema considera la señal `locked` del Clocking Wizard: mientras no exista clock estable, el procesador permanece en reset. También existe reset inicial temporizado de aproximadamente **10,49 ms**, y reset manual mediante `btnC`. Se sincroniza la desactivación del reset con el clock interno.

### 4.3 Reporte final post-implementation

| Métrica | Resultado a 50 MHz |
|---|---:|
| WNS (setup) | **+3.103 ns** |
| TNS (setup) | **0.000 ns** |
| WHS (hold) | **+0.033 ns** |
| THS (hold) | **0.000 ns** |

Vivado informó: **`All user specified timing constraints are met.`** Los clocks registrados son `CLK100MHZ` (10 ns) y `clk_out1_clk_wiz_0` (20 ns). La implementación final cerró los chequeos de setup y hold especificados. No se declara aquí una medición experimental de frecuencia máxima: **50 MHz es la frecuencia implementada y verificada**.

## 5. Memorias y decisión de implementación

| Memoria | Profundidad | Ancho |
|---|---:|---:|
| IMEM (instrucciones) | 256 | 32 bits |
| DMEM (datos) | 256 | 32 bits |

Se investigó la alternativa **Block Memory Generator**, pero las memorias del datapath validado usan lectura asíncrona. La sustitución directa por BRAM con lectura síncrona alteraría la temporización y la microarquitectura. La síntesis original infirió memorias distribuidas (**Distributed RAM**), con primitivas de tipo `RAM64M` para IMEM y `RAM128X1D` para DMEM, por lo que se preservó el comportamiento del pipeline validado.

## 6. Síntesis, implementación y bitstream

El flujo completado fue:

```text
RTL → síntesis → optimización → placement → optimización física
    → routing → análisis temporal → DRC → generación de bitstream
```

Según la documentación de implementación, el routing final no dejó redes sin enrutar ni conflictos de solapamiento y el DRC final no presentó errores. Los constraints verificaron W5, U18, B18 y A18 para clock, reset y UART.

**Bitstream utilizado en hardware:** `vivado/bitstreams/riscv_pipeline_basys3.bit` (artefacto generado localmente; no versionado en Git).

**SHA-256 registrado del bitstream:**

```text
47b0df0cfe97ea0f70601cd2355abf5c8492e732450e1210a61348fcc9203d4a
```

La coincidencia de este hash con el registro anterior de preparación permite vincular la prueba física con el archivo binario declarado en el proyecto.

## 7. Detección de la Basys 3

La computadora reconoció el dispositivo USB de la placa mediante `lsusb`:

```text
ID 0403:6010 Future Technology Devices International, Ltd FT2232C/D/H Dual UART/FIFO IC
```

El puerto serie de la sesión de pruebas fue `/dev/ttyUSB1`, identificado por pySerial como **Digilent USB Device**, con `VID:PID=0403:6010`. La conexión UART real se validó posteriormente con respuestas correctas del procesador. La numeración de puertos en Linux puede variar entre conexiones.

## 8. Programación de la FPGA por JTAG

Vivado Hardware Manager detectó la FPGA `xc7a35t` inicialmente sin programación (`DONE status = 0`). Posteriormente se utilizó `program_hw_devices` con el bitstream indicado. La consola informó:

```text
End of startup status: HIGH
Device xc7a35t ... is programmed with a design that has no supported debug core(s) in it.
```

El mensaje **«no supported debug core(s)»** se refiere a la ausencia de núcleos de depuración de Vivado (por ejemplo, ILA), **no** a la ausencia de la Debug Unit UART diseñada para este proyecto. La programación se confirmó mediante el registro de Vivado y la posterior ejecución física satisfactoria.

Se observó el parpadeo de **LED15 (heartbeat)**. Al presionar **btnC** se encendió **LED9 (reset)**, coherente con el mapeo RTL de señales de diagnóstico.

## 9. Mapeo lógico de LEDs

| LED | Señal | Interpretación |
|---|---|---|
| LED0 | `program_loaded` | Programa cargado |
| LED1 | `core_running` | Core ejecutando |
| LED2 | `core_draining` | Vaciado de pipeline en curso |
| LED3 | `core_halted` | Ejecución detenida por HALT |
| LED4 | `core_pipeline_empty` | Pipeline vacío |
| LED5 | `uart_error_latched` | Error de trama UART retenido |
| LED8:6 | `status_code` | Código de estado |
| LED9 | `reset` | Reset activo |
| LED15 | Bit alto de contador de heartbeat | Actividad del clock interno |

Varios LEDs pueden encenderse a la vez, porque representan condiciones independientes. Las fotografías son evidencia visual de placa encendida y estados de LED; la identificación temporal precisa de un LED intermitente se apoya en la observación informada durante la prueba.

## 10. Validación automática PC ↔ UART ↔ FPGA

### 10.1 Smoke test

La prueba de comunicación mínima se ejecutó con:

```bash
python -m software.hardware_validation /dev/ttyUSB1 --smoke-only
```

Salida:

```text
Estado inicial: READY
PASS: UART PC <-> Basys 3
```

### 10.2 Validación integral automatizada

Comando:

```bash
python -m software.hardware_validation /dev/ttyUSB1
```

Resumen de resultados:

| Caso | Comprobaciones | Resultado |
|---|---|---|
| UART | Estado inicial `READY` | PASS |
| ALU | `x1=5`, `x2=7`, `x3=12` | PASS |
| ALU | `HALTED`, pipeline vacío | PASS |
| Memoria | `x1=64`, `x2=85`, `x3=85`, `DMEM[64]=85` | PASS |
| Memoria | `HALTED`, pipeline vacío | PASS |
| Control flow | `x1=0`, `x2=6`, `x3=24`, `x4=0` | PASS |
| Control flow | `x5=7`, `x6=41`, `x7=36`, `x8=0` | PASS |
| Control flow | `HALTED`, pipeline vacío | PASS |

El script terminó literalmente con:

```text
PASS VALIDACION FISICA BASYS 3
PC -> USB UART -> FPGA -> pipeline -> USB UART -> PC
```

El caso de control de flujo ejercita un lazo con `bne` y transferencias por `jal` y `jalr`; los destinos omitidos se distinguen por los valores cero en `x4` y `x8`. Las distintas cargas del script, hechas sin regenerar el bitstream, respaldan también la **reprogramación dinámica por UART**.

Los resultados íntegros se conservan en [`evidencias_basys3/logs/hardware_validation.txt`](evidencias_basys3/logs/hardware_validation.txt).

## 11. Verificación manual con la TUI

La aplicación se ejecutó con:

```bash
python -m software
```

La TUI confirmó conexión al dispositivo Digilent en `/dev/ttyUSB1` a **115200 8N1**. En ella se abrieron programas `.S`, se cargaron con `LOAD`, se solicitaron snapshots, se ejecutó `STEP` y se continuó con `RUN`.

### 11.1 Estado inicial del programa `smoke.S`

```asm
.text
.globl _start
_start:
    addi x1, x0, 5
    addi x2, x0, 7
    add  x3, x1, x2
    HALT
```

Tras `LOAD` y snapshot inicial:

- Estado: `READY`.
- PC de IF: `0x00000000`.
- IF/ID: `BUBBLE`.
- Pipeline vacío: **sí**.
- Registros generales en cero.

### 11.2 Avance ciclo a ciclo (`STEP`)

| Momento | PC de IF | Registro IF/ID | Estado relevante |
|---|---|---|---|
| Antes de STEP | `0x00000000` | Burbuja | Pipeline vacío |
| STEP 1 | `0x00000004` | `addi x1, x0, 5` válido, PC `0x00000000` | La primera instrucción pasó a IF/ID |
| STEP 2 | `0x00000008` | `addi x2, x0, 7` válido, PC `0x00000004` | La siguiente instrucción pasó a IF/ID |

Después de estos primeros pasos los registros todavía muestran cero, lo que es consistente con que las instrucciones no alcanzaron aún la etapa WB. Las capturas evidencian **una transición de pipeline por orden STEP**, sin necesidad de manipular el clock físico.

### 11.3 Ejecución hasta HALT

Después de `RUN` en `smoke.S` la TUI mostró:

```text
Estado: HALTED
Pipeline vacío: sí
x1 = 5
x2 = 7
x3 = 12
```

Se observó una burbuja en IF/ID y el fin del programa; la finalización no dejó instrucciones válidas pendientes.

### 11.4 Prueba de memoria `memory.S`

Programa de almacenamiento y lectura:

```asm
.text
.globl _start
_start:
    addi x1, x0, 64
    addi x2, x0, 85
    sw   x2, 0(x1)
    lw   x3, 0(x1)
    HALT
```

La TUI mostró `HALTED`, pipeline vacío, `x1=64`, `x2=85`, `x3=85` y memoria usada en dirección `0x0040` con valor `0x00000055` (85 decimal).

### 11.5 Prueba de control de flujo `control_flow.S`

La TUI mostró estado `HALTED`, pipeline vacío y los registros esperados del ensayo `CONTROL FLOW`:

```text
x1=0, x2=6, x3=24, x4=0
x5=7, x6=41, x7=36, x8=0
```

Esta evidencia complementa el resultado automatizado al permitir observar directamente el estado arquitectónico final en la interfaz de usuario.

## 12. Programa sin HALT y recuperación del sistema

Se utilizó `programs/hardware_validation/no_halt.S` para comprobar la conducta del sistema frente a un programa sin instrucción de parada:

```asm
.text
.globl _start
_start:
    addi x1, x0, 0
loop:
    addi x1, x1, 1
    jal x0, loop
```

La TUI mostró **`RUNNING`** después de iniciar la ejecución, tal como corresponde a un programa que se repite y no contiene `HALT`. El reset físico mediante `btnC` permitió volver a un estado operativo, confirmado posteriormente mediante `Q → READY`. El propósito de esta prueba fue observar la ausencia de terminación automática cuando el programa carece de `HALT`; no se trata de una prueba de rendimiento ni de duración indefinida.

## 13. Inventario de evidencias conservadas

### 13.1 Logs y reproducibilidad

| Archivo | Contenido |
|---|---|
| [`logs/lsusb.txt`](evidencias_basys3/logs/lsusb.txt) | Enumeración USB; dispositivo FTDI `0403:6010` |
| [`logs/serial_ports.txt`](evidencias_basys3/logs/serial_ports.txt) | Puerto serie Digilent `/dev/ttyUSB1` |
| [`logs/hardware_validation.txt`](evidencias_basys3/logs/hardware_validation.txt) | Resultado `PASS` de ALU, memoria y control de flujo |
| [`logs/bitstream_sha256.txt`](evidencias_basys3/logs/bitstream_sha256.txt) | Hash SHA-256 del bitstream probado |
| [`logs/vivado_hardware_manager.txt`](evidencias_basys3/logs/vivado_hardware_manager.txt) | Extracto de consola de Vivado con detección JTAG y programación correcta |

### 13.2 Capturas y fotografías seleccionadas

Se incluyen **únicamente las evidencias relevantes para la validación**, sin conservar capturas de configuración inicial o de errores transitorios. El orden de los archivos se basa en su contenido técnico, no en la secuencia original de descarga.

| Archivo | Evidencia mostrada |
|---|---|
| [`basys3_foto_estado_a.png`](evidencias_basys3/capturas/basys3_foto_estado_a.png) | Placa física en funcionamiento con LEDs de diagnóstico activos |
| [`basys3_foto_estado_b.png`](evidencias_basys3/capturas/basys3_foto_estado_b.png) | Segundo estado visible de los LEDs de la Basys 3 |
| [`tui_smoke_inicial.png`](evidencias_basys3/capturas/tui_smoke_inicial.png) | `smoke.S`: snapshot inicial `READY`, IF/ID vacío |
| [`tui_smoke_step_1.png`](evidencias_basys3/capturas/tui_smoke_step_1.png) | `STEP` 1: IF PC `0x4`; primera instrucción válida en IF/ID |
| [`tui_smoke_step_2.png`](evidencias_basys3/capturas/tui_smoke_step_2.png) | `STEP` 2: IF PC `0x8`; segunda instrucción válida en IF/ID |
| [`tui_smoke_halted.png`](evidencias_basys3/capturas/tui_smoke_halted.png) | `RUN`: `HALTED`, pipeline vacío, `x3=12` |
| [`tui_memory_halted.png`](evidencias_basys3/capturas/tui_memory_halted.png) | Escritura y lectura de memoria: `DMEM[64]=85` |
| [`tui_control_flow_halted.png`](evidencias_basys3/capturas/tui_control_flow_halted.png) | Control de flujo y resultados finales de registros |
| [`tui_no_halt_running.png`](evidencias_basys3/capturas/tui_no_halt_running.png) | Programa sin HALT en estado `RUNNING` |

Los archivos de evidencia se conservan separados del código fuente; los bitstreams, cachés y archivos generados de Vivado no se versionan.

## 14. Reproducción de la prueba física

Con el bitstream disponible, la placa conectada y los drivers instalados:

```bash
# Desde la raíz del repositorio
cd ~/Documents/TP-ARQUI/riscv-pipeline-basys3
source .venv/bin/activate

# Comprobar la detección del dispositivo
lsusb
python -m serial.tools.list_ports -v

# Tras programar la FPGA por JTAG con Vivado,
# utilizar el puerto serie realmente enumerado:
python -m software.hardware_validation /dev/ttyUSB1 --smoke-only

# Partiendo de READY, ejecutar la validación completa:
python -m software.hardware_validation /dev/ttyUSB1

# Interfaz de usuario (no ejecutar simultáneamente
# con otro proceso que mantenga abierto el mismo UART):
python -m software
```

La validación automatizada parte del estado `READY`; si se realizan varias sesiones consecutivas, restablecer el procesador con `btnC` antes de repetirla. El nombre `/dev/ttyUSB1` fue válido en esta sesión y puede variar en otra conexión.

## 15. Conclusión del paso 24

Se completó la integración en una placa física Basys 3 del procesador RISC-V segmentado y de sus bloques de control y comunicación. La implementación cumplió las restricciones de temporización establecidas para el clock interno de 50 MHz; Vivado pudo programar la FPGA; Linux detectó el dispositivo USB-UART; y el software Python cargó y ejecutó programas en el hardware real, obteniendo resultados correctos de ALU, memoria y control de flujo.

El modo `STEP` permitió observar el avance de instrucciones entre IF e IF/ID, mientras que `RUN` completó los programas con `HALT` y reportó el pipeline vacío. Las pruebas de carga sucesiva permiten afirmar que se reprogramó la memoria de instrucciones a través de UART sin volver a sintetizar el procesador ni reemplazar el bitstream de la FPGA.

La verificación del programa sin HALT mostró el estado `RUNNING`; la finalización con HALT y el vaciado del pipeline se comprobaron mediante programas independientes y la validación automatizada completa.

**Estado final: PASO 24 — INTEGRACIÓN Y VALIDACIÓN FÍSICA, COMPLETADO.**

El paso 25 queda destinado a revisión integral de requisitos, documentación de entrega, instrucciones de reproducción y preparación de la defensa oral.
