# Paso 15 — Branches, jumps y control hazards

## 1. Objetivo

El objetivo de este paso fue incorporar al procesador RISC-V segmentado el tratamiento de instrucciones que modifican el flujo de ejecución.

Se implementaron:

- `beq`;
- `bne`;
- `jal`;
- `jalr`;
- selección del próximo PC;
- resolución de branches y jumps en EX;
- generación de `redirect_valid`;
- generación de `redirect_target`;
- eliminación mediante `flush` de instrucciones pertenecientes al camino incorrecto;
- interacción con forwarding;
- interacción con stalls `load-use`;
- escritura de `PC+4` en `rd` para `jal` y `jalr`.

Con esto el procesador deja de asumir que la ejecución siempre continúa secuencialmente mediante `PC+4`.

---

# 2. Control hazards

En condiciones normales IF busca instrucciones utilizando:

```text
next_pc = pc + 4
```

Sin embargo, una instrucción de branch o jump puede cambiar ese flujo.

Ejemplo:

```asm
beq x1, x2, TARGET
add x3, x4, x5
sub x6, x7, x8
```

Mientras el `beq` avanza por el pipeline, IF continúa buscando instrucciones secuenciales.

Si posteriormente el branch resulta tomado, las instrucciones `add` y `sub` que ya ingresaron al pipeline pertenecen al camino incorrecto.

Este problema se denomina:

```text
control hazard
```

La solución implementada consiste en:

```text
1. determinar el destino correcto;
2. redirigir el PC;
3. eliminar las instrucciones jóvenes incorrectas mediante flush.
```

---

# 3. Política utilizada

Para branches condicionales se continúa inicialmente por el camino secuencial:

```text
PC + 4
```

Conceptualmente esto equivale a asumir:

```text
branch not taken
```

Si el branch finalmente no se toma, no es necesario realizar ninguna acción especial.

Si resulta tomado:

```text
redirect_valid = 1
```

y las instrucciones jóvenes que ya ingresaron por el camino secuencial deben eliminarse.

---

# 4. Resolución en EX

Las instrucciones de control se resuelven en la etapa EX.

Esto permite utilizar los operandos ya corregidos por forwarding:

```text
forwarded_rs1
forwarded_rs2
```

Por lo tanto un branch puede comparar valores producidos por instrucciones anteriores sin esperar necesariamente a que esos valores sean escritos en el Register File.

Además, la resolución en EX limita la cantidad de instrucciones jóvenes que deben descartarse.

Cuando una instrucción de control se encuentra en EX:

```text
EX -> branch/jump
ID -> instrucción joven
IF -> instrucción joven
```

Si hay redirect, las instrucciones presentes en ID e IF deben eliminarse.

---

# 5. Señales de redirect

Se incorporaron dos señales principales:

```text
redirect_valid
redirect_target
```

`redirect_valid` indica que el flujo secuencial debe abandonarse.

`redirect_target` contiene la nueva dirección que debe cargarse en el PC.

Conceptualmente:

```text
if redirect_valid:
    next_pc = redirect_target
else:
    next_pc = pc + 4
```

---

# 6. BEQ

La instrucción:

```asm
beq rs1, rs2, imm
```

tiene la semántica:

```text
si rs1 == rs2:
    PC = PC_branch + imm
si no:
    continuar secuencialmente
```

El destino se calcula utilizando el PC perteneciente a la propia instrucción almacenado en ID/EX:

```text
branch_target =
    id_ex_pc + id_ex_immediate
```

No se utiliza el PC actual de IF, porque cuando el branch llega a EX el front-end ya avanzó varias instrucciones.

---

# 7. BNE

La instrucción:

```asm
bne rs1, rs2, imm
```

realiza:

```text
si rs1 != rs2:
    PC = PC_branch + imm
si no:
    continuar secuencialmente
```

Para `beq` y `bne`, la Control Unit ya había configurado la ALU para realizar:

```text
rs1 - rs2
```

La señal:

```text
alu_zero
```

indica entonces igualdad.

La política implementada es:

```text
BEQ:
    redirect si alu_zero = 1

BNE:
    redirect si alu_zero = 0
```

siempre que:

```text
id_ex_valid = 1
id_ex_branch = 1
```

---

# 8. Branch no tomado

Si un branch resulta no tomado:

```text
redirect_valid = 0
```

No se realiza flush.

Esto es correcto porque las instrucciones que IF e ID buscaron mediante `PC+4` pertenecen justamente al camino que debe continuar ejecutándose.

Ejemplo:

```asm
bne x1, x2, TARGET
```

con:

```text
x1 == x2
```

El branch no se toma y la siguiente instrucción secuencial continúa normalmente.

---

# 9. JAL

La instrucción:

```asm
jal rd, imm
```

realiza simultáneamente dos operaciones:

```text
rd = PC_jal + 4
PC = PC_jal + imm
```

Es importante distinguir estos dos valores.

`rd` no contiene el destino del salto.

`rd` contiene:

```text
PC + 4
```

que representa la dirección de retorno.

El destino se obtiene mediante:

```text
redirect_target =
    id_ex_pc + id_ex_immediate
```

Como `jal` es un salto incondicional:

```text
redirect_valid = 1
```

siempre que la instrucción sea válida.

---

# 10. JAL y rd = x0

Una instrucción:

```asm
jal x0, TARGET
```

realiza el salto normalmente.

Sin embargo, la dirección de retorno no produce una modificación arquitectónica porque:

```text
x0 = 0
```

permanentemente.

Esto permite utilizar `jal x0,...` como salto incondicional sin conservar un link útil.

---

# 11. JALR

La instrucción:

```asm
jalr rd, imm(rs1)
```

realiza:

```text
rd = PC_jalr + 4
target_raw = rs1 + imm
PC = target_raw con bit 0 forzado a 0
```

La base del target es diferente de `jal`.

Para `jal`:

```text
base = PC
```

Para `jalr`:

```text
base = rs1
```

Además `rs1` utiliza su valor después del forwarding:

```text
forwarded_rs1
```

Por lo tanto:

```text
jalr_target_raw =
    forwarded_rs1 + id_ex_immediate
```

y finalmente:

```text
redirect_target[31:1] =
    jalr_target_raw[31:1]

redirect_target[0] = 0
```

---

# 12. Limpieza del bit 0 en JALR

RISC-V define el destino efectivo de `jalr` limpiando el bit menos significativo del resultado.

Ejemplo:

```text
rs1 + immediate = 89
```

en binario el bit menos significativo es 1.

El target real pasa a ser:

```text
88
```

La implementación genera:

```text
redirect_target = {
    control_target_sum[31:1],
    1'b0
}
```

Esto fue validado explícitamente en simulación.

---

# 13. Cálculo del target

En `rtl/ex_stage.sv` se incorporó lógica combinacional para seleccionar la base.

Conceptualmente:

```text
si JALR:
    base = forwarded_rs1
si no:
    base = id_ex_pc
```

Luego:

```text
control_target_sum =
    base + id_ex_immediate
```

Esto permite reutilizar la misma suma para:

```text
BEQ
BNE
JAL
JALR
```

cambiando únicamente la base.

---

# 14. Separación entre comparación y cálculo de target

Para un branch se necesitan dos operaciones conceptualmente diferentes.

Ejemplo:

```asm
beq x5, x6, TARGET
```

Primero debe determinarse:

```text
x5 == x6
```

Además debe calcularse:

```text
PC + immediate
```

La comparación se obtiene mediante la ALU utilizando:

```text
forwarded_rs1 - forwarded_rs2
```

mientras que el target se calcula mediante lógica combinacional independiente:

```text
id_ex_pc + id_ex_immediate
```

