# Conjunto de instrucciones soportadas

Este documento describe las instrucciones RISC-V soportadas por el procesador del TP.

## Formato R

| Instrucción | Formato | rs1 | rs2 | rd | Inmediato | Memoria | Modifica PC | Operación |
|---|---|---|---|---|---|---|---|---|
| add  | R | Sí | Sí | Sí | No | No | No | rd = rs1 + rs2 |
| sub  | R | Sí | Sí | Sí | No | No | No | rd = rs1 - rs2 |
| sll  | R | Sí | Sí | Sí | No | No | No | Desplazamiento lógico a izquierda |
| srl  | R | Sí | Sí | Sí | No | No | No | Desplazamiento lógico a derecha |
| sra  | R | Sí | Sí | Sí | No | No | No | Desplazamiento aritmético a derecha |
| and  | R | Sí | Sí | Sí | No | No | No | AND bit a bit |
| or   | R | Sí | Sí | Sí | No | No | No | OR bit a bit |
| xor  | R | Sí | Sí | Sí | No | No | No | XOR bit a bit |
| slt  | R | Sí | Sí | Sí | No | No | No | rd = 1 si rs1 < rs2 con signo, sino 0 |
| sltu | R | Sí | Sí | Sí | No | No | No | rd = 1 si rs1 < rs2 sin signo, sino 0 |

## Formato I - Operaciones inmediatas

| Instrucción | Formato | rs1 | rs2 | rd | Inmediato | Memoria | Modifica PC | Operación |
|---|---|---|---|---|---|---|---|---|
| addi  | I | Sí | No | Sí | Sí | No | No | rd = rs1 + inmediato |
| andi  | I | Sí | No | Sí | Sí | No | No | AND entre rs1 e inmediato |
| ori   | I | Sí | No | Sí | Sí | No | No | OR entre rs1 e inmediato |
| xori  | I | Sí | No | Sí | Sí | No | No | XOR entre rs1 e inmediato |
| slti  | I | Sí | No | Sí | Sí | No | No | rd = 1 si rs1 < inmediato con signo, sino 0 |
| sltiu | I | Sí | No | Sí | Sí | No | No | rd = 1 si rs1 < inmediato sin signo, sino 0 |
| slli  | I | Sí | No | Sí | Sí | No | No | Desplazamiento lógico a izquierda por cantidad inmediata |
| srli  | I | Sí | No | Sí | Sí | No | No | Desplazamiento lógico a derecha por cantidad inmediata |
| srai  | I | Sí | No | Sí | Sí | No | No | Desplazamiento aritmético a derecha por cantidad inmediata |

## Formato I - Loads

| Instrucción | Formato | rs1 | rs2 | rd | Inmediato | Memoria | Modifica PC | Operación |
|---|---|---|---|---|---|---|---|---|
| lb  | I | Sí | No | Sí | Sí | Lectura | No | Lee 8 bits de memoria y extiende el signo hacia rd |
| lh  | I | Sí | No | Sí | Sí | Lectura | No | Lee 16 bits de memoria y extiende el signo hacia rd |
| lw  | I | Sí | No | Sí | Sí | Lectura | No | Lee una palabra de memoria y la escribe en rd |
| lbu | I | Sí | No | Sí | Sí | Lectura | No | Lee 8 bits de memoria y completa con ceros hacia rd |
| lhu | I | Sí | No | Sí | Sí | Lectura | No | Lee 16 bits de memoria y completa con ceros hacia rd |

En las instrucciones de carga:

```text
dirección = contenido(rs1) + inmediato
```

El dato leído desde memoria se escribe posteriormente en `rd`.

## Formato I - JALR

| Instrucción | Formato | rs1 | rs2 | rd | Inmediato | Memoria | Modifica PC | Operación |
|---|---|---|---|---|---|---|---|---|
| jalr | I | Sí | No | Sí | Sí | No | Sí | rd = PC + 4; salto a contenido(rs1) + inmediato con bit 0 del destino en cero |

JALR utiliza un registro como base para calcular la dirección de salto y guarda `PC + 4` en `rd`.

