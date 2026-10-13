# Etapa WB — Write Back

## 1. Objetivo

La etapa WB (Write Back) constituye la última etapa del pipeline del procesador
RISC-V segmentado.

Su función consiste en determinar si la instrucción que llegó desde MEM/WB debe
modificar el banco de registros y, en caso afirmativo:

- seleccionar el dato correcto;
- seleccionar el registro destino;
- generar la habilitación de escritura.

WB no realiza operaciones aritméticas generales ni accesos a memoria de datos.

Las operaciones necesarias para producir el resultado de una instrucción ya
fueron realizadas previamente en EX y MEM.

---

## 2. Entrada desde MEM/WB

La etapa recibe los campos:

- `mem_wb_pc`
- `mem_wb_alu_result`
- `mem_wb_load_data`
- `mem_wb_rd`
- `mem_wb_opcode`
- `mem_wb_valid`

Estos campos permiten determinar:

- qué valor debe escribirse;
- en qué registro debe escribirse;
- si la instrucción puede producir una escritura real.

---

## 3. Salida hacia Register File

WB genera:

- `wb_write_enable`
- `wb_write_register`
- `wb_write_data`

Estas señales se conectan al puerto de escritura del banco de registros.

El Register File realiza físicamente la escritura en el flanco de reloj.

Por lo tanto `wb_stage.sv` es un bloque combinacional y no necesita:

- `clk`;
- `reset`.

---

# Fuentes de Write Back

## 4. Resultado de ALU

Las instrucciones aritméticas, lógicas e inmediatas utilizan:

`mem_wb_alu_result`

como dato de write-back.

Esto incluye las instrucciones R-type implementadas:

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

y las operaciones I-type de ALU:

- `addi`
- `andi`
- `ori`
- `xori`
- `slti`
- `sltiu`
- `slli`
- `srli`
- `srai`

También se utiliza este camino para `lui`.

En el diseño actual, `lui` ya produce en EX el valor correspondiente mediante
la operación interna `ALU_PASS_B`.

---

## 5. Dato proveniente de memoria

Las instrucciones load utilizan:

`mem_wb_load_data`

como valor de write-back.

Esto incluye:

- `lb`
- `lh`
- `lw`
- `lbu`
- `lhu`

El valor ya fue previamente:

- leído desde DMEM;
- seleccionado como byte, halfword o word;
- extendido con signo o con ceros cuando corresponde.

Por ejemplo, para un `lw`:

`alu_result`

representa la dirección efectiva de memoria y no el dato que debe escribirse
en el registro.

El dato arquitectónico final se encuentra en:

`load_data`.

---

## 6. PC + 4

Las instrucciones:

- `jal`
- `jalr`

deben escribir en `rd` la dirección de retorno:

`PC + 4`

En el diseño actual el PC de la instrucción se conserva hasta MEM/WB.

Por lo tanto WB calcula:

`pc_plus_4 = mem_wb_pc + 4`

Este valor constituye la tercera fuente posible del multiplexor de write-back.

El cálculo del target real del salto y la actualización del PC pertenecen a la
lógica de control de saltos y no a WB.

---

# Selección del dato

## 7. Multiplexor de Write Back

Se definieron internamente tres opciones:

| wb_sel | Fuente |
|---|---|
| `00` | resultado ALU |
| `01` | dato de memoria |
| `10` | PC + 4 |

La selección depende del opcode de la instrucción.

---

## 8. Selección por tipo de instrucción

| Clase | Fuente | Escribe registro |
|---|---|---|
| R-type | ALU | Sí |
| I-ALU | ALU | Sí |
| Loads | MEM | Sí |
| LUI | ALU | Sí |
| JAL | PC+4 | Sí |
| JALR | PC+4 | Sí |
| Stores | - | No |
| Branches | - | No |

---

# Habilitación de escritura

## 9. Señal `writes_register`

Internamente WB determina primero si el opcode pertenece a una clase que posee
registro destino arquitectónico.

Para:

- R-type;
- I-ALU;
- LOAD;
- LUI;
- JAL;
- JALR;

se genera:

`writes_register = 1`

Para:

- STORE;
- BRANCH;
- opcode no soportado;

se genera:

`writes_register = 0`

---

## 10. Señal final `wb_write_enable`

La condición final implementada es:

