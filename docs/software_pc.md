# Software de PC

## 1. Objetivo

El software de PC permite utilizar el procesador sin manipular manualmente código máquina ni bytes UART.

Sus responsabilidades son:

- ensamblar programas escritos en el subconjunto RISC-V implementado;
- cargar y reprogramar Instruction Memory por UART;
- controlar los modos RUN y STEP;
- consultar el estado del procesador;
- solicitar e interpretar snapshots de Debug Unit;
- mostrar registros, pipeline y memoria utilizada mediante una TUI.

## 2. Arquitectura

La implementación se separa en módulos:

```text
programa .S
    |
    v
assembler.py
    |
    v
protocol.py
    |
    v
transport.py
    |
    +--> serial_link.py --> UART real
    |
    +--> transporte simulado para tests

FPGA / simulador
    |
    v
protocol.py
    |
    v
snapshot.py
    |
    v
models.py
    |
    v
app.py
```

Esta separación permite probar assembler, protocolo y snapshots sin depender de una placa física.

## 3. Assembler

`assembler.py` implementa únicamente el subconjunto soportado por el procesador.

Incluye instrucciones R, I, loads, stores, `beq`, `bne`, `lui`, `jal`, `jalr` y la instrucción custom `HALT` (`0x0000000B`).

El assembler utiliza dos pasadas:

1. determina las direcciones de los labels;
2. codifica cada instrucción y calcula los offsets correspondientes.

También valida registros, inmediatos, cantidad máxima de instrucciones y operaciones no soportadas.

El resultado se representa mediante `AssembledProgram`, que conserva tanto las palabras de código máquina como la relación entre PC y línea fuente.

## 4. Transporte y UART

`transport.py` define una interfaz genérica para enviar y recibir bytes.

`serial_link.py` implementa esa interfaz mediante pySerial con configuración:

```text
115200 baud
8 data bits
no parity
1 stop bit
```

El protocolo no depende directamente de pySerial. Esto permite utilizar en el futuro el mismo software con un enlace virtual hacia el RTL simulado.

## 5. Protocolo

`protocol.py` implementa los comandos definidos en hardware:

```text
L  iniciar carga
W  escribir palabra
E  finalizar carga
R  ejecución continua
S  ejecutar un ciclo
G  leer registro
M  leer memoria
Q  consultar estado
D  snapshot completo
```

Las respuestas normales incluyen ACK, NACK y los paquetes `g`, `m`, `q` y `d`.

Los códigos NACK son transformados en excepciones con una descripción legible para la interfaz.

## 6. LOAD

El software recibe un programa ensamblador, lo traduce y genera automáticamente:

```text
L + count
W + address + word
W + address + word
...
E
```

Después espera ACK.

La dirección de las palabras aumenta de cuatro en cuatro porque Instruction Memory se direcciona en bytes y cada instrucción ocupa 32 bits.

## 7. STEP

Para el usuario, un STEP realiza:

```text
S
-> ACK
-> D
-> snapshot
-> actualización de la TUI
```

`S` avanza exactamente un ciclo del procesador. No representa una instrucción completa.

Por eso un STEP puede corresponder a un stall, una burbuja, un flush o un ciclo de draining.

## 8. RUN

RUN realiza:

```text
R
-> ACK
-> Q periódicamente
-> RUNNING / DRAINING / HALTED
-> D al llegar a HALTED
-> snapshot final
```

Durante ejecución continua no se solicitan snapshots, ya que Debug Unit fue diseñada para observar un estado detenido y coherente.

`Q` permite seguir la ejecución sin modificar el estado interno.

## 9. Snapshot

`snapshot.py` interpreta el formato binario versionado generado por Debug Unit.

El paquete incluye:

- estado y flags;
- PC actual de IF;
- 32 registros;
- IF/ID;
- ID/EX;
- EX/MEM;
- MEM/WB;
- posiciones utilizadas de Data Memory.

La parte fija ocupa 246 bytes y cada palabra utilizada de memoria agrega 6 bytes.

El parser valida tags, versión, tamaño, registros y terminación del paquete.

## 10. Visualización

La TUI muestra:

- editor/programa;
- estado de conexión;
- estado del core;
- pipeline;
- 32 registros;
- memoria utilizada;
- log de eventos;
- botones LOAD, STEP, RUN, SNAPSHOT y Q.

Cuando existe un programa cargado, los PCs de las etapas se relacionan con `AssembledProgram` para mostrar también la instrucción fuente correspondiente.

Una etapa inválida se presenta como una burbuja.

## 11. Manejo de errores

La aplicación distingue entre:

- error de assembler;
- error UART o timeout;
- NACK de la FPGA;
- respuesta de protocolo inválida;
- snapshot inválido;
- error de archivo;
- dato inválido.

Estos errores se muestran en el log sin cerrar la aplicación.

## 12. Programa sin HALT

El procesador no implementa un timeout interno de ejecución.

Si no existe un HALT alcanzable, RUN puede continuar indefinidamente. La TUI advierte si el código cargado no contiene la palabra HALT, pero no inventa una detención automática.

## 13. Verificación del software

Las pruebas automáticas cubren:

- assembler y labels;
- comparación contra programas `.hex` ya utilizados en el RTL;
- parser de snapshots;
- protocolo y NACK;
- lectura de registros y memoria;
- transporte serie;
- apertura y cierre de la TUI;
- relación PC-instrucción;
- clasificación de errores;
- integración end-to-end de las capas de software.

El test end-to-end utiliza una FPGA simulada a nivel de protocolo y ejecuta:

```text
assembly
-> assembler
-> LOAD
-> STEP
-> snapshot intermedio
-> RUN
-> Q: RUNNING
-> Q: DRAINING
-> Q: HALTED
-> snapshot final
```

También verifica estado HALTED, pipeline vacío, registros finales y Data Memory utilizada.

Esta prueba valida la integración interna del software. No reemplaza la futura prueba PC ↔ RTL simulado ni la validación con la Basys 3 física.
