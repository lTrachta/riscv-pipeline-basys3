# Procesador RISC-V segmentado en FPGA Basys 3

**Arquitectura de Computadoras — Trabajo Práctico N.º 3**

Implementación en SystemVerilog de un procesador RISC-V de
32 bits con pipeline de cinco etapas, comunicación UART,
Debug Unit e interfaz de control desarrollada en Python.

**Autor:** Luciano Trachta

## Características principales

- Pipeline de cinco etapas: IF, ID, EX, MEM y WB.
- Subconjunto de 32 instrucciones RISC-V y HALT personalizado.
- Resolución de hazards mediante forwarding, stalls y flushes.
- Memoria de instrucciones y datos de 256 palabras de 32 bits.
- Carga dinámica de programas ensamblador mediante UART.
- Comunicación a 115200 baudios, formato 8N1.
- Ejecución continua (RUN) y paso a paso (STEP).
- Control del avance mediante enables, sin intervenir el clock.
- Debug Unit para consultar registros, pipeline y memoria.
- TUI en Python para controlar el procesador desde la PC.

## Plataforma utilizada

| Componente | Descripción |
|---|---|
| FPGA | Digilent Basys 3 — Artix-7 XC7A35T |
| Lenguaje de hardware | SystemVerilog |
| Software de diseño | Vivado 2025.1 |
| Software de PC | Python 3 |
| Comunicación | USB-UART |
| Clock externo | 100 MHz |
| Clock interno | 50 MHz |

## Arquitectura

```text
                   COMPUTADORA
              Ensamblador + TUI
                        |
                    USB-UART
                        |
                        v
                 FPGA BASYS 3
                        |
                 UART RX / TX
                        |
             Controlador de protocolo
                  /           \
                 v             v
          Program Loader    Debug Unit
                 |             ^
                 v             |
           Instruction        |
             Memory           |
                 |             |
                 v             |
          +--------------------------+
          |    PROCESADOR RISC-V     |
          |                          |
          |  IF -> ID -> EX -> MEM    |
          |                  -> WB    |
          |                          |
          |  Forwarding / Hazards    |
          |  Register File / ALU     |
          |  Data Memory             |
          +--------------------------+
                        |
               Resultados y estado
                        |
                    Debug Unit
                        |
                    UART TX
                        |
                        v
                       TUI
```

El esquema completo y sus explicaciones están en
[Arquitectura general](docs/arquitectura_general.md).

## Conjunto de instrucciones

Se implementaron instrucciones de los formatos R, I, S, B,
J y U, además de una instrucción HALT propia.

El detalle se encuentra en
[Conjunto de instrucciones](docs/instruction_set.md).

## Ejecutar la interfaz de PC

Desde la raíz del repositorio:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r software/requirements.txt
python -m software
```

Con la Basys 3 programada y conectada:

1. Refrescar la lista de puertos serie.
2. Seleccionar el dispositivo Digilent correspondiente.
3. Presionar Conectar.
4. Abrir un archivo ensamblador `.S`.
5. Presionar LOAD para cargarlo.
6. Utilizar STEP o RUN.
7. Consultar registros, pipeline y memoria desde la TUI.

El puerto puede variar entre conexiones. En las pruebas
registradas se utilizó `/dev/ttyUSB1`.

Los programas de ejemplo están en:

`programs/hardware_validation/`

## Validación automática en Basys 3

La placa debe estar programada y el puerto serie disponible.

```bash
source .venv/bin/activate
python -m software.hardware_validation /dev/ttyUSB1
```

Reemplazar `/dev/ttyUSB1` por el puerto detectado.

El script comprueba la comunicación UART y ejecuta programas
de ALU, memoria y control de flujo.

La evidencia de la validación realizada se conserva en:

[Validación física](docs/basys3_integration.md)

## Tests de software

```bash
source .venv/bin/activate
python -m unittest discover -s software/tests -v
```

La documentación de la simulación completa PC-UART-RTL
se encuentra en [simulation/README.md](simulation/README.md).

## Implementación física y timing

La implementación final utiliza un reloj interno de 50 MHz,
generado mediante Clocking Wizard.

Resultados registrados por Vivado:

| Métrica | Resultado |
|---|---:|
| WNS | +3.103 ns |
| TNS | 0 ns |
| WHS | +0.033 ns |
| THS | 0 ns |

Los caminos internos analizados cumplen las restricciones
temporales especificadas.

Estos resultados no constituyen una medición de la
frecuencia máxima posible.

El análisis completo está en
[Timing y camino crítico](docs/timing_analysis.md).

## Resultados de verificación

Se conservaron evidencias de:

- Verificación integral del pipeline: 98 comprobaciones correctas.
- Pruebas físicas de ALU, memoria y control de flujo.
- Ejecución RUN y STEP desde la TUI.
- Finalización mediante HALT y vaciado del pipeline.
- Reprogramación mediante UART sin generar otro bitstream.
- Cumplimiento de timing a 50 MHz.

Las verificaciones y evidencias corresponden a los casos
de prueba documentados y no implican cobertura exhaustiva
de todas las condiciones posibles.

## Organización del repositorio

| Directorio | Contenido |
|---|---|
| `rtl/` | Módulos SystemVerilog |
| `tb/` | Testbenches |
| `constraints/` | Restricciones de la Basys 3 |
| `ip/` | Configuración del Clocking Wizard |
| `software/` | Assembler, protocolo, TUI y tests |
| `simulation/` | Simulación end-to-end con UART virtual |
| `programs/` | Programas ensamblador de prueba |
| `docs/` | Documentación y evidencias |
| `vivado/` | Directorio de trabajo de Vivado |

## Documentación y entrega

- [Guía de entrega](docs/guia_entrega.md)
- [Auditoría final](docs/auditoria_final.md)
- [Arquitectura general](docs/arquitectura_general.md)
- [Verificación integral](docs/integrated_verification.md)
- [Integración física](docs/basys3_integration.md)
- [Análisis de timing](docs/timing_analysis.md)

El bitstream generado localmente no se versiona en Git.
Para reproducir la implementación física se requiere
generarlo en Vivado a partir del proyecto RTL,
las restricciones y la configuración del IP.

## Referencias

- Enunciado del Trabajo Práctico N.º 3.
- Patterson y Hennessy, *Computer Organization and Design:
  The Hardware/Software Interface — RISC-V Edition*.
- Documentación de AMD Vivado Design Suite.
