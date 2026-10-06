# Etapa EX — Execute

## 1. Objetivo

La etapa EX recibe la información preparada previamente por la etapa ID y realiza
la operación correspondiente a la instrucción.

Sus principales responsabilidades son:

- ejecutar operaciones aritméticas;
- ejecutar operaciones lógicas;
- realizar desplazamientos;
- realizar comparaciones signed y unsigned;
- calcular direcciones efectivas para instrucciones load/store;
- preparar cálculos asociados a saltos;
- entregar los resultados a la siguiente etapa mediante el registro EX/MEM.

La etapa EX recibe sus datos desde el registro ID/EX.

---

## 2. Separación entre selección de operandos y operación ALU

Dentro de EX existen dos decisiones independientes:

1. qué valores entran a la ALU;
2. qué operación realiza la ALU.

La selección de operandos se realiza mediante señales de control:

- `alu_src_a`
- `alu_src_b`

Convención utilizada:

### alu_src_a

- `0`: `read_data1`
- `1`: `PC`

### alu_src_b

- `0`: `read_data2`
- `1`: `immediate`

Por ejemplo:

### ADD

- operand A = rs1
- operand B = rs2
- operación = ADD

### ADDI

- operand A = rs1
- operand B = immediate
- operación = ADD

Por lo tanto, `add` y `addi` utilizan la misma operación interna de ALU.
Lo que cambia es el origen del segundo operando.

---

## 3. ALU

Archivo:

`rtl/alu.sv`

La ALU es un módulo completamente combinacional.

Entradas:

- `operand_a[31:0]`
- `operand_b[31:0]`
- `alu_operation[3:0]`

Salidas:

- `result[31:0]`
- `zero`

No utiliza reloj ni reset porque no almacena estado.

---

## 4. Operaciones internas de la ALU

Se definió la siguiente codificación interna:

| Código | Operación |
|---|---|
| 0000 | ALU_ADD |
| 0001 | ALU_SUB |
| 0010 | ALU_AND |
| 0011 | ALU_OR |
| 0100 | ALU_XOR |
| 0101 | ALU_SLL |
| 0110 | ALU_SRL |
| 0111 | ALU_SRA |
| 1000 | ALU_SLT |
| 1001 | ALU_SLTU |
| 1010 | ALU_PASS_B |
| 1111 | ALU_INVALID |

Las restantes combinaciones quedan reservadas.

---

## 5. Operaciones aritméticas

### ADD

Calcula:

`result = operand_a + operand_b`

Se utiliza para:

- `add`
- `addi`
- cálculo de dirección de loads;
- cálculo de dirección de stores;
- `jal`;
- `jalr`.

### SUB

Calcula:

`result = operand_a - operand_b`

Se utiliza para:

- `sub`;
- comparación de igualdad para `beq` y `bne`.

---

## 6. Operaciones lógicas

La ALU implementa:

- AND
- OR
- XOR

Estas operaciones trabajan bit a bit sobre los 32 bits de los operandos.

---

## 7. Desplazamientos

Se implementan:

- SLL
- SRL
- SRA

La cantidad de desplazamiento utiliza solamente:

`operand_b[4:0]`

Esto permite representar desplazamientos entre 0 y 31 bits.

### SRL

Realiza desplazamiento lógico hacia la derecha y completa los bits superiores
con ceros.

### SRA

Realiza desplazamiento aritmético hacia la derecha y conserva el signo.

En SystemVerilog se utiliza interpretación signed para el primer operando.

---

## 8. Comparaciones

### SLT

Realiza una comparación signed.

Si:

`operand_a < operand_b`

el resultado es:

`0x00000001`

En caso contrario:

`0x00000000`

### SLTU

Realiza la misma comparación interpretando ambos operandos como unsigned.

Los bits de entrada pueden ser exactamente los mismos, pero su interpretación
es diferente.

---

## 9. Señal zero

La ALU genera:

`zero = 1`

cuando:

`result == 0`

Esta señal será útil posteriormente para el control de branches.

---

## 10. ALU_PASS_B y LUI

Para `lui`, el Immediate Generator reconstruye previamente el inmediato de
formato U.

Ejemplo:

`lui x5,0x12345`

produce en ID:

`immediate = 0x12345000`

EX selecciona este inmediato como operand B y utiliza:

`ALU_PASS_B`

Por lo tanto:

`result = operand_b`

y el resultado es:

`0x12345000`

ImmGen solamente reconstruye el operando inmediato.
La ejecución continúa realizándose en EX.

---

## 11. ALU Control

Archivo:

`rtl/alu_control.sv`

El módulo ALU Control es combinacional.

Entradas:

- `opcode[6:0]`
- `funct3[2:0]`
- `funct7[6:0]`

Salida:

- `alu_operation[3:0]`

Su responsabilidad es exclusivamente determinar qué operación debe realizar
la ALU.

No selecciona operandos ni implementa el control general del procesador.

---

## 12. Decodificación de instrucciones

### Operaciones registro-registro

Se utilizan `opcode`, `funct3` y, cuando es necesario, `funct7` para distinguir:

- add
- sub
- sll
- srl
- sra
- and
- or
- xor
- slt
- sltu

### Operaciones inmediatas

Se reconocen:

- addi
- andi
- ori
- xori
- slti
- sltiu
- slli
- srli
- srai

### Loads

Las siguientes instrucciones utilizan ALU_ADD para calcular la dirección:

- lb
- lh
- lw
- lbu
- lhu

### Stores

Las siguientes instrucciones utilizan ALU_ADD para calcular la dirección:

- sb
- sh
- sw

### Branches

