from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from typing import Mapping


class ProcessorStatus(IntEnum):
    READY = 0
    LOADING = 1
    RUNNING = 2
    DRAINING = 3
    HALTED = 4
    ERROR = 5


@dataclass(frozen=True)
class AssembledInstruction:
    address: int
    word: int
    text: str
    line_number: int


@dataclass(frozen=True)
class AssembledProgram:
    source: str
    instructions: tuple[AssembledInstruction, ...]
    labels: Mapping[str, int]

    @property
    def words(self) -> list[int]:
        return [instruction.word for instruction in self.instructions]

    def instruction_at(self, address: int) -> AssembledInstruction | None:
        for instruction in self.instructions:
            if instruction.address == address:
                return instruction
        return None


@dataclass(frozen=True)
class SnapshotFlags:
    raw: int

    @property
    def running(self) -> bool:
        return bool(self.raw & (1 << 0))

    @property
    def draining(self) -> bool:
        return bool(self.raw & (1 << 1))

    @property
    def halted(self) -> bool:
        return bool(self.raw & (1 << 2))

    @property
    def pipeline_empty(self) -> bool:
        return bool(self.raw & (1 << 3))

    @property
    def cycle_enable(self) -> bool:
        return bool(self.raw & (1 << 4))


@dataclass(frozen=True)
class IfIdState:
    valid: bool
    pc: int
    instruction: int


@dataclass(frozen=True)
class IdExState:
    valid: bool
    pc: int
    read_data1: int
    read_data2: int
    immediate: int
    rs1: int
    rs2: int
    rd: int
    opcode: int
    funct3: int
    funct7: int
    control: int

    @property
    def alu_src_a(self) -> int:
        return self.control & 0x1

    @property
    def alu_src_b(self) -> int:
        return (self.control >> 1) & 0x1

    @property
    def alu_op(self) -> int:
        return (self.control >> 2) & 0x7

    @property
    def branch(self) -> int:
        return (self.control >> 5) & 0x1

    @property
    def jump_type(self) -> int:
        return (self.control >> 6) & 0x3

    @property
    def mem_read(self) -> int:
        return (self.control >> 8) & 0x1

    @property
    def mem_write(self) -> int:
        return (self.control >> 9) & 0x1

    @property
    def reg_write(self) -> int:
        return (self.control >> 10) & 0x1

    @property
    def wb_sel(self) -> int:
        return (self.control >> 11) & 0x3


@dataclass(frozen=True)
class ExMemState:
    valid: bool
    pc: int
    alu_result: int
    store_data: int
    rs2: int
    rd: int
    opcode: int
    funct3: int
    control: int

    @property
    def mem_read(self) -> int:
        return self.control & 0x1

    @property
    def mem_write(self) -> int:
        return (self.control >> 1) & 0x1

    @property
    def reg_write(self) -> int:
        return (self.control >> 2) & 0x1

    @property
    def wb_sel(self) -> int:
        return (self.control >> 3) & 0x3


@dataclass(frozen=True)
class MemWbState:
    valid: bool
    pc: int
    alu_result: int
    load_data: int
    rd: int
    opcode: int
    control: int

    @property
    def reg_write(self) -> int:
        return self.control & 0x1

    @property
    def wb_sel(self) -> int:
        return (self.control >> 1) & 0x3


@dataclass(frozen=True)
class MemoryEntry:
    address: int
    value: int


@dataclass(frozen=True)
class Snapshot:
    version: int
    status: ProcessorStatus
    flags: SnapshotFlags
    if_pc: int
    registers: tuple[int, ...]
    if_id: IfIdState
    id_ex: IdExState
    ex_mem: ExMemState
    mem_wb: MemWbState
    used_memory: tuple[MemoryEntry, ...]

    @property
    def pipeline_empty(self) -> bool:
        return self.flags.pipeline_empty
