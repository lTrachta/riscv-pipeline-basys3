# Paso 13 — Forwarding

## 1. Objetivo

El objetivo de este paso fue implementar un mecanismo de forwarding capaz de resolver dependencias RAW sin detener innecesariamente el pipeline.

En un procesador segmentado, una instrucción puede necesitar un valor que una instrucción anterior ya calculó pero todavía no escribió en el Register File.

Ejemplo:

`add x5,x1,x2`

`sub x6,x5,x3`

Cuando `sub` llega a EX, el valor nuevo de `x5` todavía puede no encontrarse en el Register File.

Sin forwarding, `sub` utilizaría el valor antiguo leído previamente durante ID.

La idea del forwarding consiste en detectar que el resultado correcto ya se encuentra dentro del pipeline y enviarlo directamente hacia EX.

---

# 2. Problema RAW

RAW significa:

`Read After Write`

Ocurre cuando una instrucción intenta utilizar un registro que una instrucción anterior todavía debe actualizar.

Ejemplo:

`add x5,x1,x2`

`sub x6,x5,x3`

La primera instrucción produce el nuevo valor de `x5`.

La segunda consume `x5`.

Existe entonces una dependencia:

`ADD -> x5 -> SUB`

---

# 3. Disponibilidad temporal de los resultados

Los resultados no aparecen todos en el mismo momento.

Para instrucciones de ALU:

`add`

`sub`

`xor`

`addi`

etc.

el resultado útil aparece al finalizar EX.

Por lo tanto, cuando la instrucción siguiente llega a EX, el resultado anterior ya se encuentra en EX/MEM.

Para un load:

`lw`

el resultado real no aparece al finalizar EX.

EX solamente produce la dirección efectiva.

Ejemplo:

`lw x5,0(x1)`

En EX:

`alu_result = x1 + 0`

Ese valor es una dirección.

El dato cargado aparece recién durante MEM.

Esta diferencia es fundamental porque explica por qué forwarding resuelve muchas dependencias, pero no el caso load-use inmediato.

---

# 4. Fuentes posibles para un operando

Para cada registro fuente de la instrucción actualmente en EX existen tres posibilidades.

`00 -> ID/EX`

Se utiliza el valor leído normalmente del Register File.

`10 -> EX/MEM`

Se utiliza el resultado de la instrucción inmediatamente anterior.

`01 -> MEM/WB`

Se utiliza el resultado de una instrucción más antigua.

La codificación implementada fue:

| Valor | Fuente |
|---|---|
| `00` | ID/EX |
| `01` | MEM/WB |
| `10` | EX/MEM |
| `11` | reservado |

---

# 5. ForwardA y ForwardB

Se definieron dos señales independientes:

`forward_a[1:0]`

`forward_b[1:0]`

`ForwardA` controla la selección correspondiente a `rs1`.

`ForwardB` controla la selección correspondiente a `rs2`.

Esto permite situaciones como:

`ForwardA = 01`

`ForwardB = 10`

es decir:

- operando A desde MEM/WB;
- operando B desde EX/MEM.

---

# 6. Forwarding Unit

Se agregó:

`rtl/forwarding_unit.sv`

Entradas principales:

- `id_ex_rs1`
- `id_ex_rs2`
- `ex_mem_rd`
- `ex_mem_reg_write`
- `mem_wb_rd`
- `mem_wb_reg_write`

Salidas:

- `forward_a`
- `forward_b`

La unidad es completamente combinacional.

---

# 7. Detección de dependencia EX/MEM

Para `rs1`:

si:

`EX/MEM.RegWrite = 1`

`EX/MEM.rd != x0`

`EX/MEM.rd == ID/EX.rs1`

entonces:

`ForwardA = 10`

Para `rs2`:

si:

`EX/MEM.RegWrite = 1`

`EX/MEM.rd != x0`

`EX/MEM.rd == ID/EX.rs2`

entonces:

`ForwardB = 10`

---

# 8. Detección de dependencia MEM/WB

Si no existe una coincidencia válida con EX/MEM, se analiza MEM/WB.

Para `rs1`:

`MEM/WB.RegWrite = 1`

`MEM/WB.rd != x0`

`MEM/WB.rd == ID/EX.rs1`

entonces:

`ForwardA = 01`

Para `rs2`:

`MEM/WB.RegWrite = 1`

`MEM/WB.rd != x0`

`MEM/WB.rd == ID/EX.rs2`

entonces:

`ForwardB = 01`

---

# 9. Prioridad

La prioridad implementada es:

`EX/MEM > MEM/WB > ID/EX`

Esto es necesario porque EX/MEM representa una instrucción más reciente.

Ejemplo:

`add x5,x1,x2`

`sub x5,x5,x3`

`xor x6,x5,x4`

Cuando `xor` está en EX pueden existir simultáneamente:

`EX/MEM.rd = x5`

`MEM/WB.rd = x5`

Pero ambos valores no representan el mismo estado de `x5`.

El valor de EX/MEM fue producido por `sub`, que es más reciente.

Por lo tanto debe ganar EX/MEM.

---

# 10. Protección de x0

Nunca debe generarse forwarding para:

`rd = x0`

Aunque exista una coincidencia física:

`EX/MEM.rd == ID/EX.rs1`

si:

`rd = 0`

no existe una dependencia real.

`x0` mantiene permanentemente el valor cero.

---

# 11. Uso de RegWrite

La coincidencia de números de registro tampoco es suficiente.

Debe cumplirse:

`RegWrite = 1`

Ejemplo:

si:

`EX/MEM.rd = x5`

pero:

`EX/MEM.RegWrite = 0`

esa instrucción no produce un nuevo valor para `x5`.

Por lo tanto no debe utilizarse como fuente de forwarding.

Si MEM/WB contiene una coincidencia válida, MEM/WB puede utilizarse.

---

# 12. Modificación de EX

Se modificó:

`rtl/ex_stage.sv`

Antes:

`operand_a` utilizaba directamente `id_ex_read_data1`.

`operand_b` utilizaba directamente `id_ex_read_data2` cuando no se seleccionaba inmediato.

Después se agregaron:

`forwarded_rs1`

`forwarded_rs2`

Estos valores son seleccionados mediante `ForwardA` y `ForwardB`.

---

# 13. Forwarding de rs1

`forwarded_rs1` puede tomar:

- `id_ex_read_data1`
- `ex_mem_forward_value`
- `mem_wb_forward_value`

Luego:

si:

`alu_src_a = 0`

la entrada A de ALU utiliza:

`forwarded_rs1`

Si:

`alu_src_a = 1`

se utiliza PC.

Esto mantiene correctamente casos como JAL, donde A no depende del Register File.

---

# 14. Forwarding de rs2

`forwarded_rs2` puede tomar:

- `id_ex_read_data2`
- `ex_mem_forward_value`
- `mem_wb_forward_value`

Después existen dos usos diferentes.

## Operando B de ALU

Si:

`alu_src_b = 0`

la ALU utiliza:

`forwarded_rs2`

Si:

`alu_src_b = 1`

la ALU utiliza:

`immediate`

## Store data

Independientemente de `alu_src_b`, el dato destinado a memoria utiliza:

`forwarded_rs2`

Esta separación es fundamental para stores.

---

# 15. Forwarding y operandos inmediatos

Ejemplo:

`add x5,x1,x2`

`addi x6,x5,10`

`addi` necesita el nuevo valor de `x5`.

Por lo tanto:

`ForwardA = 10`

Pero la entrada B de ALU debe seguir siendo:

`10`

el inmediato.

Forwarding no reemplaza la lógica `alu_src_b`.

Primero se obtiene la versión correcta de `rs2`.

Después `alu_src_b` decide si la ALU utiliza ese registro o un inmediato.

---

# 16. Forwarding para stores

Ejemplo:

`add x5,x1,x2`

`sw x5,8(x3)`

Para `sw`:

`rs1 = x3`

`rs2 = x5`

La ALU debe calcular:

`x3 + 8`

Por lo tanto:

`operand_b = immediate`

Sin embargo el dato que debe escribirse en memoria es el nuevo valor de `x5`.

Antes:

`store_data = id_ex_read_data2`

Después:

`store_data = forwarded_rs2`

Esto permite resolver una dependencia ALU -> store sin esperar a WB.

---

# 17. Forwarding para la dirección de un store

También puede existir dependencia en la base de dirección.

Ejemplo:

`add x3,x1,x2`

`sw x5,0(x3)`