`beq` y `bne` utilizan ALU_SUB para comparar los registros.

### LUI

Utiliza ALU_PASS_B.

### JAL y JALR

Utilizan ALU_ADD para el cálculo inicial del destino.

La implementación completa de redirect, flush y escritura de PC+4 será agregada
en etapas posteriores.

---

## 13. Cálculo de direcciones

Para loads y stores se calcula:

`dirección efectiva = rs1 + immediate`

Ejemplo:

`sw x5,12(x6)`

si:

- x6 = 1000
- x5 = 777

EX calcula:

`alu_result = 1000 + 12 = 1012`

Al mismo tiempo se conserva:

`store_data = 777`

Por lo tanto MEM podrá posteriormente ejecutar:

`DMEM[1012] = 777`

---

## 14. Registro EX/MEM

Archivo:

`rtl/ex_mem_register.sv`

El registro EX/MEM conserva la información que las etapas posteriores todavía
necesitan.

Campos almacenados:

- `pc`
- `alu_result`
- `store_data`
- `rd`
- `opcode`
- `funct3`
- `valid`

No se conserva `funct7` porque su función ya fue utilizada durante EX para
determinar la operación correspondiente.

---

## 15. Política de control de EX/MEM

La prioridad utilizada es:

`reset > flush > enable > hold`

### Reset

Limpia todos los campos y coloca:

`valid = 0`

### Flush

Coloca solamente:

`valid = 0`

Los demás datos pueden conservarse porque una entrada con `valid=0` se
considera una burbuja.

### Enable

Captura los nuevos valores provenientes de EX.

### Hold

Con `enable=0`, los valores almacenados permanecen sin cambios.

---

## 16. ex_stage

Archivo:

`rtl/ex_stage.sv`

Este módulo integra:

- selección de operand A;
- selección de operand B;
- ALU Control;
- ALU;
- registro EX/MEM.

Flujo conceptual:

ID/EX → selección de operandos → ALU Control / ALU → EX/MEM

Las señales `alu_src_a` y `alu_src_b` se reciben actualmente como entradas.

El control general encargado de producir estas señales será implementado en
una etapa posterior del proyecto.

---

## 17. Store data

Una decisión importante del diseño es que:

`store_data_in = id_ex_read_data2`

y no `operand_b`.

Esto es necesario porque para una instrucción store:

`operand_b = immediate`

para calcular la dirección.

Sin embargo, el dato que debe llegar a MEM es el contenido original de rs2.

Ejemplo:

`sw x5,12(x6)`

- operand A = contenido de x6
- operand B = 12
- alu_result = dirección
- store_data = contenido de x5

---

## 18. Validación de alu.sv

Testbench:

`tb/alu_tb.sv`

Se validaron:

- ADD
- SUB
- generación de zero
- AND
- OR
- XOR
- SLL
- SRL
- SRA
- SLT signed
- SLTU unsigned
- PASS_B
- operación inválida

Resultado:

`PASS: alu`

También se verificó mediante waveform la diferencia entre SRL y SRA.

---

## 19. Validación de alu_control.sv

Testbench:

`tb/alu_control_tb.sv`

Se probaron las instrucciones requeridas correspondientes a:

- tipo R;
- operaciones inmediatas;
- loads;
- stores;
- branches;
- LUI;
- JAL;
- JALR.

También se probaron combinaciones inválidas.

Resultado:

`PASS: alu_control`

---

## 20. Validación de ex_mem_register.sv

Testbench:

`tb/ex_mem_register_tb.sv`

Se validaron:

- reset;
- captura;
- hold;
- flush;
- captura posterior a flush;
- prioridad de reset.

Resultado:

`PASS: ex_mem_register`

La waveform confirmó que durante flush únicamente `valid` pasa a cero,
mientras los demás campos permanecen almacenados.

---

## 21. Validación integrada de EX

Testbench:

`tb/ex_stage_tb.sv`

Se validaron de forma integrada:

- ADD
- SUB
- ADDI con inmediato negativo
- XOR
- SLL
- SRA
- SLT signed
- SLTU unsigned
- cálculo de dirección de LW
- cálculo de dirección y store_data de SW
- LUI
- cálculo preliminar de target de JAL
- hold
- flush

Resultado final:

`PASS: ex_stage`

---

## 22. Casos representativos

### ADD

25 + 17:

`alu_result = 42`

### ADDI negativo

100 + (-20):

`alu_result = 80`

### SRA

`0xFFFFFFF0 >>> 2`

resultado:

`0xFFFFFFFC`

### SLT

-5 < 3 signed:

`result = 1`

### SLTU

4294967291 < 3 unsigned:

`result = 0`

### LW

base = 100

offset = 12

dirección:

`112`

### SW

base = 1000

offset = 12

dato = 777

resultado:

- dirección = 1012
- store_data = 777

### LUI

immediate:

`0x12345000`

resultado:

`0x12345000`

### JAL

PC = 400

immediate = 20

cálculo preliminar:

`target = 420`

La lógica completa de salto se implementará posteriormente.

---

## 23. Funcionalidades diferidas

Esta implementación de EX todavía no incluye:

- forwarding;
- detección de hazards;
- stalls por dependencias;
- resolución completa de branches;
- redirect completo del PC;
- flush provocado por branch/jump;
- escritura de PC+4 para JAL/JALR;
- control general del datapath.

Estas funcionalidades se incorporarán en pasos posteriores.

---

## 24. Estado

La etapa EX base queda implementada y validada mediante simulaciones unitarias
e integradas en Vivado/XSim.

Estado:

`Paso 7 — EX: VALIDADO`
