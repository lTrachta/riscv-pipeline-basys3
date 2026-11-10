from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .models import AssembledInstruction, AssembledProgram


HALT_INSTRUCTION = 0x0000000B
MAX_INSTRUCTIONS = 256


class AssemblerError(Exception):
    """Error producido al ensamblar un programa."""


@dataclass(frozen=True)
class SourceLine:
    line_number: int
    pc: int
    text: str


R_TYPE = {
    "add":  (0b0000000, 0b000),
    "sub":  (0b0100000, 0b000),
    "sll":  (0b0000000, 0b001),
    "slt":  (0b0000000, 0b010),
    "sltu": (0b0000000, 0b011),
    "xor":  (0b0000000, 0b100),
    "srl":  (0b0000000, 0b101),
    "sra":  (0b0100000, 0b101),
    "or":   (0b0000000, 0b110),
    "and":  (0b0000000, 0b111),
}

I_ALU = {
    "addi": 0b000,
    "slti": 0b010,
    "sltiu": 0b011,
    "xori": 0b100,
    "ori": 0b110,
    "andi": 0b111,
}

I_SHIFT = {
    "slli": (0b0000000, 0b001),
    "srli": (0b0000000, 0b101),
    "srai": (0b0100000, 0b101),
}

LOAD = {
    "lb":  0b000,
    "lh":  0b001,
    "lw":  0b010,
    "lbu": 0b100,
    "lhu": 0b101,
}

STORE = {
    "sb": 0b000,
    "sh": 0b001,
    "sw": 0b010,
}

BRANCH = {
    "beq": 0b000,
    "bne": 0b001,
}


DIRECTIVES_WITHOUT_CODE = (".text", ".globl")


def parse_register(token: str) -> int:
    token = token.strip().lower()

    if not token.startswith("x"):
        raise AssemblerError(f"registro inválido: {token}")

    try:
        number = int(token[1:], 10)
    except ValueError as exc:
        raise AssemblerError(f"registro inválido: {token}") from exc

    if not 0 <= number <= 31:
        raise AssemblerError(f"registro fuera de rango: {token}")

    return number


def parse_integer(token: str) -> int:
    token = token.strip()

    try:
        return int(token, 0)
    except ValueError as exc:
        raise AssemblerError(f"valor inválido: {token}") from exc


def check_signed(value: int, bits: int, description: str) -> None:
    minimum = -(1 << (bits - 1))
    maximum = (1 << (bits - 1)) - 1

    if not minimum <= value <= maximum:
        raise AssemblerError(
            f"{description} fuera de rango para {bits} bits: {value}"
        )


def check_unsigned(value: int, bits: int, description: str) -> None:
    maximum = (1 << bits) - 1

    if not 0 <= value <= maximum:
        raise AssemblerError(
            f"{description} fuera de rango para {bits} bits: {value}"
        )


def split_operands(text: str) -> list[str]:
    if not text.strip():
        return []

    return [operand.strip() for operand in text.split(",")]


def parse_memory_operand(token: str) -> tuple[int, int]:
    token = token.strip()

    left = token.find("(")
    right = token.rfind(")")

    if (
        left == -1
        or right == -1
        or right < left
        or right != len(token) - 1
    ):
        raise AssemblerError(f"operando de memoria inválido: {token}")

    immediate_text = token[:left].strip()
    register_text = token[left + 1:right].strip()

    immediate = parse_integer(immediate_text if immediate_text else "0")
    register = parse_register(register_text)

    return immediate, register


def clean_line(line: str) -> str:
    if "#" in line:
        line = line.split("#", 1)[0]

    return line.strip()


