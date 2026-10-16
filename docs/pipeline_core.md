# Integración del Pipeline — IF / ID / EX / MEM / WB

## 1. Objetivo

El objetivo de este paso es integrar por primera vez las cinco etapas ya
implementadas y verificadas individualmente:

- IF — Instruction Fetch
- ID — Instruction Decode
- EX — Execute
- MEM — Memory Access
- WB — Write Back

Hasta este punto cada etapa había sido desarrollada y validada de forma
independiente.

La integración realizada en este paso permite que varias instrucciones se
encuentren simultáneamente en distintas etapas del procesador.

La estructura obtenida es:

IF -> IF/ID -> ID -> ID/EX -> EX -> EX/MEM -> MEM -> MEM/WB -> WB

con realimentación:

WB -> Register File de ID

Esta es la primera versión funcional del núcleo segmentado completo.

---

# 2. Concepto de segmentación

En un procesador segmentado una instrucción no necesita esperar a que la
instrucción anterior complete las cinco etapas antes de comenzar.

Distintas instrucciones pueden encontrarse simultáneamente en etapas
diferentes.

Por ejemplo, durante un determinado ciclo puede existir:

| Etapa | Instrucción |
|---|---|
| IF | I5 |
| ID | I4 |
| EX | I3 |
| MEM | I2 |
| WB | I1 |

Esto significa que las cinco etapas están trabajando simultáneamente sobre
cinco instrucciones distintas.

El objetivo principal del pipeline no es reducir necesariamente la latencia de
una instrucción individual, sino aumentar el throughput permitiendo solapar la
ejecución de varias instrucciones.

---

# 3. Registros del pipeline

La separación entre etapas se realiza mediante cuatro registros de pipeline:

- IF/ID
- ID/EX
- EX/MEM
- MEM/WB

Cada registro funciona como una fotografía del estado de una instrucción al
finalizar una etapa.

Durante un ciclo determinado, cada etapa trabaja utilizando exclusivamente la
información almacenada en el registro que la precede.

---

# 4. Registro IF/ID

IF/ID separa las etapas IF e ID.

Transporta principalmente:

- PC de la instrucción;
- instrucción de 32 bits;
- bit `valid`.

ID no utiliza directamente la instrucción que IF está buscando en ese mismo
instante.

Utiliza la instrucción almacenada previamente en IF/ID.

Por ejemplo, si:

IF está buscando I2

entonces:

IF/ID todavía contiene I1

y por lo tanto ID está procesando I1.

---

# 5. Registro ID/EX

ID/EX separa ID de EX.

Actualmente transporta:

- PC;
- valor leído de `rs1`;
- valor leído de `rs2`;
- inmediato reconstruido;
- índice `rs1`;
- índice `rs2`;
- índice `rd`;
- opcode;
- funct3;
- funct7;
- valid.

EX utiliza estos valores durante el ciclo siguiente al decode.

Los índices `rs1` y `rs2` se mantienen incluso cuando algunas instrucciones no
los utilizan semánticamente, porque serán necesarios posteriormente para
forwarding y detección de hazards.

---

# 6. Registro EX/MEM

EX/MEM separa EX de MEM.

Transporta:

- PC;
- resultado de ALU;
- dato destinado a un store;
- `rd`;
- opcode;
- funct3;
- valid.

Para una instrucción store es necesario conservar simultáneamente:

`alu_result`

y:

`store_data`

porque el primero representa la dirección efectiva de DMEM y el segundo el dato
que debe escribirse.

Ejemplo:

`sw x5,12(x6)`

EX calcula:

`address = x6 + 12`

mientras que:

`store_data = x5`

Ambos valores deben llegar a MEM.

---

# 7. Registro MEM/WB

MEM/WB separa MEM de WB.

Transporta:

- PC;
- resultado de ALU;
- dato cargado desde memoria;
- `rd`;
- opcode;
- valid.

WB utiliza esta información para seleccionar el valor que finalmente se escribirá
en el Register File.

