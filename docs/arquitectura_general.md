# Arquitectura general del sistema

## 1. Descripción

El sistema está compuesto por un procesador RISC-V
segmentado, una infraestructura de comunicación UART,
una Debug Unit y un programa de control en Python.

El procesador ejecuta instrucciones de 32 bits mediante
las etapas IF, ID, EX, MEM y WB.

## 2. Diagrama funcional

```text
                  PC - PYTHON
           +-----------------------+
           | Assembler             |
           | Interfaz TUI          |
           | Protocolo de control  |
           +-----------+-----------+
                       |
                    USB-UART
                       |
        +--------------v--------------+
        |           BASYS 3           |
        |                             |
        | UART RX             UART TX |
        |    |                   ^    |
        |    v                   |    |
        | Controlador de protocolo    |
        |    |                   ^    |
        |    +--> Program Loader |    |
        |    |         |         |    |
        |    |         v         |    |
        |    |        IMEM       |    |
        |    |         |         |    |
        |    |         v         |    |
        |    |    +----------+   |    |
        |    +--->| IF       |   |    |
        |         |    v     |   |    |
        |         | ID       |   |    |
        |         |    v     |   |    |
        |         | EX / ALU |   |    |
        |         |    v     |   |    |
        |         | MEM      |-->|    |
        |         |    v     |   |    |
        |         | WB       |   |    |
        |         +----------+   |    |
        |             |          |    |
        |     Registros / DMEM    |    |
        |             |          |    |
        |             v          |    |
        |          Debug Unit ----+    |
        |                             |
        | Clocking Wizard: 100 -> 50  |
        +-----------------------------+
```

El diagrama es funcional y simplificado. Las señales
reales de control, forwarding y hazards se detallan
en los documentos de las etapas.

## 3. Pipeline

| Etapa | Función |
|---|---|
| IF | Obtención de instrucciones |
| ID | Decodificación y lectura de registros |
| EX | Operaciones ALU y cálculo de saltos |
| MEM | Lectura y escritura de datos |
| WB | Escritura de resultados |

Los registros intermedios conservan el estado necesario
entre etapas.

## 4. Hazards

Se implementaron mecanismos de forwarding para resolver
dependencias de datos cuando el resultado está disponible
en etapas posteriores.

Los casos load-use que lo requieren introducen stalls.

Los saltos tomados producen redirects y flushes para
descartar instrucciones obtenidas por el camino incorrecto.

## 5. Memorias

- Instruction Memory: 256 palabras de 32 bits.
- Data Memory: 256 palabras de 32 bits.
- Implementación mediante recursos de memoria distribuida.

Se mantuvo el comportamiento de lectura requerido por
la microarquitectura validada.

## 6. Carga dinámica y UART

El ensamblador en Python traduce el programa `.S`
a instrucciones de 32 bits.

El software transmite las instrucciones mediante UART.
El Program Loader escribe la memoria de instrucciones.

No se modifica el hardware al cambiar de programa.

La interfaz UART opera a 115200 baudios, 8N1.

## 7. RUN, STEP y HALT

RUN habilita la ejecución continua del procesador.

STEP habilita un solo ciclo del pipeline por comando.

El reloj no se detiene mediante lógica combinacional:
el avance se controla con señales de habilitación.

HALT detiene la aceptación de nuevas instrucciones,
permite vaciar el pipeline y finalmente establece
el estado HALTED.

## 8. Debug Unit

La Debug Unit permite consultar:

- 32 registros generales.
- Registros intermedios del pipeline.
- Estado de ejecución y PC.
- Posiciones utilizadas de memoria de datos.

La información se envía a la PC mediante UART.

## 9. Clock y timing

La Basys 3 proporciona un reloj de 100 MHz.

El Clocking Wizard genera el clock interno de 50 MHz.

La implementación final obtuvo WNS +3.103 ns y
WHS +0.033 ns.

El análisis completo está en `docs/timing_analysis.md`.

## 10. Archivos principales

- `rtl/pipeline_core.sv`
- `rtl/processor_system.sv`
- `rtl/basys3_top.sv`
- `rtl/debug_unit.sv`
- `rtl/program_loader.sv`
- `rtl/system_protocol_controller.sv`
- `software/app.py`
- `software/assembler.py`
- `constraints/basys3.xdc`

Las decisiones de cada componente están desarrolladas
en los documentos específicos de `docs/`.
