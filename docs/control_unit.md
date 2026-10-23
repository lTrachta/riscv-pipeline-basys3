# Paso 11 — Unidad de Control y Control Pipelineado

## 1. Objetivo

El objetivo de este paso fue reemplazar el esquema temporal de control utilizado durante la integración inicial del pipeline por una arquitectura de control centralizada y segmentada.

Hasta el Paso 10, distintas etapas del procesador volvían a interpretar campos como `opcode`, `funct3` y `funct7` para decidir localmente qué operación realizar.

Ese enfoque permitió desarrollar y validar las etapas de forma incremental, pero no representa la organización definitiva de un procesador segmentado.

En este paso se implementó una `Control Unit` ubicada conceptualmente en la etapa ID.

La nueva arquitectura realiza:

1. Decodificación de la instrucción en ID.
2. Generación de todas las señales de control necesarias.
3. Transporte de esas señales junto con la instrucción a través de los registros del pipeline.
4. Consumo progresivo del control por EX, MEM y WB.

El resultado es:

`ID -> genera EX + MEM + WB`

`ID/EX -> transporta EX + MEM + WB`

`EX -> consume EX`

`EX/MEM -> transporta MEM + WB`

`MEM -> consume MEM`

`MEM/WB -> transporta WB`

`WB -> consume WB`

---

# 2. Subconjunto de instrucciones considerado

La Control Unit fue diseñada para el subconjunto requerido por el trabajo práctico.

## R-Type

- `add`
- `sub`
- `sll`
- `srl`
- `sra`
- `and`
- `or`
- `xor`
- `slt`
- `sltu`

## I-Type ALU

- `addi`
- `andi`
- `ori`
- `xori`
- `slti`
- `sltiu`
- `slli`
- `srli`
- `srai`

## Loads

- `lb`
- `lh`
- `lw`
- `lbu`
- `lhu`

## Stores

- `sb`
- `sh`
- `sw`

## Branches

- `beq`
- `bne`

## U-Type

- `lui`

## Jumps

- `jal`
- `jalr`

En total se consideran 32 instrucciones concretas.

---

# 3. Problema del control temporal anterior

Antes de este paso, el pipeline funcionaba de la siguiente forma.

EX volvía a mirar el `opcode` para decidir:

- fuente del operando A;
- fuente del operando B.

MEM volvía a mirar el `opcode` para decidir:

- si la instrucción era load;
- si la instrucción era store.

WB volvía a mirar el `opcode` para decidir:

- si debía escribir el Register File;
- qué fuente utilizar para write-back.

Este mecanismo era funcional, pero implicaba interpretar repetidamente una instrucción en distintas etapas.

Además, en un pipeline existen varias instrucciones simultáneamente.

Por ejemplo:

| Etapa | Instrucción |
|---|---|
| ID | `lw` |
| EX | `xor` |
| MEM | `sw` |
| WB | `addi` |

La señal generada en ID para el `lw` no puede controlar directamente EX, porque EX está procesando un `xor`.

Cada instrucción necesita transportar su propio control.

---

# 4. Nueva arquitectura de control

La instrucción se interpreta una sola vez en ID.

La `Control Unit` recibe:

- `opcode`
- `funct3`
- `funct7`

y genera una palabra de control.

Las señales generadas son:

## Control EX

- `alu_src_a`
- `alu_src_b`
- `alu_op[2:0]`
- `branch`
- `jump_type[1:0]`

## Control MEM

- `mem_read`
- `mem_write`

## Control WB

- `reg_write`
- `wb_sel[1:0]`

Además se genera:

- `control_valid`

para indicar si la codificación pertenece al subconjunto implementado.

---

# 5. Señal `alu_src_a`

Selecciona el primer operando de la ALU.

Codificación:

`0 -> rs1`

`1 -> PC`

La mayoría de las instrucciones utilizan `rs1`.

El caso principal que utiliza PC es:

`jal`

porque el target se calcula conceptualmente como:

`PC + immediate`

---

# 6. Señal `alu_src_b`

Selecciona el segundo operando de la ALU.

Codificación:

`0 -> rs2`

`1 -> immediate`

Ejemplos:

R-Type:

`rs1 OP rs2`

por lo tanto:

`alu_src_b = 0`

I-Type:

`rs1 OP immediate`

por lo tanto:

`alu_src_b = 1`

Loads y stores utilizan:

`rs1 + immediate`

por lo tanto:

`alu_src_b = 1`

---

# 7. Diferencia entre `alu_op` y `alu_operation`

Esta distinción es fundamental.

## `alu_op`

Es una señal de control general generada en ID.

Codificación utilizada:

| `alu_op` | Significado |
|---|---|
| `000` | ADD |
| `001` | SUB |
| `010` | R-DECODE |
| `011` | I-DECODE |
| `100` | PASS_B |
| `101-111` | reservado |

La Control Unit no necesita generar directamente todas las operaciones concretas de la ALU.

Por ejemplo, para una instrucción R-Type genera:

`alu_op = R-DECODE`

## `alu_operation`

Es la operación exacta enviada físicamente a la ALU.

Ejemplos:

- ADD
- SUB
- AND
- OR
- XOR
- SLL
- SRL
- SRA
- SLT
- SLTU
- PASS_B

La conversión:

`alu_op + funct3 + funct7 -> alu_operation`

se realiza en `alu_control.sv`.

---

# 8. ALU Control

Antes del Paso 11, `alu_control.sv` recibía:

- `opcode`
- `funct3`
- `funct7`

y resolvía toda la operación.

Después de la migración recibe:

- `alu_op`
- `funct3`
- `funct7`

El `opcode` deja de ser necesario para decidir la operación de ALU.

Ejemplo:

Para:

`xor x5,x6,x7`

Control Unit genera:

`alu_op = R-DECODE`

Después ALU Control analiza:

`funct3 = 100`

`funct7 = 0000000`

y genera:

`alu_operation = XOR`

---

# 9. Control de memoria

Se definieron dos señales explícitas.

## `mem_read`

Indica que la instrucción necesita leer DMEM.

Es activa únicamente para:

- `lb`
- `lh`
- `lw`
- `lbu`
- `lhu`

## `mem_write`

Indica que la instrucción necesita escribir DMEM.

Es activa únicamente para:

- `sb`
- `sh`
- `sw`

La nueva etapa MEM ya no determina si la instrucción es load/store mirando el opcode.

Utiliza directamente:

`ex_mem_mem_read`

`ex_mem_mem_write`

---

# 10. `reg_write`

Indica que la instrucción produce un valor para `rd`.

Es activo para:

- R-Type
- I-Type ALU
- loads
- `lui`
- `jal`
- `jalr`

Es inactivo para:

- stores
- branches

La habilitación final de escritura sigue verificando:

`rd != x0`

para preservar el comportamiento de `x0`.

---

# 11. `wb_sel`

Selecciona la fuente del valor escrito en el Register File.

Se utilizan dos bits porque existen tres fuentes posibles.

| `wb_sel` | Fuente |
|---|---|
| `00` | resultado ALU |
| `01` | dato leído de memoria |
| `10` | PC + 4 |
| `11` | reservado |

R-Type, I-Type y LUI:

`wb_sel = ALU`

Loads:

`wb_sel = MEM`

JAL/JALR:

`wb_sel = PC+4`

---

# 12. Control de branches

La señal:

`branch`

se activa para:

- `beq`
- `bne`

La diferencia entre ambos se mantiene en `funct3`.

Codificación:

`000 -> beq`

`001 -> bne`

Actualmente EX puede recibir correctamente:

- operands;
- `branch`;
- `funct3`;
- inmediato.

La resolución completa del branch y el redirect del PC se implementará en un paso posterior.

---

# 13. Control de jumps

Se definió:

`jump_type[1:0]`

con:

| Valor | Tipo |
|---|---|
| `00` | ninguno |
| `01` | JAL |
| `10` | JALR |
| `11` | reservado |

JAL utiliza:

`operand A = PC`

`operand B = immediate`

JALR utiliza:

`operand A = rs1`

`operand B = immediate`

Ambos escriben:

`rd = PC + 4`

por lo que tienen:

`reg_write = 1`

`wb_sel = PC+4`

La modificación real del PC todavía queda diferida al paso de control hazards.

---

# 14. Tabla general de control

| Clase | A | B | ALU Op | MemR | MemW | RegW | WB | Branch | Jump |
|---|---|---|---|---:|---:|---:|---|---:|---|
| R-Type | rs1 | rs2 | R-DECODE | 0 | 0 | 1 | ALU | 0 | NONE |
| I-ALU | rs1 | IMM | I-DECODE | 0 | 0 | 1 | ALU | 0 | NONE |
| LOAD | rs1 | IMM | ADD | 1 | 0 | 1 | MEM | 0 | NONE |
| STORE | rs1 | IMM | ADD | 0 | 1 | 0 | — | 0 | NONE |
| BEQ/BNE | rs1 | rs2 | SUB | 0 | 0 | 0 | — | 1 | NONE |
| LUI | — | IMM | PASS_B | 0 | 0 | 1 | ALU | 0 | NONE |
| JAL | PC | IMM | ADD | 0 | 0 | 1 | PC+4 | 0 | JAL |
| JALR | rs1 | IMM | ADD | 0 | 0 | 1 | PC+4 | 0 | JALR |