Para una operación ALU se utiliza:

`mem_wb_alu_result`

Para un load se utiliza:

`mem_wb_load_data`

Para JAL/JALR se utiliza:

`mem_wb_pc + 4`

---

# 8. Por qué el destino debe acompañar a la instrucción

Cuando una instrucción llega a WB, ID ya está procesando una instrucción
completamente distinta.

Por lo tanto WB no puede utilizar el `rd` correspondiente a la instrucción que
se encuentra actualmente en ID.

El `rd` de cada instrucción debe viajar junto con ella a través de los registros
intermedios.

Ejemplo:

si en un ciclo:

ID procesa una instrucción cuyo destino es `x20`

pero:

WB está terminando un load cuyo destino es `x5`

el dato del load debe escribirse en `x5`.

Por eso el `rd` correspondiente al load debe haber viajado hasta MEM/WB.

---

# 9. Señales de control y datos

No solamente los datos pertenecen a una instrucción determinada.

Las decisiones de control también deben pertenecer a la misma instrucción.

Por ejemplo:

si durante un ciclo:

ID procesa:

`addi`

mientras que EX procesa:

`add`

EX no puede utilizar directamente el `ALUSrc` generado para el `addi`.

`addi` necesita:

`operand_b = immediate`

mientras que:

`add`

necesita:

`operand_b = rs2`

Utilizar el control de la instrucción que se encuentra en ID sobre los datos de
la instrucción que se encuentra en EX produciría un resultado incorrecto.

La solución definitiva será generar señales de control en ID y transportarlas
junto con la instrucción mediante los registros del pipeline.

Esta mejora se realizará en el paso dedicado a la unidad de control.

---

# 10. Decisión temporal de control

La primera integración todavía no implementa la unidad de control central.

Por este motivo se utiliza temporalmente información como:

- opcode;
- funct3;
- funct7;

para volver a derivar algunas decisiones en etapas posteriores.

Particularmente, `pipeline_core.sv` genera temporalmente:

- `alu_src_a`;
- `alu_src_b`;

a partir de:

`id_ex_opcode`

Es importante que se utilice `id_ex_opcode` y no la instrucción actualmente
presente en IF/ID.

De esta forma la selección de operandos corresponde a la instrucción que
realmente está en EX.

---

# 11. Selección temporal de operandos de EX

La lógica utilizada actualmente es:

| Clase | alu_src_a | alu_src_b |
|---|---:|---:|
| R-type | rs1 | rs2 |
| I-ALU | rs1 | immediate |
| LOAD | rs1 | immediate |
| STORE | rs1 | immediate |
| BRANCH | rs1 | rs2 |
| LUI | no relevante | immediate |
| JAL | PC | immediate |
| JALR | rs1 | immediate |

La resolución completa de branches y jumps todavía no forma parte de esta
integración.

---

# 12. Control temporal del avance del pipeline

En esta primera integración todos los registros avanzan en cada ciclo.

Se utiliza:

`if_enable = 1`

`id_enable = 1`

`ex_enable = 1`

`mem_enable = 1`

No se implementan todavía stalls automáticos.

También se mantienen inactivos:

`flush_if_id = 0`

`flush_id_ex = 0`

`flush_ex_mem = 0`

`flush_mem_wb = 0`

y:

`redirect_valid = 0`

Por lo tanto el PC avanza secuencialmente de cuatro en cuatro.

---

# 13. Pipeline Core

El nuevo módulo principal de esta integración es:

`rtl/pipeline_core.sv`

Este módulo instancia y conecta:

- `if_stage`
- `id_stage`
- `ex_stage`
- `mem_stage`
- `wb_stage`

Además conecta la realimentación de WB hacia el banco de registros contenido
dentro de ID.

La conexión de realimentación es:

`wb_write_enable`

`wb_write_register`

`wb_write_data`

hacia las entradas WB de `id_stage`.

