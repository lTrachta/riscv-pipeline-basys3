# Simulación end-to-end PC ↔ RTL

Esta carpeta contiene el entorno utilizado para validar el sistema completo antes de utilizar la Basys 3 física.

La prueba conecta el software real de PC con `processor_system` ejecutándose en XSim mediante un puerto serie virtual de Linux.

## Arquitectura

```text
Software de PC
    |
    | pySerial
    v
/tmp/riscv_pipeline_uart
    |
    | PTY Linux
    v
Bridge cocotb
    |
    | UART 8N1 bit a bit
    v
uart_rx.sv
    |
system_protocol_controller.sv
    |
program_loader.sv
    |
pipeline_core.sv
    |
debug_unit.sv
    |
uart_tx.sv
    |
    v
Bridge cocotb
    |
    v
Software de PC
```

De esta forma los comandos enviados por `ProcessorClient` atraviesan los módulos UART reales del RTL. El software no recibe respuestas generadas artificialmente por Python.

## Timing de simulación

`processor_system_virtual_top.sv` instancia el mismo `processor_system` utilizado por el diseño, pero modifica únicamente los parámetros temporales:

```text
Clock de simulación: 1 MHz
UART de simulación: 62500 baud
Oversampling: 16
```

Esto produce exactamente 16 clocks por bit UART y reduce considerablemente el tiempo requerido por XSim.

El RTL destinado a la placa no se modifica. La configuración real continúa siendo:

```text
Clock: 100 MHz
UART: 115200 baud
8N1
```

## Dependencias

Activar el entorno:

```bash
source .venv/bin/activate
```

Instalar:

```bash
python -m pip install -r simulation/requirements.txt
```

Cargar Vivado:

```bash
source /home/luciano/Xilinx/2025.1/Vivado/settings64.sh
```

Comprobar:

```bash
which xvlog
which xvhdl
which xelab
```

## Iniciar la FPGA virtual

En una primera terminal:

```bash
cd ~/Documents/TP-ARQUI/riscv-pipeline-basys3
source .venv/bin/activate
source /home/luciano/Xilinx/2025.1/Vivado/settings64.sh

python -m simulation.run_virtual_uart
```

Cuando XSim esté listo aparecerá:

```text
UART VIRTUAL XSIM ACTIVA
PTY Linux: /dev/pts/...
Puerto estable: /tmp/riscv_pipeline_uart
```

El enlace `/tmp/riscv_pipeline_uart` puede abrirse mediante pySerial como un puerto serie normal.

## Smoke test

Con la simulación activa, desde otra terminal:

```bash
source .venv/bin/activate
python -m simulation.smoke_uart
```

Resultado esperado:

```text
Estado recibido: READY
PASS: Python -> UART RTL -> protocolo -> UART RTL -> Python
```

## Prueba end-to-end automática

Con XSim activo:

```bash
python -m simulation.e2e_rtl
```

Esta prueba utiliza el assembler, `SerialLink`, `ProcessorClient` y el parser de snapshots reales del software.

Valida:

- carga dinámica de programas;
- STEP de exactamente un ciclo;
- snapshots;
- RUN;
- HALT;
- vaciado del pipeline;
- registros;
- memoria utilizada;
- comandos G y M;
- reprogramación dinámica;
- BNE;
- JAL;
- JALR;
- errores NACK 01, 02, 03, 04 y 05;
- programa sin HALT.

El resultado final esperado es:

```text
PASS END-TO-END RTL
PC -> UART -> RTL -> pipeline -> UART -> PC
```

Al terminar esta prueba se crea `simulation/.stop_virtual_uart`, lo que provoca el cierre controlado de la simulación.

## Prueba manual con la TUI

Volver a iniciar:

```bash
python -m simulation.run_virtual_uart
```

En otra terminal:

```bash
python -m software
```

La aplicación debe detectar:

```text
/tmp/riscv_pipeline_uart - UART virtual XSim
```

Se puede utilizar entonces el mismo flujo previsto para la placa:

```text
Conectar
LOAD
STEP
SNAPSHOT
RUN
```

Los registros, latches del pipeline y memoria mostrados por la TUI provienen del RTL ejecutándose en XSim.

## Cierre manual

Para terminar la simulación:

```bash
touch simulation/.stop_virtual_uart
```

También puede utilizarse `Ctrl+C` en la terminal de XSim.

## Archivos

```text
processor_system_virtual_top.sv
    Wrapper temporal de processor_system para acelerar la UART en simulación.

run_virtual_uart.py
    Bridge entre PTY Linux y señales UART del RTL.

smoke_uart.py
    Prueba mínima Q -> READY.

e2e_rtl.py
    Prueba automática completa software-PC ↔ RTL.

requirements.txt
    Dependencias adicionales de simulación.
```