De esta manera no se obliga a la misma operación de ALU a realizar simultáneamente ambas funciones.

---

# 15. Flush

Un `flush` significa:

```text
descartar una instrucción que ya ingresó al pipeline
```

La instrucción pasa a representar una burbuja:

```text
valid = 0
```

y sus controles con efectos arquitectónicos quedan neutralizados.

Esto es diferente de un stall.

---

# 16. Diferencia entre stall y flush

Un stall significa:

```text
la instrucción es correcta,
pero todavía no puede avanzar.
```

Un flush significa:

```text
la instrucción ya no debe ejecutarse.
```

En un load-use:

```text
PC      HOLD
IF/ID   HOLD
ID/EX   BUBBLE
```

En un redirect:

```text
PC      TARGET
IF/ID   BUBBLE
ID/EX   BUBBLE
```

Por lo tanto ambos mecanismos pueden insertar burbujas, pero por razones completamente diferentes.

---

# 17. Flush generado por redirect

Cuando:

```text
redirect_valid = 1
```

el core genera:

```text
flush_if_id = 1
flush_id_ex = 1
```

De esta manera se eliminan las dos instrucciones jóvenes que pudieron haber ingresado por el camino secuencial incorrecto.

---

# 18. Por qué EX/MEM no se flushea

Durante un redirect, la instrucción que está actualmente en EX es justamente la instrucción de control que tomó la decisión.

Por lo tanto:

```text
flush_ex_mem = 0
```

La instrucción debe continuar avanzando.

Esto es especialmente importante para:

```text
jal
jalr
```

porque todavía deben llegar a WB para escribir:

```text
rd = PC + 4
```

Si EX/MEM fuese flusheado, la propia instrucción de jump sería destruida antes de completar su efecto arquitectónico.

---

# 19. Instrucciones jóvenes y antiguas

Cuando una instrucción en EX genera un redirect pueden distinguirse tres grupos.

```text
MEM/WB
    instrucciones más antiguas
    -> continúan

EX
    instrucción branch/jump
    -> continúa

ID/IF
    instrucciones más jóvenes
    -> flush
```

Solamente se eliminan instrucciones posteriores a la instrucción que modifica el flujo.

---

# 20. Selección del próximo PC

`rtl/if_stage.sv` ya había sido preparado previamente para soportar redirects.

La lógica existente es:

```text
si redirect_valid:
    next_pc = redirect_pc
si no:
    next_pc = pc + 4
```

Además:

```text
pc_enable =
    if_enable | redirect_valid
```

Esto establece una propiedad importante:

```text
redirect tiene prioridad sobre un hold normal
```

Una redirección del PC no puede quedar bloqueada por un stall de una instrucción joven.

---

# 21. Interacción entre redirect y load-use

El control de ID/EX quedó definido como:

```text
flush_id_ex =
    load_use_stall
    OR
    redirect_valid
```

Esto permite generar una burbuja por dos motivos diferentes.

Caso load-use:

```text
la instrucción debe esperar
```

Caso redirect:

```text
la instrucción debe descartarse
```

La misma entrada de `flush` del registro ID/EX sirve para ambos mecanismos.

---

# 22. Forwarding hacia branches

Ejemplo:

```asm
add x5, x1, x2
beq x5, x6, TARGET
```

Cuando el `beq` llega a EX, el nuevo valor de `x5` todavía puede encontrarse en EX/MEM.

La Forwarding Unit detecta:

```text
EX/MEM.rd == ID/EX.rs1
```

y selecciona:

```text
ForwardA = EX/MEM
```

Por lo tanto el branch compara el valor actualizado.

No es necesario insertar un stall.

---

# 23. Forwarding hacia JALR

También puede existir:

```asm
addi x5, x0, TARGET
jalr x1, 0(x5)
```

`jalr` necesita `x5` en EX para calcular su destino.

Si el valor fue producido inmediatamente antes por una instrucción ALU:

```text
EX/MEM -> EX forwarding
```

permite calcular correctamente el target sin stall.

---

# 24. Load seguido de branch

Ejemplo:

```asm
lw  x5, 0(x1)
beq x5, x6, TARGET
```

El branch necesita `x5` en EX.

Sin embargo el load obtiene el dato real recién durante MEM.

Por lo tanto forwarding EX/MEM no alcanza.

Se utiliza la Hazard Detection Unit ya implementada en el Paso 14.

El comportamiento es:

```text
1 stall
```

seguido por:

```text
MEM/WB -> EX forwarding
```

Entonces el branch puede realizar la comparación correcta.

---

# 25. Load seguido de JALR

El mismo problema aparece en:

```asm
lw   x5, 0(x1)
jalr x1, 0(x5)
```

`jalr` necesita el valor de `x5` en EX para generar el nuevo PC.

Por lo tanto:

```text
1 stall
```

y luego:

```text
MEM/WB -> EX forwarding
```

permiten calcular el destino correcto.

La Hazard Detection Unit ya clasificaba JALR como una instrucción que utiliza `rs1` en EX, por lo que no fue necesario modificarla en este paso.

---

# 26. Escritura de PC+4

La Control Unit ya generaba para `jal` y `jalr`:

```text
RegWrite = 1
WBSel = PC+4
```

En WB se calcula:

```text
mem_wb_pc + 4
```

y se escribe en `rd`.

Por lo tanto la lógica de redirect y la lógica de link son independientes:

```text
EX:
    modifica el flujo

WB:
    escribe PC+4
```

---

# 27. Archivos modificados

Para implementar los control hazards fue necesario modificar:

```text
rtl/ex_stage.sv
rtl/pipeline_core.sv
```

Además se agregó:

```text
tb/pipeline_core_control_hazards_tb.sv
```

No fue necesario modificar:

```text
rtl/if_stage.sv
rtl/program_counter.sv
rtl/if_id_register.sv
rtl/id_ex_register.sv
rtl/control_unit.sv
rtl/immediate_generator.sv
rtl/wb_stage.sv
rtl/hazard_detection_unit.sv
```

porque estas unidades ya habían sido diseñadas anticipando la integración posterior de control hazards.

---

# 28. Test integrado de control hazards

Se agregó:

```text
tb/pipeline_core_control_hazards_tb.sv
```

El test verificó de manera integrada:

- `beq` tomado;
- `bne` no tomado;
- `bne` tomado;
- `jal`;
- `jalr`;
- limpieza del bit 0 de `jalr`;
- generación del target correcto;
- escritura de `PC+4`;
- flush de IF/ID;
- flush de ID/EX;
- supervivencia de la instrucción de control en EX/MEM;
- eliminación de instrucciones del wrong path;
- forwarding ALU → branch;
- forwarding ALU → JALR;
- load-use → branch;
- load-use → JALR;
- forwarding MEM/WB posterior al stall.

Resultado:

```text
Tests run    : 31
Tests passed : 31
Tests failed : 0
Redirects    : 8
Stalls       : 2

PASS: pipeline_core_control_hazards
```

---

# 29. Validación de wrong path

Las instrucciones correspondientes al camino incorrecto fueron diseñadas para intentar modificar:

```text
x30
x31
```

Después de todos los redirects se verificó:

```text
x30 = 0
x31 = 0
```

Esto demuestra que las instrucciones jóvenes fueron correctamente invalidadas y no produjeron efectos arquitectónicos.

---

# 30. Validación de JAL

Para un `jal` ubicado en PC 52 se verificó:

```text
target = 64
```

y:

```text
rd = PC + 4 = 56
```

El salto se realizó correctamente y la propia instrucción sobrevivió hasta WB para guardar el link.

---

# 31. Validación de JALR

Se utilizó un valor impar:

```text
rs1 = 89
```

con inmediato cero.