Esta conexión permite que los resultados de una instrucción modifiquen
finalmente el estado arquitectónico del Register File.

---

# 14. Flujo completo del datapath

El recorrido completo de una instrucción es:

IF

-> IF/ID

-> ID

-> ID/EX

-> EX

-> EX/MEM

-> MEM

-> MEM/WB

-> WB

-> Register File

Por primera vez se verificó este recorrido completo dentro de una única
instancia de procesador.

---

# 15. NOP utilizado en simulación

Después de las instrucciones reales se utiliza:

`0x00000013`

que corresponde a:

`addi x0,x0,0`

Esta instrucción se utiliza como NOP.

Conceptualmente realiza:

`x0 = x0 + 0`

pero `x0` no puede modificarse.

Por lo tanto no genera ningún cambio arquitectónico.

Es importante distinguir:

NOP:

`valid = 1`

Burbuja:

`valid = 0`

Un NOP es una instrucción real que atraviesa todas las etapas del pipeline pero
no produce efectos visibles.

---

# 16. Primera prueba integrada

Testbench:

`tb/pipeline_core_tb.sv`

El objetivo de esta prueba es verificar el funcionamiento simultáneo de las cinco
etapas sin introducir hazards.

Se utiliza el siguiente programa:

| Instrucción | Código máquina |
|---|---|
| `addi x5,x0,10` | `00A00293` |
| `addi x6,x0,20` | `01400313` |
| `lui x7,0x12345` | `123453B7` |
| `xor x8,x0,x0` | `00004433` |
| `addi x9,x0,-3` | `FFD00493` |

El resto de IMEM se llena con:

`00000013`

correspondiente a NOP.

---

# 17. Motivo de elección del primer programa

Las cinco instrucciones fueron elegidas de forma que ninguna dependa del
resultado producido por una instrucción inmediatamente anterior.

Esto evita introducir todavía:

- forwarding;
- stalls;
- detección de dependencias RAW.

El objetivo de esta prueba no es resolver hazards sino verificar que las etapas
pueden funcionar simultáneamente sin mezclar información perteneciente a
instrucciones distintas.

---

# 18. Llenado del pipeline

El recorrido esperado es:

| Ciclo | IF | ID | EX | MEM | WB |
|---:|---|---|---|---|---|
| 1 | I1 | - | - | - | - |
| 2 | I2 | I1 | - | - | - |
| 3 | I3 | I2 | I1 | - | - |
| 4 | I4 | I3 | I2 | I1 | - |
| 5 | I5 | I4 | I3 | I2 | I1 |

Durante el quinto ciclo las cinco etapas se encuentran ocupadas
simultáneamente.

---

# 19. Evidencia de pipeline lleno

La simulación verificó explícitamente el instante:

| Etapa | Instrucción | PC |
|---|---|---:|
| IF | I5 | 16 |
| ID | I4 | 12 |
| EX | I3 | 8 |
| MEM | I2 | 4 |
| WB | I1 | 0 |

Las señales observadas fueron:

`if_pc_current = 0x10`

`if_id_pc = 0x0C`

`id_ex_pc = 0x08`

`ex_mem_pc = 0x04`

`mem_wb_pc = 0x00`

Resultado de simulación:

`PASS: PIPELINE FULL`

Esta constituye la primera evidencia directa de cinco instrucciones distintas
ocupando simultáneamente las cinco etapas del procesador.

---

# 20. Resultados en EX

La secuencia de resultados generada fue:

| Instrucción | Resultado |
|---|---|
| I1 | `0000000A` |
| I2 | `00000014` |
| I3 | `12345000` |
| I4 | `00000000` |
| I5 | `FFFFFFFD` |

La secuencia de registros destino observada en EX/MEM y posteriormente MEM/WB
fue:

`x5 -> x6 -> x7 -> x8 -> x9`

confirmando que cada instrucción mantuvo asociado su propio destino.

---

# 21. Write Back de la primera prueba

La simulación produjo:

`PASS: WB I1 | x5 <- 0000000a`

`PASS: WB I2 | x6 <- 00000014`

`PASS: WB I3 | x7 <- 12345000`

`PASS: WB I4 | x8 <- 00000000`

`PASS: WB I5 | x9 <- fffffffd`

Los valores finales fueron:

| Registro | Valor |
|---|---|
| x0 | `00000000` |
| x5 | `0000000A` |
| x6 | `00000014` |
| x7 | `12345000` |
| x8 | `00000000` |
| x9 | `FFFFFFFD` |

Resultado final:

`PASS: pipeline_core`

---

# 22. Caso especial de x8

La instrucción:

`xor x8,x0,x0`

produce correctamente:

`0 XOR 0 = 0`

Por lo tanto WB escribe cero en `x8`.

Como el Register File ya contenía cero después del reset, la waveform no muestra
una transición visible sobre `x8`.

Sin embargo, el testbench comprueba explícitamente que el write-back se produjo.

---

# 23. Campos físicos y semánticos

Durante la observación de ID/EX pueden aparecer valores aparentemente extraños
en campos como `rs2` para instrucciones I-type.

Esto ocurre porque `field_decoder.sv` realiza una separación física fija de los
bits de la instrucción.

Por ejemplo:

`instruction[24:20]`

siempre se presenta físicamente como `rs2`.

Sin embargo, en una instrucción I-type esos bits forman parte del inmediato y
no representan un segundo registro fuente semántico.

Por lo tanto:

campo físico presente

no implica:

registro semánticamente utilizado.

La interpretación correcta depende del formato y opcode de la instrucción.

---

# 24. Valid y NOPs

Después de I5, IMEM contiene NOPs.

Por este motivo:

`valid = 1`

continúa propagándose por los registros del pipeline.

Cuando uno de estos NOPs llega a WB:

`rd = x0`

por lo tanto:

`wb_write_enable = 0`

Es posible entonces observar simultáneamente:

`mem_wb_valid = 1`

y:

`wb_write_enable = 0`

Esto no representa una contradicción.

Significa que existe una instrucción válida en WB, pero esa instrucción no genera
un cambio arquitectónico.

---

# 25. Drenaje real todavía no implementado

La primera simulación no detiene realmente IF al finalizar el programa.

En cambio, las instrucciones reales son seguidas por NOPs.

Por lo tanto el pipeline termina lleno de NOPs en lugar de quedar completamente
vacío.

La implementación futura de HALT deberá:

- detener la entrada de instrucciones nuevas;
- permitir que las instrucciones ya presentes terminen;
- detectar cuándo todos los registros del pipeline tienen `valid = 0`.

Ese proceso será el drenaje real del pipeline.

---

# 26. Segunda prueba integrada: memoria

Testbench:

`tb/pipeline_core_memory_tb.sv`

El objetivo de esta segunda prueba es verificar el camino completo de acceso a
DMEM dentro del procesador integrado.

El programa utilizado es:

`addi x1,x0,64`

`addi x2,x0,85`

NOP

NOP

NOP

NOP

`sw x2,0(x1)`

`lw x3,0(x1)`

seguido nuevamente por NOPs.

---

# 27. Motivo de los NOPs antes del store

El procesador todavía no implementa forwarding ni detección automática de
hazards.

Las instrucciones:

`addi x1,x0,64`

y:

`addi x2,x0,85`

producen valores que posteriormente necesita:

`sw x2,0(x1)`

Si el store apareciera inmediatamente después, podría leer los valores antiguos
de `x1` y `x2` antes de que los ADDI hayan llegado a WB.

Para evitar ese RAW hazard durante esta prueba se insertan NOPs manualmente.

Así:

`x1 = 64`

y:

`x2 = 85`

ya se encuentran escritos en el Register File cuando el store llega a ID.

---

# 28. Códigos de la prueba de memoria

Las instrucciones utilizadas son:

