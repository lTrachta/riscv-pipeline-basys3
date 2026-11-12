# Integración física con Basys 3

## Objetivo

Esta etapa prepara el sistema completo para su ejecución física sobre una placa Basys 3.

Hasta esta instancia el procesador, el protocolo UART, el mecanismo de carga dinámica, el Debug Unit y el software de PC habían sido validados mediante simulación.

La integración física incorpora:

- top específico de Basys 3;
- clock físico;
- generación del clock interno;
- reset de encendido;
- reset manual;
- USB-UART;
- constraints físicas;
- LEDs de diagnóstico;
- síntesis;
- implementación;
- análisis de timing;
- generación de bitstream.

La prueba final con hardware queda pendiente hasta disponer físicamente de la placa.

---

## FPGA objetivo

El dispositivo utilizado por Basys 3 es:

```text
XC7A35T-1CPG236C
```

El proyecto Vivado se creó para:

```text
xc7a35tcpg236-1
```

---

## Interfaces físicas utilizadas

Las interfaces externas del diseño son:

```text
CLK100MHZ
btnC
RsRx
RsTx
led[15:0]
```

La asignación física utilizada es:

```text
W5  -> CLK100MHZ
U18 -> btnC

B18 -> RsRx
A18 -> RsTx
```

La comunicación UART utiliza:

```text
115200 baud
8 bits
sin paridad
1 stop bit
```

---

## Clock físico

La Basys 3 proporciona un oscilador físico de:

```text
100 MHz
```

correspondiente a:

```text
Periodo = 10 ns
```

Inicialmente se intentó ejecutar directamente todo `processor_system` con este clock.

La primera implementación física mostró:

```text
WNS = -3.558 ns
TNS = -1036.007 ns
```

con 601 endpoints violando setup timing.

El peor camino encontrado presentaba:

```text
Requirement      = 10.000 ns
Data Path Delay  = 13.519 ns
Logic Levels     = 25
```

El camino crítico conectaba lógica del pipeline desde EX/MEM hacia la actualización del PC.

Por lo tanto, el procesador no podía considerarse correctamente implementado a 100 MHz.

---

## Clocking Wizard

Se utilizó el IP Core:

```text
Clocking Wizard
```

para transformar:

```text
100 MHz físicos
        |
        v
Clocking Wizard
        |
        v
50 MHz internos
```

El clock externo continúa siendo 100 MHz.

El clock utilizado por:

```text
processor_system
pipeline
UART
Debug Unit
loader
```

es de:

```text
50 MHz
```

o:

```text
Periodo = 20 ns
```

El `processor_system` fue configurado como:

```text
CLK_FREQ     = 50_000_000
BAUD_RATE    = 115_200
OVERSAMPLING = 16
```

El archivo fuente del IP que debe conservarse en el repositorio es:

```text
ip/clk_wiz_0/clk_wiz_0.xci
```

Los output products generados por Vivado no forman parte del código fuente del proyecto.

---

## Resultado final de timing

Luego de generar el clock interno de 50 MHz, volver a sintetizar y ejecutar placement y routing, el análisis final obtuvo:

```text
WNS = +3.103 ns
TNS = 0.000 ns

WHS = +0.033 ns
THS = 0.000 ns
```

Vivado informó:

```text
All user specified timing constraints are met.
```

Por lo tanto se cumplen tanto setup timing como hold timing.

---

## Clocks finales

Vivado reconoce:

```text
CLK100MHZ
Periodo: 10 ns
Frecuencia: 100 MHz
```

y el clock generado:

```text
clk_out1_clk_wiz_0
Periodo: 20 ns
Frecuencia: 50 MHz
```

No existen definiciones de clock primario duplicadas.

---

## Reset

El reset físico combina:

```text
Clocking Wizard locked
+
btnC
+
reset inicial temporizado
```

El procesador permanece en reset mientras el Clocking Wizard no indique que su clock de salida es estable.

Después del lock se mantiene un reset adicional de aproximadamente:

```text
10.49 ms
```

antes de liberar el sistema.

El botón central:

```text
btnC
```

permite realizar reset manual del sistema.

La afirmación del reset puede ocurrir de forma asíncrona, pero su liberación se sincroniza con el clock interno.

---

## UART

La comunicación física utiliza el USB-UART incorporado en la Basys 3.

El camino esperado es:

```text
Software Python
      |
      v
pySerial
      |
      v
USB
      |
      v
FTDI de Basys 3
      |
      v
RsRx / RsTx
      |
      v
uart_rx / uart_tx
      |
      v
system_protocol_controller
```

El JTAG y el UART utilizan funciones diferentes del circuito FTDI.

JTAG se utilizará para programar la FPGA.

UART se utilizará para la comunicación entre la aplicación y el procesador.

---

## LEDs de diagnóstico

El top de placa utiliza LEDs para permitir diagnóstico incluso si el software de PC o la UART no responden.

