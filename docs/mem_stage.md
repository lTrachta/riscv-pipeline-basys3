# Etapa MEM — Memory Access

## 1. Objetivo

La etapa MEM del procesador RISC-V segmentado se encarga principalmente del
acceso a la memoria de datos.

Esta etapa recibe la información almacenada previamente en el registro EX/MEM
y realiza una de tres acciones principales:

- leer información desde memoria para instrucciones load;
- escribir información en memoria para instrucciones store;
- dejar pasar resultados provenientes de la ALU para instrucciones que no
  necesitan acceder a memoria.

La salida de esta etapa se almacena en el registro MEM/WB para que posteriormente
la etapa WB pueda completar la instrucción.

---

## 2. Separación entre memoria de instrucciones y memoria de datos

El procesador utiliza dos conceptos de memoria diferentes:

- IMEM: memoria de instrucciones;
- DMEM: memoria de datos.

IMEM es utilizada durante la etapa IF y recibe como referencia la dirección
del PC.

DMEM es utilizada durante la etapa MEM y recibe como dirección el resultado
calculado previamente por la ALU en EX.

Para instrucciones load/store:

`address = ex_mem_alu_result`

Por ejemplo:

`lw x5,12(x6)`

EX calcula:

`x6 + 12`

y MEM utiliza ese resultado como dirección de DMEM.

---

## 3. Direccionamiento por bytes

La memoria utiliza direcciones de byte.

Una palabra contiene 32 bits:

`32 bits = 4 bytes`

Por lo tanto una dirección se interpreta conceptualmente como:

- bits superiores: selección de palabra;
- `address[1:0]`: posición dentro de la palabra.

En una memoria organizada en palabras de 32 bits:

`address[31:2]`

identifica conceptualmente la palabra correspondiente.

Los bits:

`address[1:0]`

permiten distinguir los cuatro bytes de esa palabra.

---

## 4. Little-endian

La organización utilizada es little-endian.

Para una palabra:

`0x11223344`

almacenada comenzando en la dirección 100:

| Dirección | Byte |
|---|---|
| 100 | 44 |
| 101 | 33 |
| 102 | 22 |
| 103 | 11 |

Por lo tanto:

- offset `00` selecciona el byte `44`;
- offset `01` selecciona el byte `33`;
- offset `10` selecciona el byte `22`;
- offset `11` selecciona el byte `11`.

---

## 5. Instrucciones de memoria implementadas

### Loads

Se contemplan:

- `lb`
- `lh`
- `lw`
- `lbu`
- `lhu`

### Stores

Se contemplan:

- `sb`
- `sh`
- `sw`

---

## 6. Política de alineación

Se decidió soportar accesos naturalmente alineados.

### Byte

Las instrucciones:

- `lb`
- `lbu`
- `sb`

pueden utilizar cualquier valor de:

`address[1:0]`

porque un byte puede comenzar en cualquier dirección.

### Halfword

Las instrucciones:

- `lh`
- `lhu`
- `sh`

requieren:

`address[0] = 0`

Por lo tanto los offsets válidos son:

- `00`
- `10`

Los offsets:

- `01`
- `11`

se consideran desalineados.

### Word

Las instrucciones:

- `lw`
- `sw`

requieren:

`address[1:0] = 00`

Cualquier otro offset se considera desalineado.

Los accesos desalineados no se implementan cruzando dos palabras de memoria.

Cuando se detecta uno:

- no se modifica DMEM;
- la instrucción se neutraliza antes de MEM/WB;
- `valid` pasa a cero.

No se implementa en esta etapa un mecanismo de excepción por acceso
desalineado.

---

# Data Memory

## 7. Módulo `data_memory.sv`

Archivo:

`rtl/data_memory.sv`

Este módulo representa el almacenamiento físico de datos.

No interpreta instrucciones.

No sabe si una operación corresponde a:

- `lb`;
- `lh`;
- `lw`;
- `sb`;
- `sh`;
- `sw`.

Solamente:

- lee palabras;
- escribe bytes habilitados.

---

## 8. Organización interna de DMEM

La memoria utiliza por defecto:

`DEPTH = 256`

Cada posición contiene:

`32 bits`

Por lo tanto:

`256 palabras × 4 bytes = 1024 bytes`

La implementación inicial dispone entonces de:

`1 KiB`

de memoria de datos.

El tamaño es parametrizable.

---

## 9. Interfaz de Data Memory

Entradas:

- `clk`
- `address[31:0]`
- `write_data[31:0]`
- `write_enable`
- `byte_enable[3:0]`

Salida:

- `read_data[31:0]`

---

## 10. Lectura de memoria

La lectura de DMEM es combinacional.

Al cambiar la dirección, la memoria entrega inmediatamente la palabra
correspondiente mediante:

`read_data`

DMEM siempre devuelve una palabra completa de 32 bits.

La extracción posterior de un byte o halfword se realiza fuera del módulo
mediante `load_unit.sv`.

---

## 11. Escritura de memoria

La escritura es secuencial.

La memoria solamente se modifica en:

`posedge clk`

si:

`write_enable = 1`

Los bytes modificados se determinan mediante:

`byte_enable[3:0]`

---

## 12. Byte Enable

Cada bit habilita un byte diferente:

| Byte Enable | Bits |
|---|---|
| `[0]` | `[7:0]` |
| `[1]` | `[15:8]` |
| `[2]` | `[23:16]` |
| `[3]` | `[31:24]` |

Ejemplos:

| byte_enable | Acción |
|---|---|
| `0000` | no escribe |
| `0001` | byte 0 |
| `0010` | byte 1 |
| `0100` | byte 2 |
| `1000` | byte 3 |
| `0011` | halfword inferior |
| `1100` | halfword superior |
| `1111` | palabra completa |

---

## 13. Verificación de rango

La memoria comprueba que la dirección se encuentre dentro del rango
implementado.

Con:

`DEPTH = 256`

existen:

`1024 bytes`

Por lo tanto las direcciones válidas son:

`0 ... 1023`

Una lectura fuera de rango produce:

`read_data = 0`

Una escritura fuera de rango se ignora.

---

## 14. Reset de DMEM

Data Memory no posee reset.

El reset del procesador no borra automáticamente el contenido de DMEM.

Esta decisión evita asociar accidentalmente el reset del pipeline con una
limpieza completa de memoria y permite definir más adelante una política
específica para la reprogramación dinámica del sistema.

---

# Store Unit

## 15. Módulo `store_unit.sv`

Archivo:

`rtl/store_unit.sv`

Este módulo prepara las señales necesarias para realizar stores.

Entradas:

- `funct3[2:0]`
- `address_offset[1:0]`
- `store_data[31:0]`

Salidas:

- `write_data[31:0]`
- `byte_enable[3:0]`
- `misaligned`

Es completamente combinacional.

---

## 16. Store Byte — SB

`funct3 = 000`

Siempre utiliza:

`store_data[7:0]`

Los cuatro offsets son válidos.

Ejemplo:

`store_data = 0x123456AA`

| Offset | write_data | byte_enable |
|---|---|---|
| `00` | `000000AA` | `0001` |
| `01` | `0000AA00` | `0010` |
| `10` | `00AA0000` | `0100` |
| `11` | `AA000000` | `1000` |

---

## 17. Store Halfword — SH

`funct3 = 001`

Utiliza:

`store_data[15:0]`

Para:

`store_data = 0x1234ABCD`

los casos válidos son:

### Offset 00

`write_data = 0000ABCD`

`byte_enable = 0011`

### Offset 10

`write_data = ABCD0000`

`byte_enable = 1100`

Offsets `01` y `11` producen:

`misaligned = 1`

`byte_enable = 0000`