`wb_write_enable = mem_wb_valid && writes_register && (mem_wb_rd != 0)`

Por lo tanto una escritura ocurre solamente cuando:

1. la entrada MEM/WB corresponde a una instrucción válida;
2. la clase de instrucción escribe un registro;
3. el registro destino no es `x0`.

---

## 11. Valid y burbujas

Una entrada con:

`mem_wb_valid = 0`

representa una burbuja.

Aunque los demás campos puedan contener valores que parezcan corresponder a
una instrucción válida, WB debe impedir cualquier efecto arquitectónico.

Por ello:

`mem_wb_valid = 0`

fuerza:

`wb_write_enable = 0`

---

## 12. Registro x0

RISC-V define `x0` como un registro cuyo valor arquitectónico siempre es cero.

En el Register File ya se ignoran escrituras sobre `x0`.

Sin embargo, WB también bloquea explícitamente la escritura cuando:

`mem_wb_rd = 0`

Esto evita generar una habilitación de escritura innecesaria.

Ejemplo:

`add x0,x5,x6`

puede producir un resultado en la ALU, pero:

`wb_write_enable = 0`

---

# Instrucciones sin Write Back

## 13. Stores

Las instrucciones:

- `sb`
- `sh`
- `sw`

no escriben el banco de registros.

Su efecto arquitectónico ya ocurrió durante MEM mediante la escritura en DMEM.

Cuando llegan a WB:

`wb_write_enable = 0`

---

## 14. Branches

Las instrucciones:

- `beq`
- `bne`

no poseen un registro destino arquitectónico.

Su efecto consiste en modificar el flujo de ejecución cuando se cumple la
condición correspondiente.

Por lo tanto:

`wb_write_enable = 0`

La lógica de branch y actualización del PC se implementará en una etapa
posterior.

---

# Jumps

## 15. JAL

Para una instrucción:

`jal x1, offset`

existen dos efectos diferentes:

- actualización del PC hacia el target del salto;
- escritura de `PC+4` en `x1`.

WB se ocupa únicamente del segundo efecto.

Ejemplo:

`PC = 400`

produce:

`x1 = 404`

---

## 16. JALR

El mismo principio se aplica a `jalr`.

El cálculo del target del salto utiliza el registro fuente y el inmediato.

Sin embargo, el valor escrito en `rd` es:

`PC + 4`

Ejemplo:

`PC = 1000`

produce:

`rd = 1004`

---

# Implementación

## 17. Módulo `wb_stage.sv`

Archivo:

`rtl/wb_stage.sv`

El módulo es completamente combinacional.

No posee reloj ni reset.

Las principales funciones internas son:

- cálculo de `PC+4`;
- decodificación de la clase de instrucción;
- generación de `writes_register`;
- generación de `wb_sel`;
- multiplexado del dato;
- bloqueo de `x0`;
- bloqueo de burbujas.

---

## 18. Opcodes utilizados

La lógica reconoce:

- R-type: `0110011`
- I-ALU: `0010011`
- LOAD: `0000011`
- STORE: `0100011`
- BRANCH: `1100011`
- LUI: `0110111`
- JAL: `1101111`
- JALR: `1100111`

Cualquier opcode no soportado produce:

`writes_register = 0`

y por lo tanto no modifica el Register File.

---

# Validación de WB

## 19. Testbench unitario

Archivo:

`tb/wb_stage_tb.sv`

Se verificaron los siguientes casos:

- R-type;
- I-ALU;
- LUI;
- LOAD;
- JAL;
- JALR;
- STORE;
- BRANCH;
- burbuja;
- destino `x0`;
- JAL con `rd=x0`;
- opcode inválido.

Resultado:

`PASS: wb_stage`

---

## 20. Resultado ALU

Para una instrucción R-type con:

`alu_result = 42`

y:

`rd = x7`

WB produjo:

`wb_write_enable = 1`

`wb_write_register = 7`

`wb_write_data = 42`

---

## 21. Resultado de LOAD

Se simuló una instrucción load con:

`alu_result = 0x20`

`load_data = 0x80A53344`

WB seleccionó correctamente:

`wb_write_data = 0x80A53344`

demostrando que la dirección efectiva no se utiliza como dato de write-back.

---

## 22. JAL y JALR

Para JAL:

`PC = 400`

se obtuvo:

`wb_write_data = 404`

Para JALR:

`PC = 1000`

se obtuvo:

`wb_write_data = 1004`

---

## 23. Casos sin escritura

Las simulaciones confirmaron:

- STORE -> `write_enable = 0`
- BRANCH -> `write_enable = 0`
- burbuja -> `write_enable = 0`
- `rd=x0` -> `write_enable = 0`
- opcode inválido -> `write_enable = 0`

---

# Integración con Register File

## 24. Testbench integrado

Archivo:

`tb/wb_register_file_integration_tb.sv`

Se conectó directamente:

`wb_stage`

con:

`register_file`

De esta forma se comprobó que las señales producidas por WB generan
modificaciones reales sobre el estado arquitectónico del banco de registros.

---

## 25. Escrituras verificadas

Se obtuvieron los siguientes resultados:

| Instrucción simulada | Resultado |
|---|---|
| R-type | `x7 = 0x0000002A` |
| I-ALU | `x8 = 0x12345678` |
| LOAD | `x5 = 0x80A53344` |
| LUI | `x9 = 0x12345000` |
| JAL | `x1 = 0x00000194` |
| JALR | `x2 = 0x000003EC` |

---

## 26. Escrituras bloqueadas

También se comprobó que permanecieran sin modificación:

- `x12` durante STORE;
- `x13` durante BRANCH;
- `x10` durante una burbuja;
- `x20` con opcode inválido;
- `x0` ante un intento de escritura.

---

## 27. Persistencia

Finalmente se volvió a leer:

`x7`

después de ejecutar el resto de las pruebas.

El registro conservó:

`0x0000002A`

confirmando que las operaciones posteriores que no debían escribirlo no
alteraron su contenido.

Resultado:

`PASS: wb_register_file_integration`

---

# Pipeline

## 28. Ausencia de registro posterior

WB es la etapa final del pipeline.

No se implementa un registro posterior del tipo:

`WB/...`

porque el resultado final ya se almacena directamente en el Register File,
que constituye estado arquitectónico del procesador.

El camino final queda:

`MEM/WB -> WB -> Register File`

---

# Decisiones temporales

## 29. Decodificación local por opcode

En la implementación actual WB deriva:

- `writes_register`;
- selección de fuente de write-back;

directamente desde el opcode.

Esta es una decisión temporal mientras todavía no se implementó la unidad de
control central.

Posteriormente podrá reemplazarse por señales de control pipelineadas tales como:

- `RegWrite`;
- `WBSel`.

---

## 30. PC+4 calculado en WB

Actualmente:

`PC+4`

se calcula dentro de WB utilizando:

`mem_wb_pc`

Esto es posible porque el PC de la instrucción se conserva durante el pipeline.

No es necesario agregar todavía un campo separado `pc_plus_4` a todos los
registros intermedios.

La decisión podrá revisarse durante la integración de jumps y control.

---

# Funcionalidades diferidas

## 31. Pendientes

La etapa WB base no implementa todavía:

- unidad de control central;
- forwarding;
- detección de hazards;
- resolución completa de branches;
- redirect completo de JAL;
- redirect completo de JALR;
- flush de instrucciones posteriores por salto;
- integración completa IF/ID/EX/MEM/WB.

Particularmente, aunque WB ya implementa correctamente el valor de link
`PC+4` para JAL/JALR, el mecanismo completo del salto todavía se resolverá
en una etapa posterior.

---

# Archivos implementados

## 32. RTL

- `rtl/wb_stage.sv`

## 33. Testbenches

- `tb/wb_stage_tb.sv`
- `tb/wb_register_file_integration_tb.sv`

Se reutiliza además:

- `rtl/register_file.sv`

implementado y validado previamente durante ID.

---

# Resultados

## 34. Simulaciones

Resultados obtenidos:

`PASS: wb_stage`

`PASS: wb_register_file_integration`

La integración confirmó escrituras reales en los registros correspondientes y
el bloqueo correcto de instrucciones que no deben modificar el Register File.

---

## 35. Estado

La etapa WB base queda implementada y validada mediante:

- test unitario;
- waveform;
- integración con Register File;
- comprobación del estado arquitectónico.

Estado final:

`Paso 9 — WB: VALIDADO`