La asignación lógica es:

```text
LED0  program_loaded
LED1  running
LED2  draining
LED3  halted
LED4  pipeline_empty
LED5  UART frame error

LED8:6 status_code

LED9  reset activo

LED15 heartbeat
```

El heartbeat permite verificar visualmente:

```text
bitstream cargado
+
clock funcionando
+
sistema fuera de reset
```

---

## Memorias

El procesador utiliza:

```text
Instruction Memory
256 x 32 bits

Data Memory
256 x 32 bits
```

Se investigaron las alternativas de memoria disponibles mediante Vivado y el IP Catalog.

En particular se evaluó:

```text
Block Memory Generator
```

Sin embargo las memorias existentes utilizan lectura asíncrona.

Modificar directamente el diseño para utilizar Block RAM introduciría lectura síncrona y modificaría la temporización funcional del pipeline ya validado.

La síntesis de Vivado implementó ambas memorias automáticamente como:

```text
Distributed RAM
```

La IMEM utiliza primitivas equivalentes a:

```text
RAM64M
```

y la DMEM:

```text
RAM128X1D
```

Por lo tanto se conservó la arquitectura existente.

---

## Constraints físicas

El archivo utilizado es:

```text
constraints/basys3.xdc
```

Contiene las restricciones de:

```text
clock
reset
UART
LEDs
IOSTANDARD LVCMOS33
```

Los reportes post-implementation verificaron:

```text
CLK100MHZ -> W5
btnC      -> U18
RsRx      -> B18
RsTx      -> A18
```

El DRC final no presentó errores.

---

## Síntesis e implementación

El flujo utilizado fue:

```text
RTL
 ↓
Synthesis
 ↓
Optimization
 ↓
Placement
 ↓
Physical Optimization
 ↓
Routing
 ↓
Timing Analysis
 ↓
DRC
 ↓
Bitstream
```

El routing final terminó sin:

```text
failed nets
unrouted nets
partially routed nets
node overlaps
```

---

## Bitstream

El bitstream final preparado para la prueba física es:

```text
vivado/bitstreams/riscv_pipeline_basys3.bit
```

Tamaño aproximado:

```text
2.1 MB
```

SHA-256 de la versión preparada:

```text
47b0df0cfe97ea0f70601cd2355abf5c8492e732450e1210a61348fcc9203d4a
```

El bitstream es un artefacto generado y no se almacena en Git.

Puede regenerarse a partir del RTL, constraints y configuración del Clocking Wizard.

---

## Preparación del entorno físico

El usuario Linux pertenece al grupo:

```text
dialout
```

por lo que dispone de permisos para utilizar dispositivos serie.

Los drivers de cable de Vivado están disponibles localmente.

También se preparó:

```text
software/hardware_validation.py
```

para ejecutar una validación automática contra la placa física.

---

## Programas de prueba

Se prepararon:

```text
programs/hardware_validation/smoke.S
programs/hardware_validation/memory.S
programs/hardware_validation/control_flow.S
programs/hardware_validation/no_halt.S
```

Estos programas permiten comprobar progresivamente:

```text
ALU
registros
memoria
HALT
pipeline vacío
BNE
JAL
JALR
flush
reprogramación
comportamiento sin HALT
```

---

## Procedimiento previsto para la placa física

Al disponer de una Basys 3 se realizará:

```text
1. Conectar Basys 3 mediante USB.

2. Detectar JTAG y USB-UART.

3. Abrir Hardware Manager.

4. Programar:
   riscv_pipeline_basys3.bit

5. Verificar LED15 heartbeat.

6. Detectar el puerto /dev/ttyUSB*.

7. Ejecutar:
   hardware_validation.py --smoke-only

8. Esperar:
   READY

9. Ejecutar validación automática completa.

10. Ejecutar la TUI.

11. LOAD.

12. STEP.

13. SNAPSHOT.

14. RUN.

15. Verificar HALTED.

16. Verificar pipeline vacío.

17. Comprobar memoria.

18. Comprobar control de flujo.

19. Reprogramar otro programa sin regenerar bitstream.

20. Probar programa sin HALT.

21. Guardar evidencias de la ejecución física.
```

---

## Estado previo a la prueba física

Antes de disponer de la placa quedaron completados:

```text
Top Basys 3                OK
Constraints                OK
Clock físico 100 MHz       OK
Clock Wizard 50 MHz        OK
Reset                      OK
UART                       OK
LEDs diagnóstico           OK
Memorias                   OK
Síntesis                   OK
Placement                  OK
Routing                    OK
DRC                        OK
Timing                     OK
Bitstream                  OK
Software validación        OK
Programas de prueba        OK
```

La única validación pendiente es la interacción eléctrica con una Basys 3 física.

Esta validación incluye específicamente:

```text
JTAG físico
USB-UART físico
clock físico real
programación FPGA
PC <-> Basys 3
```