---

## 18. Store Word — SW

`funct3 = 010`

Solo es válido:

`address_offset = 00`

En ese caso:

`write_data = store_data`

`byte_enable = 1111`

Para offsets:

- `01`
- `10`
- `11`

se genera:

`misaligned = 1`

y ningún byte queda habilitado.

---

# Load Unit

## 19. Módulo `load_unit.sv`

Archivo:

`rtl/load_unit.sv`

Este módulo recibe la palabra completa entregada por Data Memory y produce
el valor final de una instrucción load.

Entradas:

- `funct3[2:0]`
- `address_offset[1:0]`
- `read_data[31:0]`

Salidas:

- `load_data[31:0]`
- `misaligned`

Es un bloque combinacional.

---

## 20. Selección de byte

Según:

`address_offset`

se selecciona:

| Offset | Byte |
|---|---|
| `00` | `read_data[7:0]` |
| `01` | `read_data[15:8]` |
| `10` | `read_data[23:16]` |
| `11` | `read_data[31:24]` |

---

## 21. Load Byte — LB

`funct3 = 000`

Selecciona un byte y realiza extensión de signo hasta 32 bits.

Ejemplo:

`selected_byte = A5`

en binario comienza con 1.

Resultado:

`FFFFFFA5`

---

## 22. Load Byte Unsigned — LBU

`funct3 = 100`

Selecciona un byte y completa los bits superiores con ceros.

Ejemplo:

`selected_byte = A5`

Resultado:

`000000A5`

---

## 23. Load Halfword — LH

`funct3 = 001`

Selecciona 16 bits y realiza extensión de signo.

Para:

`read_data = 80A53344`

### Offset 00

halfword:

`3344`

resultado:

`00003344`

### Offset 10

halfword:

`80A5`

resultado:

`FFFF80A5`

---

## 24. Load Halfword Unsigned — LHU

`funct3 = 101`

Selecciona 16 bits y realiza extensión con ceros.

Por ejemplo:

`80A5`

produce:

`000080A5`

---

## 25. Load Word — LW

`funct3 = 010`

Cuando la dirección está alineada:

`load_data = read_data`

La palabra completa se utiliza directamente.

---

# MEM/WB

## 26. Registro `mem_wb_register.sv`

Archivo:

`rtl/mem_wb_register.sv`

Este registro separa temporalmente MEM de WB.

Almacena:

- `pc`
- `alu_result`
- `load_data`
- `rd`
- `opcode`
- `valid`

Se mantienen separados:

- resultado de ALU;
- dato leído de memoria.

La selección definitiva del dato que se escribirá en el banco de registros
será responsabilidad de WB.

---

## 27. Política de control de MEM/WB

La prioridad es:

`reset > flush > enable > hold`

### Reset

Limpia los campos y coloca:

`valid = 0`

### Flush

Coloca:

`valid = 0`

Los otros datos pueden permanecer almacenados.

### Enable

Captura los valores provenientes de MEM.

### Hold

Cuando:

`enable = 0`

el registro conserva su estado.

---

# MEM Stage

## 28. Módulo `mem_stage.sv`

Archivo:

`rtl/mem_stage.sv`

Este módulo integra:

- Store Unit;
- Data Memory;
- Load Unit;
- registro MEM/WB.

Recibe directamente los campos provenientes de EX/MEM.

---

## 29. Entradas desde EX/MEM

Se utilizan:

- `ex_mem_pc`
- `ex_mem_alu_result`
- `ex_mem_store_data`
- `ex_mem_rd`
- `ex_mem_opcode`
- `ex_mem_funct3`
- `ex_mem_valid`

Además recibe:

- `reset`
- `mem_enable`
- `flush_mem_wb`

---

## 30. Clasificación de instrucciones

MEM distingue principalmente dos opcodes:

### LOAD

`0000011`

### STORE

`0100011`

