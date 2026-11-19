# Guía de entrega — Trabajo Práctico N.º 3

## Proyecto

Procesador RISC-V de cinco etapas implementado en
SystemVerilog sobre una FPGA Basys 3.

## Repositorio

https://github.com/lTrachta/riscv-pipeline-basys3

## Documentación principal

| Documento | Contenido |
|---|---|
| `README.md` | Presentación general e instrucciones |
| `docs/arquitectura_general.md` | Arquitectura y decisiones principales |
| `docs/auditoria_final.md` | Auditoría y comprobaciones |
| `docs/integrated_verification.md` | Pruebas del procesador |
| `docs/basys3_integration.md` | Implementación y validación física |
| `docs/timing_analysis.md` | Timing, skew y camino crítico |
| `software/README.md` | Uso del software y TUI |
| `simulation/README.md` | Simulación end-to-end |

## Evidencias físicas

Las capturas de la TUI y las fotografías originales
de la placa se encuentran en:

`docs/evidencias_basys3/`

Las imágenes seleccionadas para el informe están en:

`docs/evidencias_informe_final/`

Incluyen:

- Ejecución paso a paso.
- Prueba aritmética y HALT.
- Lectura y escritura de memoria.
- Prueba de control de flujo.
- Fotografía de la placa Basys 3.
- Resumen de timing de Vivado.

## Pruebas y resultados

La verificación integral del pipeline registró
98 comprobaciones correctas.

Las pruebas físicas registradas cubren comunicación UART,
ALU, memoria, control de flujo y finalización mediante HALT.

Los resultados finales de timing corresponden a una
frecuencia interna implementada de 50 MHz.

## Reproducción

Para utilizar el sistema se requiere:

1. Instalar las dependencias de Python.
2. Sintetizar e implementar el diseño en Vivado.
3. Generar y programar el bitstream en Basys 3.
4. Conectar la placa mediante USB.
5. Ejecutar `python -m software`.
6. Cargar un programa ensamblador.
7. Controlarlo con RUN o STEP.

El bitstream y los archivos temporales de Vivado
no forman parte del repositorio versionado.

## Informe académico

El informe de presentación al profesor se preparó
en Google Docs e incluye las fotografías, las pruebas
de la TUI y el análisis temporal.

La documentación técnica del repositorio complementa
ese informe sin repetir todos sus contenidos.
