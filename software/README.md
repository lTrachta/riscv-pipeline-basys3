# Software de PC

Aplicación Python para ensamblar, cargar, ejecutar y depurar el procesador RISC-V segmentado mediante el protocolo UART del proyecto.

## Instalación

Desde la raíz del repositorio:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r software/requirements.txt
```

## Ejecutar los tests

```bash
python -m unittest discover -s software/tests -v
```

## Ejecutar la TUI

```bash
python -m software
```

La comunicación serie utiliza **115200 8N1**.

## Módulos

- `assembler.py`: convierte ensamblador del subconjunto implementado a palabras de 32 bits, resuelve labels y valida operandos.
- `models.py`: estructuras Python para programa ensamblado, estado, registros, pipeline y memoria.
- `snapshot.py`: interpreta el paquete binario generado por Debug Unit.
- `transport.py`: interfaz genérica para transportar bytes.
- `serial_link.py`: implementación de `transport.py` mediante pySerial.
- `protocol.py`: comandos `L/W/E/R/S/G/M/Q/D`, respuestas y errores.
- `app.py`: TUI para conectar, cargar programas, ejecutar RUN/STEP y visualizar el estado.
- `tests/`: pruebas unitarias e integración del software.

## Flujo de LOAD

```text
programa .S
    -> assembler
    -> palabras de 32 bits
    -> L + W... + E
    -> UART
    -> ACK
```

## Flujo de STEP

El botón STEP realiza automáticamente:

```text
S -> ACK -> D -> snapshot -> actualizar pantalla
```

STEP representa **un ciclo del procesador**, no una instrucción completa.

## Flujo de RUN

El botón RUN realiza:

```text
R -> ACK -> Q...
              |
              +-> RUNNING
              +-> DRAINING
              +-> HALTED
                         -> D
                         -> snapshot final
```

Durante RUN no se solicitan snapshots completos. Se utiliza `Q` hasta que el core alcanza `HALTED`, y recién entonces se solicita `D`.

## Snapshot

La aplicación muestra:

- 32 registros;
- PC de IF;
- IF/ID;
- ID/EX;
- EX/MEM;
- MEM/WB;
- Data Memory utilizada;
- estado general del procesador.

Los PCs del snapshot se relacionan con el programa cargado para mostrar qué instrucción fuente ocupa cada etapa.

## Programa sin HALT

Si el programa cargado no contiene `HALT`, la TUI muestra una advertencia. El procesador puede permanecer en RUN indefinidamente porque el core no posee un timeout automático de ejecución.

## Errores

La interfaz diferencia errores de:

- assembler;
- UART/timeout;
- NACK de la FPGA;
- protocolo;
- snapshot;
- archivo;
- datos inválidos.

Un error se informa en el log de la aplicación y no debe cerrar la TUI.

## Validación sin FPGA

`test_end_to_end.py` utiliza un transporte que simula la FPGA a nivel de protocolo y verifica el recorrido:

```text
assembly
-> assembler
-> LOAD
-> STEP
-> snapshot
-> RUN
-> Q hasta HALTED
-> snapshot final
```

Esta prueba valida la integración entre las capas de software. La conexión del software real con el RTL simulado y luego con la Basys 3 se valida en las etapas posteriores del proyecto.