---

# 15. Validación de instrucciones soportadas

La Control Unit no considera válido cualquier opcode perteneciente a una familia.

También comprueba las combinaciones soportadas de:

- `funct3`
- `funct7`

Por ejemplo, para R-Type solo se aceptan las combinaciones correspondientes a las instrucciones implementadas.

Para loads solo son válidos:

- `000`
- `001`
- `010`
- `100`
- `101`

Para stores:

- `000`
- `001`
- `010`

Para branches:

- `000`
- `001`

Para JALR:

`funct3 = 000`

---

# 16. `control_valid`

La Control Unit genera:

`control_valid = 1`

solo cuando la codificación pertenece al subconjunto soportado.

En `id_stage.sv` se genera:

`id_ex_valid_in = if_id_valid && control_valid`

Por lo tanto, si IF/ID contiene una codificación no soportada:

`if_id_valid = 1`

`control_valid = 0`

el resultado será:

`id_ex_valid = 0`

La instrucción se transforma en una burbuja.

No se implementa todavía una excepción de instrucción ilegal.

---

# 17. Valores neutrales por defecto

La Control Unit comienza cada evaluación asignando valores seguros.

Entre ellos:

`mem_write = 0`

`mem_read = 0`

`reg_write = 0`

`branch = 0`

`jump_type = NONE`

`control_valid = 0`

Así una codificación desconocida no puede provocar accidentalmente:

- escritura de memoria;
- escritura de registros;
- branch;
- jump.

---

# 18. Pipelineado del control

La palabra completa de control se genera en ID.

Sin embargo no todas las señales necesitan atravesar las cinco etapas.

Cada grupo solamente viaja hasta la etapa donde será utilizado.

## ID/EX

Transporta:

### EX

- `alu_src_a`
- `alu_src_b`
- `alu_op`
- `branch`
- `jump_type`

### MEM

- `mem_read`
- `mem_write`

### WB

- `reg_write`
- `wb_sel`

---

# 19. EX consume su control

EX utiliza:

- `alu_src_a`
- `alu_src_b`
- `alu_op`

y posteriormente utilizará:

- `branch`
- `jump_type`

para resolver cambios de flujo.

Después de EX esas señales ya no son necesarias.

---

# 20. EX/MEM

EX/MEM solamente conserva:

## MEM

- `mem_read`
- `mem_write`

## WB

- `reg_write`
- `wb_sel`

Esto evita transportar señales cuyo propósito ya fue cumplido.

---

# 21. MEM consume su control

MEM utiliza:

- `mem_read`
- `mem_write`

para decidir el comportamiento de DMEM.

Una vez terminada MEM, esas señales ya no deben continuar.

---

# 22. MEM/WB

MEM/WB conserva únicamente:

- `reg_write`
- `wb_sel`

además de los datos necesarios para Write Back.

---

# 23. WB consume el último grupo de control

WB dejó de interpretar el opcode.

Ahora recibe directamente:

`mem_wb_reg_write`

`mem_wb_wb_sel`

El multiplexor selecciona:

`00 -> ALU result`

`01 -> load data`

`10 -> PC+4`

`11 -> inválido`

El write enable final es:

`valid && reg_write && wb_sel válido && rd != 0`

---

# 24. Eliminación de la dependencia de opcode en WB

Se realizó una prueba específica donde:

`opcode = 1111111`

pero:

`valid = 1`

`reg_write = 1`

`wb_sel = ALU`

WB produjo correctamente:

`WE = 1`

`rd = 14`

`data = ABCDEF01`

Esto demuestra que WB ya no utiliza el opcode para decidir el comportamiento.

---

# 25. Store data en EX

Durante la migración se mantuvo una decisión importante del datapath.

Para:

`sw x5,8(x6)`

EX calcula:

`operand A = x6`

`operand B = 8`

`ALU result = x6 + 8`

Pero el dato escrito en memoria sigue siendo:

`x5`

Por eso:

`store_data_in = id_ex_read_data2`

y no:

`store_data_in = operand_b`

Esto evita escribir el inmediato en lugar del dato del registro fuente.

---

# 26. Accesos desalineados

MEM conserva las comprobaciones de alineación implementadas previamente.

Política actual:

Byte:

- cualquier offset.

Halfword:

- offsets 0 y 2.

Word:

- offset 0.

Un load/store desalineado se neutraliza mediante:

`mem_wb_valid = 0`