| Instrucción | Código máquina |
|---|---|
| `addi x1,x0,64` | `04000093` |
| `addi x2,x0,85` | `05500113` |
| `sw x2,0(x1)` | `0020A023` |
| `lw x3,0(x1)` | `0000A183` |
| NOP | `00000013` |

---

# 29. Preparación del estado para el store

Las dos primeras instrucciones producen:

`x1 = 64 = 0x00000040`

`x2 = 85 = 0x00000055`

La simulación confirmó:

`PASS: WB I1 | x1 <- 00000040`

`PASS: WB I2 | x2 <- 00000055`

---

# 30. Store integrado

La instrucción:

`sw x2,0(x1)`

utiliza:

`x1 = 0x40`

como dirección base y:

`x2 = 0x55`

como dato.

En EX se calcula:

`alu_result = x1 + 0`

por lo tanto:

`alu_result = 0x00000040`

EX/MEM transporta simultáneamente:

`ex_mem_alu_result = 0x00000040`

y:

`ex_mem_store_data = 0x00000055`

En MEM se genera:

`memory_write_enable = 1`

y para SW:

`store_byte_enable = 1111`

Por lo tanto los cuatro bytes de la palabra quedan habilitados.

Resultado:

`DMEM[64] = 0x00000055`

La simulación confirmó:

`PASS: STORE IN MEM | address=00000040 | data=00000055`

---

# 31. Organización física de la dirección de DMEM

La dirección utilizada por el programa es:

`64 bytes`

Como DMEM está organizada internamente en palabras de 32 bits:

`64 / 4 = 16`

Por lo tanto el dato se encuentra físicamente en:

`memory[16]`

El testbench comprueba directamente:

`data_memory_inst.memory[16]`

y obtuvo:

`00000055`

---

# 32. Load integrado

La instrucción:

`lw x3,0(x1)`

calcula nuevamente en EX:

`address = 0x00000040`

Cuando llega a MEM, Data Memory entrega:

`memory_read_data = 0x00000055`

Load Unit formatea el dato como una palabra completa.

MEM/WB contiene:

`mem_wb_alu_result = 0x00000040`

`mem_wb_load_data = 0x00000055`

`mem_wb_rd = 3`

`mem_wb_opcode = LOAD`

`mem_wb_valid = 1`

---

# 33. Diferencia entre dirección y dato de load

Esta prueba permite observar claramente dos valores distintos:

`alu_result = 0x40`

representa:

la dirección efectiva de DMEM.

Mientras que:

`load_data = 0x55`

representa:

el valor leído desde esa dirección.

WB debe seleccionar:

`load_data`

y no:

`alu_result`.

---

# 34. Write Back del load

WB reconoce el opcode LOAD y selecciona:

`mem_wb_load_data`

Genera:

`wb_write_enable = 1`

`wb_write_register = 3`

`wb_write_data = 0x00000055`

En el siguiente flanco el Register File queda:

`x3 = 0x00000055`

La simulación confirmó:

`PASS: WB I4 LOAD | x3 <- 00000055`

---

# 35. Store no produce Write Back

La instrucción SW modifica DMEM durante MEM.

No debe escribir ningún registro durante WB.

Por lo tanto la secuencia total de escrituras reales al Register File en esta
prueba es:

`x1`

`x2`

`x3`

El testbench exige exactamente tres write-backs.

El store no aparece como escritura de Register File.

---

# 36. Estado final de la segunda prueba

La simulación finalizó con:

`x1 = 00000040`

`x2 = 00000055`

`x3 = 00000055`

`DMEM[64] = 00000055`

Resultados:

`PASS: FINAL MEMORY PIPELINE STATE`

`PASS: pipeline_core_memory`

---

# 37. Lecturas X de DMEM en simulación

Durante algunos ciclos puede observarse:

`XXXXXXXX`

en señales como:

`memory_read_data`

Esto ocurre porque algunas direcciones de DMEM no fueron inicializadas en la
simulación.