Ahora el registro dependiente es:

`rs1 = x3`

Entonces:

`ForwardA = 10`

y la ALU recibe el nuevo valor de `x3` para calcular la dirección.

---

# 18. Forwarding para branches

Ejemplo:

`add x5,x1,x2`

`beq x5,x0,TARGET`

Cuando el branch llegue a EX, necesita comparar el valor actualizado de `x5`.

El forwarding permite que los operandos correctos estén disponibles en EX.

La resolución real del branch y el redirect del PC todavía no forman parte de este paso.

---

# 19. Forwarding para JALR

JALR utiliza:

`rs1 + immediate`

para calcular su target.

Si `rs1` depende de una instrucción anterior, ForwardA puede corregir el valor antes de la ALU.

El redirect real de JALR permanece diferido al paso de control hazards.

---

# 20. Fuente EX/MEM

En `pipeline_core.sv`, la fuente de forwarding EX/MEM es:

`ex_mem_alu_result`

Esto es correcto para operaciones cuyo resultado se produce en EX.

Sin embargo existe una excepción importante:

los loads.

---

# 21. Protección ante loads en EX/MEM

Para:

`lw x5,0(x1)`

el contenido de:

`EX/MEM.alu_result`

es la dirección efectiva.

No es todavía el dato cargado.

Por eso no se permite que un load actúe como productor EX/MEM.

Se implementó:

`ex_mem_forward_reg_write =`

`ex_mem_valid &&`

`ex_mem_reg_write &&`

`!ex_mem_mem_read`

La condición:

`!ex_mem_mem_read`

evita reenviar accidentalmente una dirección como si fuese un dato cargado.

---

# 22. Fuente MEM/WB

Para forwarding desde MEM/WB se reutiliza:

`wb_write_data`

Esto es conveniente porque WB ya selecciona el valor final correcto mediante `wb_sel`.

Ese valor puede ser:

- resultado ALU;
- dato de load;
- PC+4.

Por lo tanto MEM/WB -> EX no necesita volver a interpretar el tipo de instrucción.

---

# 23. Load con una instrucción intermedia

Ejemplo:

`lw x5,0(x1)`

`addi x8,x0,1`

`add x6,x5,x2`

Cuando `add` llega a EX, el resultado del load ya se encuentra disponible en MEM/WB.

Por lo tanto puede utilizarse:

`ForwardA = 01`

sin stall.

---

# 24. Load-use inmediato

Caso:

`lw x5,0(x1)`

`add x6,x5,x2`

Cuando `add` llega a EX, `lw` está en MEM.

El dato todavía no estaba disponible desde EX/MEM.

Por eso forwarding por sí solo no puede solucionar este caso.

Este hazard requiere detener temporalmente el pipeline.

Su resolución queda explícitamente diferida al Paso 14.

---

# 25. Validación aislada de Forwarding Unit

Archivo:

`tb/forwarding_unit_tb.sv`

Se verificaron:

- ausencia de hazard;
- EX/MEM -> A;
- EX/MEM -> B;
- EX/MEM -> A+B;
- MEM/WB -> A;
- MEM/WB -> B;
- forwarding mixto;
- prioridad EX/MEM;
- protección x0;
- EX/MEM inválido y MEM/WB válido;
- RegWrite desactivado;
- MEM/WB -> A+B.

Resultado:

`Tests run: 12`

`Tests passed: 12`

`Tests failed: 0`

`PASS: forwarding_unit`

---

# 26. Validación aislada de EX con forwarding

Archivo:

`tb/ex_forwarding_pipeline_tb.sv`

Se verificaron:

- operación sin forwarding;
- EX/MEM -> A;
- MEM/WB -> A;
- A y B desde etapas diferentes;
- ADDI con forwarding solamente sobre A;
- forwarding de store data;
- operands de branch;
- base de JALR.

Resultado:

`Tests run: 8`

`Tests passed: 8`

`Tests failed: 0`

`PASS: ex_forwarding_pipeline`

---

# 27. Caso store validado

Durante el test aislado se verificó:

`sw x5,8(x3)`

con:

`x3 = 64`

`immediate = 8`

`x5 viejo = 1`

`x5 nuevo forwarded = 85`

Resultado:

`ALU result = 72`

`store_data = 85`

Esto demuestra que:

- la ALU utiliza correctamente el inmediato para la dirección;
- el dato del store puede ser corregido independientemente.

---

# 28. Integración en pipeline_core

Se agregó la instancia:

`forwarding_unit_inst`

La Forwarding Unit compara:

`ID/EX.rs1`

`ID/EX.rs2`

contra:

`EX/MEM.rd`

`MEM/WB.rd`

y genera:

`forward_a`

`forward_b`

Estas señales se entregan directamente a `ex_stage`.

---

# 29. Test end-to-end sin NOPs

Archivo:

`tb/pipeline_core_forwarding_tb.sv`

Programa utilizado:

`addi x1,x0,10`

`addi x2,x0,20`

`add x5,x1,x2`

`sub x6,x5,x2`

`xor x7,x6,x5`

`sw x7,0(x0)`

No se agregaron NOPs entre las instrucciones dependientes.

---

# 30. Resultados end-to-end

Los valores finales fueron:

`x1 = 10`

`x2 = 20`

`x5 = 30`

`x6 = 10`

`x7 = 20`

`DMEM[0] = 20`

También se verificó explícitamente que durante la ejecución ocurrieron:

- forwarding EX/MEM;
- forwarding MEM/WB;
- forwarding mixto;
- forwarding de store data.

Resultado:

`Tests run: 10`

`Tests passed: 10`

`Tests failed: 0`

`PASS: pipeline_core_forwarding`

---

# 31. Forwarding mixto

Un caso especialmente importante fue:

`addi x1,x0,10`

`addi x2,x0,20`

`add x5,x1,x2`

Cuando `add` se encontraba en EX:

un operando provenía de MEM/WB y el otro de EX/MEM.

Conceptualmente:

`ForwardA = 01`

`ForwardB = 10`

La ALU recibió:

`A = 10`

`B = 20`

y produjo:

`30`

Esto demuestra que los dos caminos de forwarding funcionan independientemente en el mismo ciclo.

---

# 32. Regresión del pipeline general

Después de integrar forwarding se volvió a ejecutar:

`tb/pipeline_core_tb.sv`

Se mantuvo el estado de pipeline completo:

- IF -> I5
- ID -> I4
- EX -> I3
- MEM -> I2
- WB -> I1

Resultados finales:

`x5 = 0000000A`

`x6 = 00000014`

`x7 = 12345000`

`x8 = 00000000`

`x9 = FFFFFFFD`

Resultado:

`PASS: pipeline_core`

---

# 33. Regresión del pipeline de memoria

También se volvió a ejecutar:

`tb/pipeline_core_memory_tb.sv`

Resultados:

`x1 = 00000040`

`x2 = 00000055`

`x3 = 00000055`

`DMEM[64] = 00000055`

Resultado:

`PASS: pipeline_core_memory`

Esto confirma que la incorporación de forwarding no rompió el comportamiento previamente validado de loads y stores.

---

# 34. Archivos agregados

Se agregaron:

`rtl/forwarding_unit.sv`

`tb/forwarding_unit_tb.sv`

`tb/ex_forwarding_pipeline_tb.sv`

`tb/pipeline_core_forwarding_tb.sv`

`docs/forwarding.md`

---

# 35. Archivos modificados

Se modificaron:

`rtl/ex_stage.sv`

`rtl/pipeline_core.sv`

---

# 36. Limitaciones actuales

El mecanismo implementado todavía no resuelve:

- load-use inmediato;
- stalls;
- inserción automática de burbujas;
- branch redirects;
- flushes por branch/jump;
- HALT;
- drenaje del pipeline.

Estas funcionalidades corresponden a pasos posteriores.

---

# 37. Resultado del Paso 13

Se implementó forwarding para dependencias RAW cuyo dato está disponible a tiempo.

La implementación permite reenviar valores desde:

`EX/MEM -> EX`

y:

`MEM/WB -> EX`

con prioridad:

`EX/MEM > MEM/WB`

También se implementó forwarding específico para:

- operandos A;
- operandos B;
- store data;
- bases de dirección;
- operands de branch;
- JALR.

Las pruebas aisladas, end-to-end y las regresiones finalizaron correctamente.

Estado:

`Paso 13 — Forwarding: VALIDADO`

El próximo paso será:

`Paso 14 — Load-use hazard, stalls y burbujas`