No se implementa todavía una excepción arquitectónica.

---

# 27. Protección ante MemRead + MemWrite simultáneos

Se agregó una protección defensiva.

Una combinación:

`mem_read = 1`

`mem_write = 1`

es considerada inválida.

En ese caso:

- `mem_wb_valid = 0`
- no se permite escritura de DMEM
- no se genera un load válido

Esta situación no debería ser producida por la Control Unit, pero la etapa MEM queda protegida ante una señal de control inconsistente.

---

# 28. Flush de registros del pipeline

Durante este paso se reforzó el comportamiento de flush.

Antes algunos registros simplemente colocaban:

`valid = 0`

manteniendo físicamente otros valores.

Ahora también se neutralizan las señales de control relevantes.

Ejemplo:

al hacer flush sobre EX/MEM:

`mem_read = 0`

`mem_write = 0`

`reg_write = 0`

`wb_sel = 0`

Esto garantiza que una burbuja no conserve accidentalmente una señal con efectos laterales.

---

# 29. Hold

La prioridad de los registros continúa siendo:

`reset > flush > enable > hold`

Cuando:

`enable = 0`

los datos y controles permanecen congelados.

Esto será fundamental posteriormente para implementar stalls.

---

# 30. Test de Control Unit aislada

Archivo:

`tb/control_unit_tb.sv`

Se verificaron las 32 instrucciones requeridas y ocho casos inválidos.

Resultado:

`Tests run: 40`

`Tests passed: 40`

`Tests failed: 0`

`PASS: control_unit`

---

# 31. Test ID + Control + ID/EX

Archivo:

`tb/id_control_pipeline_tb.sv`

Se verificaron:

- XOR
- LW
- SW
- BEQ
- JAL
- JALR
- HOLD
- FLUSH
- instrucción inválida

Resultado:

`Tests run: 9`

`Tests passed: 9`

`Tests failed: 0`

`PASS: id_control_pipeline`

Este test demostró que los datos y el control de una misma instrucción quedan almacenados juntos en ID/EX.

---

# 32. Test EX + Control + EX/MEM

Archivo:

`tb/ex_control_pipeline_tb.sv`

Se verificaron:

- XOR
- ADDI
- LW
- SW
- BEQ
- LUI
- JAL
- HOLD
- FLUSH

Resultado:

`Tests run: 9`

`Tests passed: 9`

`Tests failed: 0`

`PASS: ex_control_pipeline`

Este test verificó todas las clases principales de `alu_op`.

---

# 33. Resultados relevantes de EX

XOR:

`0x55 XOR 0x0F = 0x5A`

ADDI:

`10 + 7 = 17`

LW:

`0x40 + 12 = 0x4C`

SW:

`0x40 + 8 = 0x48`

y:

`store_data = 0x55`

BEQ:

`0x55 - 0x55 = 0`

LUI:

`PASS_B -> 0x12345000`

JAL:

`0x200 + 0x20 = 0x220`

---

# 34. Test MEM + Control + MEM/WB

Archivo:

`tb/mem_control_pipeline_tb.sv`

Se verificaron:

- SW
- LW
- ALU pass-through
- JAL
- HOLD
- load desalineado
- MemRead+MemWrite ilegal
- FLUSH

Resultado:

`Tests run: 8`

`Tests passed: 8`

`Tests failed: 0`

`PASS: mem_control_pipeline`

---

# 35. Resultado real sobre DMEM

Durante el test MEM:

`SW -> DMEM[0x40] = 0x00000055`

Después:

`LW <- DMEM[0x40]`

produjo:

`load_data = 0x00000055`

También se comprobó que:

- HOLD no modifica DMEM.
- MemRead+MemWrite simultáneos no modifican DMEM.
- instrucciones ALU no modifican DMEM.

---

# 36. Test WB

Archivo:

`tb/wb_control_pipeline_tb.sv`

Se verificaron:

- selección ALU
- selección LOAD
- selección PC+4
- `RegWrite=0`
- `rd=x0`
- `valid=0`
- `wb_sel=11`
- opcode ignorado

Resultado:

`Tests run: 8`

`Tests passed: 8`

`Tests failed: 0`

`PASS: wb_control_pipeline`

---

# 37. Integración completa del pipeline

Después de validar cada etapa por separado se actualizó:

`rtl/pipeline_core.sv`

El bloque temporal que reconstruía `alu_src_a` y `alu_src_b` mirando `id_ex_opcode` fue eliminado.

Ahora `pipeline_core` únicamente conecta las señales pipelineadas entre etapas.

---

# 38. Eliminación del warning `pc_current`

La salida:

`pc_current`

