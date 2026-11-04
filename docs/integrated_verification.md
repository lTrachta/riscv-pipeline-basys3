# Verificación integral del procesador

## 1. Objetivo

Antes de incorporar la comunicación UART y la implementación física sobre FPGA se realizó una verificación integral del procesador mediante simulación.

El objetivo fue comprobar el funcionamiento del procesador completo ejecutando programas formados por múltiples instrucciones, en lugar de verificar únicamente módulos aislados.

La verificación incluyó:

- operaciones aritméticas y lógicas;
- instrucciones con inmediatos;
- accesos a memoria;
- extensión de signo y extensión con ceros;
- branches;
- jumps;
- forwarding;
- stalls por dependencias load-use;
- forwarding hacia stores;
- flushes por hazards de control;
- loops;
- finalización mediante HALT;
- vaciado completo del pipeline.

Además de comprobar los resultados arquitectónicos finales, se inspeccionaron formas de onda para verificar el comportamiento interno del pipeline ciclo a ciclo.

---

## 2. Organización

Los programas utilizados para la verificación se almacenaron en:

```text
programs/integrated_verification/
```

Cada programa posee:

```text
archivo .S
archivo .hex
```

El archivo `.S` contiene una representación legible en assembler.

El archivo `.hex` contiene las palabras máquina de 32 bits utilizadas directamente por la memoria de instrucciones.

Los programas son cargados desde el testbench mediante:

```systemverilog
$readmemh(...)
```

Esto permite separar el programa que se ejecuta del banco de pruebas.

---

## 3. Testbench integral

Se agregó:

```text
tb/pipeline_core_integrated_tb.sv
```

El testbench utiliza una única instancia de `pipeline_core` y ejecuta consecutivamente diferentes programas.

Para cada programa:

1. activa reset;
2. limpia Instruction Memory y Data Memory;
3. carga el archivo `.hex`;
4. libera reset;
5. ejecuta hasta detectar `halted`;
6. utiliza un timeout para evitar simulaciones infinitas;
7. verifica registros;
8. verifica memoria;
9. verifica contadores de hazards y redirects;
10. verifica eventos internos de forwarding.

---

## 4. Verificación automática

La ejecución integral produjo:

```text
Tests run    : 98
Tests passed : 98
Tests failed : 0

PASS: pipeline_core_integrated
```

Todos los programas alcanzaron correctamente:

```text
halted = 1
pipeline_empty = 1
```

y cada uno aceptó exactamente una instrucción HALT válida.

---

## 5. Cobertura del conjunto de instrucciones

Los programas de verificación cubren las 32 instrucciones soportadas por el procesador.

### Operaciones R-Type

```text
add
sub
sll
srl
sra
and
or
xor
slt
sltu
```

### Operaciones inmediatas

```text
addi
andi
ori
xori
slti
sltiu
slli
srli
srai
```

### Loads

```text
lb
lh
lw
lbu
lhu
```

### Stores

```text
sb
sh
sw
```

### Control

```text
beq
bne
jal
jalr
```

### U-Type

```text
lui
```

También se verificó la instrucción HALT definida específicamente para el procesador.

---

## 6. Programa ALU e inmediatos

Archivo:

```text
programs/integrated_verification/alu_immediates.S
```

Este programa verifica operaciones R-Type, operaciones inmediatas y LUI.

Entre los resultados comprobados se encuentran:

```text
ADD  = 13
SUB  = 7
SLL  = 24
SRL  = 3
SRA  = 0xFFFFFFFE

AND  = 2
OR   = 11
XOR  = 9

SLT  = 1
SLTU = 0

SLLI = 48
SRLI = 12
SRAI = 0xFFFFFFFC

LUI  = 0x12345000
```

También se comprobó la diferencia entre operaciones signed y unsigned y entre shifts lógicos y aritméticos.

Resultado:

```text
stalls    = 0
redirects = 0
```

Durante la ejecución se observaron tanto forwarding desde EX/MEM como forwarding desde MEM/WB.

---

## 7. Programa de memoria

Archivo:

```text
programs/integrated_verification/memory.S
```

Se verificaron stores de byte, halfword y word:

```text
sb
sh
sw
```

y los cinco tipos de load:

```text
lb
lh
lw
lbu
lhu
```

Una de las pruebas principales consistió en almacenar valores con el bit de signo activo y comprobar la diferencia entre:

