from __future__ import annotations

from .models import (
    ExMemState,
    IdExState,
    IfIdState,
    MemWbState,
    MemoryEntry,
    ProcessorStatus,
    Snapshot,
    SnapshotFlags,
)


SNAPSHOT_TAG = 0x64
SNAPSHOT_VERSION = 0x01
TAG_REGISTERS = 0x52
TAG_IF_ID = 0x49
TAG_ID_EX = 0x58
TAG_EX_MEM = 0x45
TAG_MEM_WB = 0x42
TAG_MEMORY = 0x4D
TAG_END = 0x7E

FIXED_PREFIX_SIZE = 245
FIXED_SNAPSHOT_SIZE = 246
MEMORY_COUNT_OFFSET = 243


class SnapshotError(Exception):
    """Paquete de snapshot inválido o incompleto."""


def _u16(data: bytes, offset: int) -> int:
    return int.from_bytes(data[offset:offset + 2], byteorder="big", signed=False)


def _u32(data: bytes, offset: int) -> int:
    return int.from_bytes(data[offset:offset + 4], byteorder="big", signed=False)


def memory_count_from_prefix(prefix: bytes) -> int:
    if len(prefix) < FIXED_PREFIX_SIZE:
        raise SnapshotError(
            f"prefijo incompleto: {len(prefix)} bytes; se necesitan {FIXED_PREFIX_SIZE}"
        )

    if prefix[0] != SNAPSHOT_TAG:
        raise SnapshotError(
            f"tag inicial inválido: 0x{prefix[0]:02X}; esperado 0x{SNAPSHOT_TAG:02X}"
        )

    if prefix[242] != TAG_MEMORY:
        raise SnapshotError(
            f"tag de memoria inválido: 0x{prefix[242]:02X}; esperado 0x{TAG_MEMORY:02X}"
        )

    return _u16(prefix, MEMORY_COUNT_OFFSET)


def expected_snapshot_size_from_prefix(prefix: bytes) -> int:
    return FIXED_SNAPSHOT_SIZE + 6 * memory_count_from_prefix(prefix)


def parse_snapshot(data: bytes) -> Snapshot:
    if len(data) < FIXED_SNAPSHOT_SIZE:
        raise SnapshotError(
            f"snapshot demasiado corto: {len(data)} bytes; mínimo {FIXED_SNAPSHOT_SIZE}"
        )

    index = 0

    def take_byte() -> int:
        nonlocal index
        if index >= len(data):
            raise SnapshotError("snapshot truncado")
        value = data[index]
        index += 1
        return value

    def expect_tag(expected: int, description: str) -> None:
        value = take_byte()
        if value != expected:
            raise SnapshotError(
                f"tag {description} inválido: 0x{value:02X}; esperado 0x{expected:02X}"
            )

    def take_u16() -> int:
        nonlocal index
        if index + 2 > len(data):
            raise SnapshotError("snapshot truncado leyendo u16")
        value = _u16(data, index)
        index += 2
        return value

    def take_u32() -> int:
        nonlocal index
        if index + 4 > len(data):
            raise SnapshotError("snapshot truncado leyendo u32")
        value = _u32(data, index)
        index += 4
        return value

    expect_tag(SNAPSHOT_TAG, "snapshot")

    version = take_byte()
    if version != SNAPSHOT_VERSION:
        raise SnapshotError(
            f"versión de snapshot no soportada: {version}; esperada {SNAPSHOT_VERSION}"
        )

    raw_status = take_byte()
    try:
        status = ProcessorStatus(raw_status)
    except ValueError as exc:
        raise SnapshotError(f"estado inválido en snapshot: {raw_status}") from exc

    flags = SnapshotFlags(take_byte())
    if_pc = take_u32()

    expect_tag(TAG_REGISTERS, "Register File")
    register_count = take_byte()
    if register_count != 32:
        raise SnapshotError(
            f"cantidad de registros inválida: {register_count}; esperados 32"
        )

    registers = [0] * 32
    seen_registers: set[int] = set()

    for _ in range(register_count):
        register_number = take_byte()
        register_value = take_u32()

        if not 0 <= register_number <= 31:
            raise SnapshotError(f"registro fuera de rango: x{register_number}")

        if register_number in seen_registers:
            raise SnapshotError(f"registro duplicado en snapshot: x{register_number}")

        seen_registers.add(register_number)
        registers[register_number] = register_value

    if len(seen_registers) != 32:
        raise SnapshotError("snapshot no contiene los 32 registros")

    expect_tag(TAG_IF_ID, "IF/ID")
    if_id = IfIdState(
        valid=bool(take_byte()),
        pc=take_u32(),
        instruction=take_u32(),
    )

    expect_tag(TAG_ID_EX, "ID/EX")
    id_ex = IdExState(
        valid=bool(take_byte()),
        pc=take_u32(),
        read_data1=take_u32(),
        read_data2=take_u32(),
        immediate=take_u32(),
        rs1=take_byte() & 0x1F,
        rs2=take_byte() & 0x1F,
        rd=take_byte() & 0x1F,
        opcode=take_byte() & 0x7F,
        funct3=take_byte() & 0x07,
        funct7=take_byte() & 0x7F,
        control=take_u16(),
    )

    expect_tag(TAG_EX_MEM, "EX/MEM")
    ex_mem = ExMemState(
        valid=bool(take_byte()),
        pc=take_u32(),
        alu_result=take_u32(),
        store_data=take_u32(),
        rs2=take_byte() & 0x1F,
        rd=take_byte() & 0x1F,
        opcode=take_byte() & 0x7F,
        funct3=take_byte() & 0x07,
        control=take_byte(),
    )

    expect_tag(TAG_MEM_WB, "MEM/WB")
    mem_wb = MemWbState(
        valid=bool(take_byte()),
        pc=take_u32(),
        alu_result=take_u32(),
        load_data=take_u32(),
        rd=take_byte() & 0x1F,
        opcode=take_byte() & 0x7F,
        control=take_byte(),
    )

    expect_tag(TAG_MEMORY, "Data Memory")
    memory_count = take_u16()
    used_memory: list[MemoryEntry] = []
    seen_addresses: set[int] = set()

    for _ in range(memory_count):
        address = take_u16()
        value = take_u32()

        if address in seen_addresses:
            raise SnapshotError(
                f"dirección de memoria duplicada en snapshot: 0x{address:04X}"
            )

        seen_addresses.add(address)
        used_memory.append(MemoryEntry(address=address, value=value))

    expect_tag(TAG_END, "fin")

    if index != len(data):
        raise SnapshotError(
            f"sobran {len(data) - index} bytes después del fin del snapshot"
        )

    expected_size = FIXED_SNAPSHOT_SIZE + 6 * memory_count
    if len(data) != expected_size:
        raise SnapshotError(
            f"tamaño inválido: {len(data)} bytes; esperado {expected_size}"
        )

    return Snapshot(
        version=version,
        status=status,
        flags=flags,
        if_pc=if_pc,
        registers=tuple(registers),
        if_id=if_id,
        id_ex=id_ex,
        ex_mem=ex_mem,
        mem_wb=mem_wb,
        used_memory=tuple(used_memory),
    )