de `if_stage` anteriormente estaba sin conectar dentro de `pipeline_core`.

Se agregó:

`if_pc_current`

y se conectó:

`.pc_current(if_pc_current)`

Esto elimina el warning de puerto desconectado y mejora la observabilidad para debug futuro.

---

# 39. Regresión end-to-end: pipeline general

Se volvió a ejecutar sin cambiar el resultado esperado:

`tb/pipeline_core_tb.sv`

Resultado:

`PASS: PIPELINE FULL`

Con:

| Etapa | Instrucción |
|---|---|
| IF | I5 |
| ID | I4 |
| EX | I3 |
| MEM | I2 |
| WB | I1 |

Write-backs:

`x5 <- 0000000A`

`x6 <- 00000014`

`x7 <- 12345000`

`x8 <- 00000000`

`x9 <- FFFFFFFD`

Resultado:

`PASS: pipeline_core`

---

# 40. Regresión end-to-end: memoria

Se volvió a ejecutar:

`tb/pipeline_core_memory_tb.sv`

Resultados:

`x1 = 00000040`

`x2 = 00000055`

`DMEM[64] = 00000055`

`x3 = 00000055`

Resultado:

`PASS: pipeline_core_memory`

Esto demuestra que la migración del control no alteró el comportamiento funcional del datapath previamente validado.

---

# 41. Comparación antes y después

## Antes

Cada etapa volvía a interpretar parte de la instrucción.

`opcode -> EX`

`opcode -> MEM`

`opcode -> WB`

## Después

ID interpreta la instrucción una sola vez.

`instruction`

`-> Control Unit`

`-> control EX + MEM + WB`

`-> registros de pipeline`

`-> consumidores correspondientes`

---

# 42. Ventajas de la nueva arquitectura

La nueva implementación presenta:

- separación clara entre datapath y control;
- control asociado correctamente con cada instrucción;
- menor duplicación de decodificación;
- mejor soporte para pipeline real;
- base adecuada para hazards;
- base adecuada para stalls;
- base adecuada para flushes;
- mejor observabilidad;
- validación de instrucciones no soportadas;
- neutralización defensiva de efectos laterales.

---

# 43. Archivos RTL modificados o agregados

Nuevo:

`rtl/control_unit.sv`

Modificados:

`rtl/id_ex_register.sv`

`rtl/id_stage.sv`

`rtl/alu_control.sv`

`rtl/ex_mem_register.sv`

`rtl/ex_stage.sv`

`rtl/mem_wb_register.sv`

`rtl/mem_stage.sv`

`rtl/wb_stage.sv`

`rtl/pipeline_core.sv`

---

# 44. Testbenches agregados

`tb/control_unit_tb.sv`

`tb/id_control_pipeline_tb.sv`

`tb/ex_control_pipeline_tb.sv`

`tb/mem_control_pipeline_tb.sv`

`tb/wb_control_pipeline_tb.sv`

Además se reutilizaron como pruebas de regresión:

`tb/pipeline_core_tb.sv`

`tb/pipeline_core_memory_tb.sv`

---

# 45. Funcionalidades todavía pendientes

El Paso 11 no implementa todavía:

- detección de hazards RAW;
- forwarding;
- stalls automáticos;
- load-use hazard;
- resolución completa de branches;
- resolución completa de JAL/JALR;
- redirect del PC;
- flush automático por control hazards;
- HALT;
- drenaje real;
- Debug Unit;
- modo step;
- recarga dinámica de programas.

Estas funcionalidades se apoyarán en la nueva arquitectura de control.

---

# 46. Relación con el próximo paso

El siguiente paso es el estudio de hazards.

Ahora contamos con señales como:

- `reg_write`
- `rd`
- `rs1`
- `rs2`
- `mem_read`
- `valid`

transportadas correctamente con cada instrucción.

Estas señales permitirán determinar cuándo una instrucción depende de otra.

Ejemplo:

`add x5,x1,x2`

`sub x6,x5,x3`

La segunda instrucción necesita `x5` antes de que la primera llegue naturalmente a WB.

La resolución de estas dependencias será tratada mediante:

- forwarding;
- detección de hazards;
- stalls;
- burbujas.

---

# 47. Resultado del Paso 11

Se implementó y validó una unidad de control centralizada en ID.

Las señales de control se generan una única vez y viajan junto con la instrucción a través del pipeline.

Cada etapa consume exclusivamente el grupo de señales que le corresponde.

Las pruebas unitarias, de integración por etapa y las regresiones end-to-end finalizaron correctamente.

Estado:

`Paso 11 — Unidad de Control y control pipelineado: VALIDADO`