El resto de las instrucciones no accede a DMEM y puede avanzar hacia MEM/WB.

---

## 31. Validación de funct3

Para LOAD se consideran válidos:

| funct3 | Instrucción |
|---|---|
| `000` | lb |
| `001` | lh |
| `010` | lw |
| `100` | lbu |
| `101` | lhu |

Para STORE:

| funct3 | Instrucción |
|---|---|
| `000` | sb |
| `001` | sh |
| `010` | sw |

Una combinación no soportada se neutraliza.

---

## 32. Habilitación real de escritura de memoria

Un store puede modificar DMEM únicamente cuando se cumplen simultáneamente:

- `ex_mem_valid = 1`
- opcode corresponde a STORE;
- `mem_enable = 1`;
- `reset = 0`;
- `flush_mem_wb = 0`;
- `funct3` es válido;
- el acceso está alineado.

Esto evita efectos laterales durante:

- hold;
- flush;
- reset;
- burbujas;
- stores inválidos;
- stores desalineados.

---

## 33. Hold y stores

Cuando:

`mem_enable = 0`

MEM/WB conserva su contenido.

Además, los stores quedan bloqueados.

Por lo tanto una instrucción store presente en EX/MEM durante un hold no modifica
DMEM.

---

## 34. Flush y stores

Durante:

`flush_mem_wb = 1`

el registro MEM/WB genera una burbuja.

Además:

`memory_write_enable = 0`

de manera que un store presente durante el flush no modifica memoria.

---

## 35. Reset y memoria

Durante reset:

- MEM/WB se limpia;
- stores quedan bloqueados;
- DMEM conserva su contenido.

De esta manera reset no significa borrar la memoria de datos.

---

## 36. Loads desalineados

Un load desalineado produce:

`load_misaligned = 1`

y:

`mem_wb_valid = 0`

Por lo tanto no llegará a WB como una instrucción válida y no podrá escribir
accidentalmente cero en el registro destino.

---

## 37. Stores desalineados

Un store desalineado produce:

`store_misaligned = 1`

y:

`memory_write_enable = 0`

Además:

`mem_wb_valid = 0`

La memoria queda intacta.

---

## 38. Instrucciones que no utilizan memoria

Una instrucción ALU atraviesa MEM sin acceder a DMEM.

Por ejemplo:

`add x7,x3,x5`

puede llegar desde EX/MEM con:

`alu_result = 42`

MEM conserva:

`alu_result = 42`

y lo almacena en MEM/WB para que posteriormente WB pueda escribirlo en `x7`.

Para estas instrucciones:

`load_data = 0`

porque dicho campo no tiene significado.

---

# Validación

## 39. Test de Data Memory

Testbench:

`tb/data_memory_tb.sv`

Se verificó:

- escritura completa;
- lectura completa;
- escritura de byte 0;
- escritura de byte 1;
- escritura de byte 2;
- escritura de byte 3;
- halfword inferior;
- halfword superior;
- `write_enable = 0`;
- `byte_enable = 0000`;
- lecturas fuera de rango;
- escrituras fuera de rango.

Resultado:

`PASS: data_memory`

---

## 40. Test de Store Unit

Testbench:

`tb/store_unit_tb.sv`

Se verificó:

- SB en los cuatro offsets;
- SH inferior;
- SH superior;
- SH desalineados;
- SW alineado;
- SW desalineados;
- funct3 inválido.

Resultado:

`PASS: store_unit`

---

## 41. Test de Load Unit

Testbench:

`tb/load_unit_tb.sv`

Se verificó:

- LB en los cuatro bytes;
- LBU en los cuatro bytes;
- LH inferior y superior;
- LHU inferior y superior;
- LW;
- extensiones signed;
- extensiones unsigned;
- accesos desalineados;
- funct3 inválido.

Resultado:

`PASS: load_unit`

---

## 42. Integración Store + DMEM + Load

Testbench:

`tb/memory_access_integration_tb.sv`

Se comprobó un acceso real completo a memoria.

Primero:

`sw`

almacenó:

`80A53344`

Posteriormente se verificaron:

- `lw`
- `lb`
- `lbu`
- `lh`
- `lhu`

Luego:

`sb`

modificó la palabra:

`80A53344 -> 80A5EE44`

Posteriormente:

`sh`

produjo:

`80A5EE44 -> ABCDEE44`

También se verificó que un store desalineado no alterara memoria.

Resultado:

`PASS: memory_access_integration`

---

## 43. Test de MEM/WB

Testbench:

`tb/mem_wb_register_tb.sv`

Se verificó:

- reset;
- captura de load;
- hold;
- flush;
- captura posterior a flush;
- captura de burbuja;
- prioridad de reset.

Resultado:

`PASS: mem_wb_register`

---

## 44. Validación integrada de MEM

Testbench:

`tb/mem_stage_tb.sv`

Se verificó la etapa completa.

Casos probados:

- reset;
- SW;
- LW;
- LB signed;
- LBU;
- LH signed;
- LHU;
- SB;
- SH;
- passthrough de resultado ALU;
- hold;
- store bloqueado durante hold;
- flush;
- store bloqueado durante flush;
- SH desalineado;
- LW desalineado;
- funct3 inválido;
- store bloqueado durante reset;
- persistencia de DMEM luego de reset.

---

## 45. Evolución comprobada de la palabra almacenada

Durante la simulación integrada se observó:

`80A53344`

después de un SB:

`80A5EE44`

y posteriormente después de SH:

`ABCDEE44`

Los loads posteriores confirmaron el contenido correcto de memoria.

---

## 46. Resultados representativos

### LW

Resultado:

`80A53344`

### LB signed

Byte:

`A5`

Resultado:

`FFFFFFA5`

### LBU

Byte:

`A5`

Resultado:

`000000A5`

### LH signed

Halfword:

`80A5`

Resultado:

`FFFF80A5`

### LHU

Halfword:

`80A5`

Resultado:

`000080A5`

### Passthrough ALU

Resultado EX:

`42`

MEM/WB:

`alu_result = 42`

---

## 47. Protección de efectos laterales

La simulación confirmó que DMEM no se modifica durante:

- hold;
- flush;
- reset;
- store desalineado;
- store con funct3 inválido.

Esto es necesario porque una escritura en memoria modifica el estado
arquitectónico del sistema.

---

## 48. Funcionalidades diferidas

La implementación actual no incluye:

- soporte para accesos desalineados que crucen dos palabras;
- excepciones por acceso desalineado;
- selección definitiva del dato de Write Back;
- RegWrite;
- control general centralizado;
- forwarding;
- detección de hazards;
- memoria definitiva mediante IP de Vivado;
- interfaz de Debug Unit para inspeccionar DMEM.

Estas funcionalidades se implementarán o revisarán en etapas posteriores.

---

## 49. Archivos implementados

RTL:

- `rtl/data_memory.sv`
- `rtl/store_unit.sv`
- `rtl/load_unit.sv`
- `rtl/mem_wb_register.sv`
- `rtl/mem_stage.sv`

Testbenches:

- `tb/data_memory_tb.sv`
- `tb/store_unit_tb.sv`
- `tb/load_unit_tb.sv`
- `tb/memory_access_integration_tb.sv`
- `tb/mem_wb_register_tb.sv`
- `tb/mem_stage_tb.sv`

---

## 50. Estado

La etapa MEM base queda implementada y validada mediante pruebas unitarias,
pruebas de integración y simulación completa en Vivado/XSim.

Resultados:

`PASS: data_memory`

`PASS: store_unit`

`PASS: load_unit`

`PASS: memory_access_integration`

`PASS: mem_wb_register`

`PASS: mem_stage`

Estado final:

`Paso 8 — MEM: VALIDADO`