def encode_r(
    rd: int,
    rs1: int,
    rs2: int,
    funct3: int,
    funct7: int,
) -> int:
    return (
        ((funct7 & 0x7F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((rd & 0x1F) << 7)
        | 0b0110011
    )


def encode_i(
    rd: int,
    rs1: int,
    immediate: int,
    funct3: int,
    opcode: int,
) -> int:
    immediate &= 0xFFF

    return (
        (immediate << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def encode_shift_i(
    rd: int,
    rs1: int,
    shamt: int,
    funct3: int,
    funct7: int,
) -> int:
    immediate = ((funct7 & 0x7F) << 5) | (shamt & 0x1F)

    return encode_i(
        rd=rd,
        rs1=rs1,
        immediate=immediate,
        funct3=funct3,
        opcode=0b0010011,
    )


def encode_s(rs1: int, rs2: int, immediate: int, funct3: int) -> int:
    immediate &= 0xFFF

    imm_11_5 = (immediate >> 5) & 0x7F
    imm_4_0 = immediate & 0x1F

    return (
        (imm_11_5 << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | (imm_4_0 << 7)
        | 0b0100011
    )


def encode_b(rs1: int, rs2: int, offset: int, funct3: int) -> int:
    check_signed(offset, 13, "offset de branch")

    if offset % 2 != 0:
        raise AssemblerError(
            f"offset de branch no alineado a 2 bytes: {offset}"
        )

    immediate = offset & 0x1FFF

    imm_12 = (immediate >> 12) & 0x1
    imm_10_5 = (immediate >> 5) & 0x3F
    imm_4_1 = (immediate >> 1) & 0xF
    imm_11 = (immediate >> 11) & 0x1

    return (
        (imm_12 << 31)
        | (imm_10_5 << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | (imm_4_1 << 8)
        | (imm_11 << 7)
        | 0b1100011
    )


def encode_u(rd: int, immediate: int) -> int:
    check_unsigned(immediate, 20, "inmediato de lui")

    return (
        ((immediate & 0xFFFFF) << 12)
        | ((rd & 0x1F) << 7)
        | 0b0110111
    )


def encode_j(rd: int, offset: int) -> int:
    check_signed(offset, 21, "offset de jal")

    if offset % 2 != 0:
        raise AssemblerError(f"offset de jal no alineado a 2 bytes: {offset}")

    immediate = offset & 0x1FFFFF

    imm_20 = (immediate >> 20) & 0x1
    imm_10_1 = (immediate >> 1) & 0x3FF
    imm_11 = (immediate >> 11) & 0x1
    imm_19_12 = (immediate >> 12) & 0xFF

    return (
        (imm_20 << 31)
        | (imm_10_1 << 21)
        | (imm_11 << 20)
        | (imm_19_12 << 12)
        | ((rd & 0x1F) << 7)
        | 0b1101111
    )


def resolve_target(token: str, labels: dict[str, int], current_pc: int) -> int:
    token = token.strip()

    if token in labels:
        return labels[token] - current_pc

    return parse_integer(token)


def first_pass(source: str) -> tuple[list[SourceLine], dict[str, int]]:
    labels: dict[str, int] = {}
    instructions: list[SourceLine] = []
    pc = 0

    for line_number, raw_line in enumerate(source.splitlines(), start=1):
        line = clean_line(raw_line)

        if not line:
            continue

        if line.startswith(DIRECTIVES_WITHOUT_CODE):
            continue

        while ":" in line:
            label_text, remaining = line.split(":", 1)
            label = label_text.strip()

            if not label:
                raise AssemblerError(f"línea {line_number}: label vacío")

            if any(character.isspace() for character in label):
                raise AssemblerError(
                    f"línea {line_number}: label inválido: {label}"
                )

            if label in labels:
                raise AssemblerError(
                    f"línea {line_number}: label duplicado: {label}"
                )

            labels[label] = pc
            line = remaining.strip()

            if not line:
                break

        if not line:
            continue

        instructions.append(
            SourceLine(line_number=line_number, pc=pc, text=line)
        )
        pc += 4

    if len(instructions) > MAX_INSTRUCTIONS:
        raise AssemblerError(
            f"programa demasiado grande: {len(instructions)} instrucciones; "
            f"máximo {MAX_INSTRUCTIONS}"
        )

    return instructions, labels


def encode_instruction(source_line: SourceLine, labels: dict[str, int]) -> int:
    text = source_line.text.strip()
    parts = text.split(None, 1)
    mnemonic = parts[0].lower()
    operand_text = parts[1].strip() if len(parts) > 1 else ""
    operands = split_operands(operand_text)

    try:
        if mnemonic == "halt":
            if operands:
                raise AssemblerError("HALT no recibe operandos")
            return HALT_INSTRUCTION

        if mnemonic == ".word":
            if len(operands) != 1:
                raise AssemblerError(".word requiere exactamente un valor")

            value = parse_integer(operands[0])
            if not -(1 << 31) <= value <= 0xFFFFFFFF:
                raise AssemblerError(f"valor .word fuera de 32 bits: {value}")
            return value & 0xFFFFFFFF

        if mnemonic in R_TYPE:
            if len(operands) != 3:
                raise AssemblerError(f"{mnemonic} requiere rd, rs1, rs2")

            rd = parse_register(operands[0])
            rs1 = parse_register(operands[1])
            rs2 = parse_register(operands[2])
            funct7, funct3 = R_TYPE[mnemonic]
            return encode_r(rd, rs1, rs2, funct3, funct7)

        if mnemonic in I_ALU:
            if len(operands) != 3:
                raise AssemblerError(
                    f"{mnemonic} requiere rd, rs1, inmediato"
                )

            rd = parse_register(operands[0])
            rs1 = parse_register(operands[1])
            immediate = parse_integer(operands[2])
            check_signed(immediate, 12, f"inmediato de {mnemonic}")
            return encode_i(
                rd=rd,
                rs1=rs1,
                immediate=immediate,
                funct3=I_ALU[mnemonic],
                opcode=0b0010011,
            )

        if mnemonic in I_SHIFT:
            if len(operands) != 3:
                raise AssemblerError(f"{mnemonic} requiere rd, rs1, shamt")

            rd = parse_register(operands[0])
            rs1 = parse_register(operands[1])
            shamt = parse_integer(operands[2])
            check_unsigned(shamt, 5, f"shamt de {mnemonic}")
            funct7, funct3 = I_SHIFT[mnemonic]
            return encode_shift_i(rd, rs1, shamt, funct3, funct7)

        if mnemonic in LOAD:
            if len(operands) != 2:
                raise AssemblerError(f"{mnemonic} requiere rd, offset(rs1)")

            rd = parse_register(operands[0])
            immediate, rs1 = parse_memory_operand(operands[1])
            check_signed(immediate, 12, f"offset de {mnemonic}")
            return encode_i(
                rd=rd,
                rs1=rs1,
                immediate=immediate,
                funct3=LOAD[mnemonic],
                opcode=0b0000011,
            )

        if mnemonic in STORE:
            if len(operands) != 2:
                raise AssemblerError(f"{mnemonic} requiere rs2, offset(rs1)")

            rs2 = parse_register(operands[0])
            immediate, rs1 = parse_memory_operand(operands[1])
            check_signed(immediate, 12, f"offset de {mnemonic}")
            return encode_s(rs1, rs2, immediate, STORE[mnemonic])

        if mnemonic in BRANCH:
            if len(operands) != 3:
                raise AssemblerError(f"{mnemonic} requiere rs1, rs2, destino")

            rs1 = parse_register(operands[0])
            rs2 = parse_register(operands[1])
            offset = resolve_target(operands[2], labels, source_line.pc)
            return encode_b(rs1, rs2, offset, BRANCH[mnemonic])

        if mnemonic == "lui":
            if len(operands) != 2:
                raise AssemblerError("lui requiere rd, inmediato20")

            rd = parse_register(operands[0])
            immediate = parse_integer(operands[1])
            return encode_u(rd, immediate)

        if mnemonic == "jal":
            if len(operands) != 2:
                raise AssemblerError("jal requiere rd, destino")

            rd = parse_register(operands[0])
            offset = resolve_target(operands[1], labels, source_line.pc)
            return encode_j(rd, offset)

        if mnemonic == "jalr":
            if len(operands) != 2:
                raise AssemblerError("jalr requiere rd, offset(rs1)")

            rd = parse_register(operands[0])
            immediate, rs1 = parse_memory_operand(operands[1])
            check_signed(immediate, 12, "offset de jalr")
            return encode_i(
                rd=rd,
                rs1=rs1,
                immediate=immediate,
                funct3=0b000,
                opcode=0b1100111,
            )

        raise AssemblerError(f"instrucción no soportada: {mnemonic}")

    except AssemblerError as exc:
        raise AssemblerError(f"línea {source_line.line_number}: {exc}") from exc


def assemble_program(source: str) -> AssembledProgram:
    source_lines, labels = first_pass(source)
    instructions: list[AssembledInstruction] = []

    for source_line in source_lines:
        word = encode_instruction(source_line, labels)
        instructions.append(
            AssembledInstruction(
                address=source_line.pc,
                word=word,
                text=source_line.text,
                line_number=source_line.line_number,
            )
        )

    if not instructions:
        raise AssemblerError("el programa no contiene instrucciones")

    return AssembledProgram(
        source=source,
        instructions=tuple(instructions),
        labels=dict(labels),
    )


def assemble(source: str) -> list[int]:
    return assemble_program(source).words


def assemble_file(path: str | Path) -> AssembledProgram:
    source = Path(path).read_text(encoding="utf-8")
    return assemble_program(source)


def words_to_hex(words: list[int]) -> str:
    return "\n".join(f"{word:08X}" for word in words)