## Formato S - Stores

| Instrucción | Formato | rs1 | rs2 | rd | Inmediato | Memoria | Modifica PC | Operación |
|---|---|---|---|---|---|---|---|---|
| sb | S | Sí | Sí | No | Sí | Escritura | No | Almacena los 8 bits menos significativos de rs2 en memoria |
| sh | S | Sí | Sí | No | Sí | Escritura | No | Almacena los 16 bits menos significativos de rs2 en memoria |
| sw | S | Sí | Sí | No | Sí | Escritura | No | Almacena una palabra de rs2 en memoria |

En los stores:

- `rs1` contiene la dirección base;
- `rs2` contiene el dato que se escribirá;
- el inmediato es el desplazamiento.

```text
dirección = contenido(rs1) + inmediato
```

Las instrucciones S no poseen registro destino `rd`.

## Formato B - Branches

| Instrucción | Formato | rs1 | rs2 | rd | Inmediato | Memoria | Modifica PC | Operación |
|---|---|---|---|---|---|---|---|---|
| beq | B | Sí | Sí | No | Sí | No | Condicional | Si rs1 == rs2: PC = PC + inmediato; sino: PC = PC + 4 |
| bne | B | Sí | Sí | No | Sí | No | Condicional | Si rs1 != rs2: PC = PC + inmediato; sino: PC = PC + 4 |

Las instrucciones B comparan dos registros y no escriben registro destino.

## Formato U - Inmediato superior

| Instrucción | Formato | rs1 | rs2 | rd | Inmediato | Memoria | Modifica PC | Operación |
|---|---|---|---|---|---|---|---|---|
| lui | U | No | No | Sí | Sí | No | No | rd = inmediato << 12 |

Los 12 bits inferiores del resultado quedan en cero.

## Formato J - Salto incondicional

| Instrucción | Formato | rs1 | rs2 | rd | Inmediato | Memoria | Modifica PC | Operación |
|---|---|---|---|---|---|---|---|---|
| jal | J | No | No | Sí | Sí | No | Sí | rd = PC + 4; PC = PC + inmediato |

JAL realiza un salto relativo al PC y guarda en `rd` la dirección de retorno `PC + 4`.

## Resumen por formato

| Formato | Cantidad | Instrucciones |
|---|---:|---|
| R | 10 | add, sub, sll, srl, sra, and, or, xor, slt, sltu |
| I - Inmediatas | 9 | addi, andi, ori, xori, slti, sltiu, slli, srli, srai |
| I - Loads | 5 | lb, lh, lw, lbu, lhu |
| I - Salto | 1 | jalr |
| S | 3 | sb, sh, sw |
| B | 2 | beq, bne |
| U | 1 | lui |
| J | 1 | jal |
| **Total** | **32** | |

## Extensión de diseño: HALT

El conjunto exigido por el enunciado contiene 32 instrucciones. Además, el sistema requiere un mecanismo explícito de parada.

Se adoptó como extensión propia:

```text
HALT = 32'h0000000B
```

HALT no se contabiliza entre las 32 instrucciones RISC-V anteriores.

La instrucción se detecta en ID. Cuando un HALT válido es aceptado:

1. se impide el ingreso de instrucciones nuevas;
2. IF/ID e ID/EX son invalidados para evitar que HALT continúe como una instrucción normal;
3. las instrucciones más antiguas que ya se encuentran en el pipeline pueden terminar;
4. el controlador pasa de `RUNNING` a `DRAINING`;
5. solamente cuando IF/ID, ID/EX, EX/MEM y MEM/WB están vacíos se alcanza `HALTED`.

Un redirect generado por una instrucción más antigua en EX tiene prioridad sobre un HALT más joven en ID. De esta manera, un HALT ubicado en un camino incorrecto no detiene el procesador.

La existencia de un pipeline vacío por sí sola no implica fin de programa. `HALTED` sólo puede alcanzarse luego de haber aceptado HALT.

Si no existe un HALT alcanzable, el procesador continúa ejecutando hasta que una acción externa lo detenga o resetee.