No constituye un error si la instrucción activa en ese momento no necesita
utilizar ese valor.

Cuando el `lw` accede a la dirección realmente utilizada:

`0x40`

la memoria ya contiene:

`0x55`

y el valor leído es completamente definido.

---

# 38. Warning de pc_current

Durante la elaboración aparece actualmente:

`port 'pc_current' remains unconnected`

en la instancia de `if_stage` dentro de `pipeline_core.sv`.

Esta salida no es necesaria para el funcionamiento actual del datapath.

El testbench puede observarla jerárquicamente mediante la instancia interna de
IF.

Por lo tanto el warning no afecta las simulaciones realizadas.

Más adelante puede conectarse explícitamente a una señal del núcleo para:

- debug;
- observabilidad;
- interfaz de Debug Unit.

---

# 39. Corrección realizada durante la integración

Durante la primera elaboración se detectó una diferencia de nombre en la interfaz
de IF.

`pipeline_core.sv` intentaba conectar:

`redirect_target`

como nombre de puerto de `if_stage`.

El puerto real de `if_stage` es:

`redirect_pc`

La conexión fue corregida a:

`.redirect_pc(redirect_target)`

No fue necesario modificar `if_stage.sv`.

Luego de esta corrección la elaboración del núcleo completo fue exitosa.

---

# 40. Funcionalidades todavía no implementadas

La integración actual todavía no resuelve:

- hazards RAW;
- forwarding;
- load-use hazard;
- stalls automáticos;
- control central pipelineado;
- branches completos;
- JAL completo;
- JALR completo;
- redirects reales;
- flushes por control hazard;
- HALT;
- drenaje real;
- modo step;
- Debug Unit;
- recarga dinámica de programas;
- memoria definitiva mediante IP de Vivado.

Los programas de validación actuales fueron elegidos específicamente para no
necesitar todavía estas funcionalidades.

---

# 41. Limitación respecto de dependencias

Una secuencia como:

`add x5,x1,x2`

seguida inmediatamente por:

`sub x6,x5,x3`

todavía no está soportada correctamente sin separación adicional.

La segunda instrucción puede leer `x5` antes de que la primera lo escriba en WB.

Este caso será tratado posteriormente mediante forwarding y lógica de hazards.

---

# 42. Archivos agregados en este paso

RTL:

`rtl/pipeline_core.sv`

Testbenches:

`tb/pipeline_core_tb.sv`

`tb/pipeline_core_memory_tb.sv`

Documentación:

`docs/pipeline_core.md`

---

# 43. Evidencias obtenidas

Primera prueba:

`PASS: PIPELINE FULL`

`PASS: WB I1`

`PASS: WB I2`

`PASS: WB I3`

`PASS: WB I4`

`PASS: WB I5`

`PASS: FINAL REGISTER FILE`

`PASS: pipeline_core`

Segunda prueba:

`PASS: WB I1`

`PASS: WB I2`

`PASS: STORE IN MEM`

`PASS: WB I4 LOAD`

`PASS: LOAD IN MEM/WB`

`PASS: FINAL MEMORY PIPELINE STATE`

`PASS: pipeline_core_memory`

---

# 44. Resultado del Paso 10

La integración demostró correctamente:

- funcionamiento simultáneo de IF, ID, EX, MEM y WB;
- propagación correcta del PC de cada instrucción;
- propagación correcta de `rd`;
- propagación correcta de resultados de ALU;
- realimentación WB hacia Register File;
- escritura efectiva de registros;
- store efectivo sobre DMEM;
- load desde DMEM hasta Register File;
- aislamiento entre instrucciones distintas;
- utilización de NOPs para evitar hazards todavía no implementados.

Se verificó experimentalmente un pipeline con las cinco etapas ocupadas
simultáneamente:

IF = I5

ID = I4

EX = I3

MEM = I2

WB = I1

Estado:

`Paso 10 — integración pipeline sin hazards: VALIDADO`