```text
lb  -> extensión de signo
lbu -> extensión con ceros
```

Se obtuvo:

```text
lb  0xFF -> 0xFFFFFFFF
lbu 0xFF -> 0x000000FF
```

De la misma manera:

```text
lh  0xFFFF -> 0xFFFFFFFF
lhu 0xFFFF -> 0x0000FFFF
```

También se verificó:

```text
sw/lw -> 0x11223344
```

Resultado:

```text
stalls    = 0
redirects = 0
```

---

## 8. Programa de flujo de control

Archivo:

```text
programs/integrated_verification/control_flow.S
```

Se verificaron:

```text
BEQ tomado
BEQ no tomado

BNE tomado
BNE no tomado

JAL
JALR
```

También se comprobaron:

- cálculo correcto del target;
- escritura de PC + 4 como link;
- eliminación de instrucciones wrong-path;
- limpieza del bit menos significativo del target de JALR.

Resultados principales:

```text
JAL link  = 60
JALR link = 76

stalls    = 0
redirects = 4
```

Los registros asociados a instrucciones del camino incorrecto permanecieron en cero.

---

## 9. Programa de hazards combinados

Archivo:

```text
programs/integrated_verification/hazards.S
```

Este programa fue diseñado específicamente para producir múltiples dependencias dentro de una misma ejecución.

Se verificaron:

```text
ALU -> ALU

load -> ALU

load -> store-data

load -> store-base

ALU -> branch

load -> branch
```

Resultado:

```text
stalls    = 3
redirects = 2
```

Los tres stalls corresponden a situaciones donde el valor de un load era requerido en EX:

```text
load -> ALU
load -> store base
load -> branch
```

En cambio:

```text
load -> store data
```

no generó stall.

El dato fue resuelto mediante forwarding desde WB hacia MEM.

También se observaron:

```text
EX/MEM forwarding
MEM/WB forwarding
WB -> MEM store-data forwarding
```

---

## 10. Programa de integración completa

Archivo:

```text
programs/integrated_verification/integration.S
```

El programa utiliza memoria, ALU, dependencias y control de flujo para ejecutar un pequeño algoritmo.

Primero almacena:

```text
1
2
3
4
```

en memoria.

Luego recorre esos cuatro valores mediante un loop y calcula:

```text
1 + 2 + 3 + 4 = 10
```

La suma se almacena nuevamente en memoria y posteriormente vuelve a cargarse.

Resultados finales:

```text
x3 = 10
x4 = 0
x5 = 216
x6 = 4
x7 = 10
```

Memoria:

```text
DMEM[200] = 1
DMEM[204] = 2
DMEM[208] = 3
DMEM[212] = 4
DMEM[216] = 10
```

Durante la ejecución se obtuvieron:

```text
stalls    = 4
redirects = 3
```

El loop se ejecuta cuatro veces.

El branch BNE se toma tres veces:

```text
count = 3 -> tomado
count = 2 -> tomado
count = 1 -> tomado
```

y deja de tomarse cuando:

```text
count = 0
```

---

## 11. Seguimiento de instrucciones mediante PC y valid

Para estudiar una instrucción dentro del pipeline se utilizaron principalmente:

```text
if_pc_current

if_id_pc
if_id_valid

id_ex_pc
id_ex_valid

ex_mem_pc
ex_mem_valid

mem_wb_pc
mem_wb_valid
```

El PC permite identificar una instrucción mientras se desplaza entre etapas.

Los bits `valid` permiten distinguir una instrucción real de una burbuja.

Por ejemplo:

```text
id_ex_pc = 20
id_ex_valid = 0
```

no significa que la instrucción de PC 20 esté ejecutándose.

El contenido almacenado debe ignorarse porque el registro de pipeline está marcado como inválido.

---

## 12. Evidencia de forwarding

En las formas de onda se inspeccionaron:

```text
forward_a
forward_b
```

La codificación utilizada es:

```text
00 -> dato proveniente de ID/EX
01 -> forwarding desde MEM/WB
10 -> forwarding desde EX/MEM
```

Se observaron casos reales donde una instrucción consumidora recibió directamente el resultado producido por una instrucción anterior sin esperar su escritura en el Register File.

Esto permitió verificar forwarding tanto desde:

```text
EX/MEM
```

como desde:

```text
MEM/WB
```

---

## 13. Evidencia de load-use stall

Se verificaron dependencias del tipo:

```text
lw
instrucción consumidora inmediata
```

En estos casos se observó:

```text
load_use_stall = 1
```

y simultáneamente:

```text
PC      -> HOLD
IF/ID   -> HOLD
ID/EX   -> BUBBLE
EX/MEM  -> load continúa avanzando
```

En el ciclo posterior la instrucción consumidora pudo continuar utilizando forwarding desde MEM/WB.

---

## 14. Evidencia de forwarding hacia stores

Para el caso:

```text
lw
sw utilizando el valor cargado como store-data
```

se verificó que:

```text
load_use_stall = 0
```

y que se activa:

```text
store_data_forwarded = 1
```

Esto demuestra que el dato del store no necesita estar disponible durante EX, sino recién cuando el store llega a MEM.

---

## 15. Evidencia de hazards de control

Para branches tomados se observaron:

```text
redirect_valid = 1
redirect_target = target calculado
flush_if_id = 1
flush_id_ex = 1
```

El PC fue redirigido hacia el target mientras las instrucciones jóvenes de IF e ID fueron convertidas en burbujas.

El branch que produjo el redirect continuó avanzando normalmente porque era una instrucción válida y más vieja que las instrucciones descartadas.

---

## 16. Verificación del loop

En las formas de onda del programa integral se observaron:

```text
4 load-use stalls
3 redirects
```

Esto coincide con las cuatro iteraciones del loop y los tres branches tomados.

La última evaluación de BNE no produce redirect porque el contador ya es cero.

---

## 17. Evidencia de HALT y drain

Al final del programa se verificó el comportamiento de:

```text
running
draining
halted
pipeline_empty
```

La secuencia observada fue:

```text
RUNNING
   |
   | HALT aceptado
   v
DRAINING
   |
   | pipeline vacío
   v
HALTED
```

Cuando HALT fue aceptado:

```text
running  -> 0
draining -> 1
```

A partir de ese momento no ingresaron nuevas instrucciones.

Las instrucciones anteriores continuaron avanzando.

Los bits de validez fueron desapareciendo progresivamente:

```text
if_id_valid
id_ex_valid
ex_mem_valid
mem_wb_valid
```

hasta alcanzar:

```text
0
0
0
0
```

Entonces:

```text
pipeline_empty = 1
```

y en el siguiente flanco de reloj el controlador pasó de DRAINING a HALTED.

Estado final:

```text
running        = 0
draining       = 0
halted         = 1
pipeline_empty = 1
```

Esto demuestra que la ejecución finaliza con el pipeline completamente vacío.

---

## 18. Regresiones

Después de incorporar la verificación integral se volvieron a ejecutar los testbenches desarrollados previamente.

### Control hazards

```text
Tests run    : 31
Tests passed : 31
Tests failed : 0
Redirects    : 8
Stalls       : 2
```

### Forwarding

```text
Tests run    : 10
Tests passed : 10
Tests failed : 0
```

### Load-use

```text
Tests run    : 22
Tests passed : 22
Tests failed : 0
Stalls       : 4
```

### Store forwarding

```text
Tests run    : 12
Tests passed : 12
Tests failed : 0
Stalls       : 1
```

### HALT y drain

```text
Tests run    : 38
Tests passed : 38
Tests failed : 0
```

También finalizaron correctamente:

```text
PASS: pipeline_core_memory
PASS: pipeline_core
```

Por lo tanto, la incorporación del nuevo banco de programas no detectó regresiones en las funcionalidades desarrolladas previamente.

---

## 19. Resultado

La verificación integral permitió comprobar el procesador en dos niveles.

### Corrección arquitectónica

Se verificaron los valores finales de:

```text
Register File
Data Memory
PC/link registers
estado de finalización
```

### Corrección microarquitectónica

Mediante formas de onda se verificaron:

```text
movimiento IF -> ID -> EX -> MEM -> WB
valid bits
forwarding
stalls
bubbles
redirects
flushes
stores
write-back
HALT
drain
```

Los cinco programas de prueba finalizaron correctamente y el banco integral obtuvo:

```text
98 / 98 verificaciones correctas
```

Con estas pruebas se considera verificado el funcionamiento del core antes de incorporar la infraestructura de carga de programas y comunicación UART.
