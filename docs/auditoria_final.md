# Auditoría final del Trabajo Práctico N.º 3

Fecha: 2026-11-19

## Alcance

Auditoría de integridad del repositorio y revisión de evidencias
del procesador RISC-V segmentado implementado sobre Basys 3.

El control de existencia de un archivo no demuestra por sí solo
que su implementación sea correcta. La validación funcional se
respalda mediante las pruebas conservadas en el proyecto.

## Requisitos contrastados con la consigna

La consigna solicita:

- Procesador RISC-V con etapas IF, ID, EX, MEM y WB.
- Instrucciones R, I, S, B, J y U especificadas.
- Control de hazards de datos y control.
- Carga y reprogramación por UART sin resintetizar.
- Programas escritos en ensamblador y traducidos a código máquina.
- Instrucción HALT o mecanismo de parada.
- Modos RUN y STEP, avanzando un ciclo por comando STEP.
- Clock sin intervención mediante lógica de control.
- Debug Unit para 32 registros, latches y memoria utilizada.
- Interfaz de PC para visualizar los datos.
- Pipeline vacío al terminar la ejecución.
- Análisis del camino crítico, skew y frecuencia.
- Documentación de las decisiones de diseño.

## Comprobación de archivos

| Componente | Estado | Archivo |
|---|---|---|
| Pipeline IF | OK | `rtl/if_stage.sv` |
| Pipeline ID | OK | `rtl/id_stage.sv` |
| Pipeline EX | OK | `rtl/ex_stage.sv` |
| Pipeline MEM | OK | `rtl/mem_stage.sv` |
| Pipeline WB | OK | `rtl/wb_stage.sv` |
| Integración del procesador | OK | `rtl/pipeline_core.sv` |
| Registros generales | OK | `rtl/register_file.sv` |
| ALU | OK | `rtl/alu.sv` |
| Memoria de instrucciones | OK | `rtl/instruction_memory.sv` |
| Memoria de datos | OK | `rtl/data_memory.sv` |
| Forwarding | OK | `rtl/forwarding_unit.sv` |
| Detección de hazards | OK | `rtl/hazard_detection_unit.sv` |
| Control de ejecución | OK | `rtl/execution_control_unit.sv` |
| Recepción UART | OK | `rtl/uart_rx.sv` |
| Transmisión UART | OK | `rtl/uart_tx.sv` |
| Controlador de protocolo | OK | `rtl/system_protocol_controller.sv` |
| Carga de programas | OK | `rtl/program_loader.sv` |
| Debug Unit | OK | `rtl/debug_unit.sv` |
| Integración Basys 3 | OK | `rtl/basys3_top.sv` |
| Constraints | OK | `constraints/basys3.xdc` |
| Clocking Wizard | OK | `ip/clk_wiz_0/clk_wiz_0.xci` |
| Assembler | OK | `software/assembler.py` |
| TUI | OK | `software/app.py` |
| Comunicación serie | OK | `software/serial_link.py` |
| Pruebas de software | OK | `software/tests/test_end_to_end.py` |
| Testbench integral | OK | `tb/pipeline_core_integrated_tb.sv` |
| Pruebas integrales documentadas | OK | `docs/integrated_verification.md` |
| Pruebas físicas documentadas | OK | `docs/basys3_integration.md` |
| Resultados de pruebas físicas | OK | `docs/evidencias_basys3/logs/hardware_validation.txt` |
| Timing | OK | `docs/timing_analysis.md` |
| Reporte de setup | OK | `docs/evidencias_timing/reportes/critical_paths_setup.txt` |
| Reporte de hold | OK | `docs/evidencias_timing/reportes/critical_paths_hold.txt` |
| Reporte de restricciones | OK | `docs/evidencias_timing/reportes/check_timing.txt` |

## Conjunto de instrucciones

Instrucciones solicitadas: 32

Instrucciones ausentes de la documentación:
Ninguna

Nota: se verifican las instrucciones documentadas; las
pruebas funcionales se describen en integrated_verification.md.

## Pruebas

- Tests Python: PASS
- Evidencia de validación física anterior: PRESENTE
- Reporte de timing final: PRESENTE
- Capturas del informe: 6/6

Salida completa de los tests Python:
`docs/auditoria_tests.log`

## Observaciones técnicas

- La implementación final opera a 50 MHz.
- Los reportes finales indican WNS +3.103 ns y WHS +0.033 ns.
- Se documentó un camino de setup que termina en un pin de reset.
- El chequeo de restricciones identifica salidas sin output delay.
- No se determinó experimentalmente la frecuencia máxima.
- Las 98 verificaciones integrales y las pruebas físicas
  corresponden a resultados registrados previamente; este
  script no vuelve a ejecutar Vivado ni programa la placa.

## Resultado

CONTROLES AUTOMÁTICOS SATISFACTORIOS

Esta auditoría automatizada no reemplaza una inspección
exhaustiva del RTL ni garantiza cobertura funcional total.