El valor bruto era:

```text
89
```

pero el target real fue:

```text
88
```

demostrando que:

```text
target[0] = 0
```

se aplica correctamente.

También se comprobó la escritura de:

```text
PC + 4
```

en el registro destino.

---

# 32. Forwarding hacia branch

Se probó una dependencia:

```text
ALU -> BEQ
```

sin instrucciones intermedias.

El test observó explícitamente:

```text
ForwardA = EX/MEM
```

y el branch tomó la decisión utilizando el valor recién producido.

No se necesitó stall.

---

# 33. Forwarding hacia JALR

También se verificó:

```text
ALU -> JALR
```

La base del salto fue obtenida mediante forwarding desde EX/MEM.

El target fue calculado correctamente y no se generó un stall.

---

# 34. Load-use hacia branch

Se comprobó:

```text
LW -> BEQ
```

El pipeline generó exactamente un stall para esa dependencia.

Posteriormente el branch recibió el dato mediante:

```text
MEM/WB -> EX
```

y realizó el redirect correctamente.

---

# 35. Load-use hacia JALR

También se comprobó:

```text
LW -> JALR
```

El pipeline generó exactamente un stall.

Después:

```text
MEM/WB -> EX
```

entregó el valor cargado a JALR.

Se utilizó además un valor impar:

```text
193
```

y el destino final fue:

```text
192
```

validando simultáneamente load-use, forwarding y limpieza de `target[0]`.

---

# 36. Regresión de forwarding

Después de incorporar los control hazards se volvió a ejecutar:

```text
tb/pipeline_core_forwarding_tb.sv
```

Resultado:

```text
Tests run    : 10
Tests passed : 10
Tests failed : 0

PASS: pipeline_core_forwarding
```

---

# 37. Regresión de load-use

Se volvió a ejecutar:

```text
tb/pipeline_core_load_use_tb.sv
```

Resultado:

```text
Tests run    : 22
Tests passed : 22
Tests failed : 0
Stalls       : 4

PASS: pipeline_core_load_use
```

---

# 38. Regresión de store forwarding

Se volvió a ejecutar:

```text
tb/pipeline_core_store_forwarding_tb.sv
```

Resultado:

```text
Tests run    : 12
Tests passed : 12
Tests failed : 0
Stalls       : 1

PASS: pipeline_core_store_forwarding
```

---

# 39. Regresión del pipeline general

Se volvió a ejecutar:

```text
tb/pipeline_core_tb.sv
```

Se mantuvo el funcionamiento simultáneo de las cinco etapas:

```text
IF
ID
EX
MEM
WB
```

y el resultado fue:

```text
PASS: pipeline_core
```

---

# 40. Regresión del pipeline de memoria

También se ejecutó:

```text
tb/pipeline_core_memory_tb.sv
```

Los accesos de load/store y los valores finales permanecieron correctos.

Resultado:

```text
PASS: pipeline_core_memory
```

---

# 41. Estado final

Al finalizar este paso el procesador soporta:

```text
BEQ
BNE
JAL
JALR

PC + 4
PC-relative targets
JALR register-relative targets

redirect_valid
redirect_target

flush IF/ID
flush ID/EX

EX/MEM -> EX forwarding
MEM/WB -> EX forwarding

load-use stalls

branch forwarding
JALR forwarding
```

La política general queda:

```text
flujo normal:
    PC <- PC + 4

branch no tomado:
    continuar secuencialmente

branch tomado:
    PC <- PC + immediate
    flush instrucciones jóvenes

JAL:
    PC <- PC + immediate
    rd <- PC + 4
    flush instrucciones jóvenes

JALR:
    PC <- (rs1 + immediate) con bit 0 = 0
    rd <- PC + 4
    flush instrucciones jóvenes
```

Con esto quedan implementados y validados los hazards de control correspondientes a `beq`, `bne`, `jal` y `jalr`.
