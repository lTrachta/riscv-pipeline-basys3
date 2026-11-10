from __future__ import annotations

import unittest

from software.assembler import assemble_program
from software.models import ProcessorStatus
from software.protocol import (
    CMD_DEBUG,
    CMD_END,
    CMD_LOAD,
    CMD_QUERY,
    CMD_RUN,
    CMD_STEP,
    CMD_WRITE,
    ProcessorClient,
)
from software.transport import ByteTransport


def u16(value: int) -> bytes:
    return value.to_bytes(2, "big")


def u32(value: int) -> bytes:
    return value.to_bytes(4, "big")


def build_snapshot(
    *,
    status: ProcessorStatus,
    flags: int,
    if_pc: int,
    registers: list[int] | None = None,
    if_id_valid: bool = False,
    if_id_pc: int = 0,
    if_id_instruction: int = 0,
    id_ex_valid: bool = False,
    id_ex_pc: int = 0,
    ex_mem_valid: bool = False,
    ex_mem_pc: int = 0,
    mem_wb_valid: bool = False,
    mem_wb_pc: int = 0,
    memory: list[tuple[int, int]] | None = None,
) -> bytes:
    regs = list(registers or [0] * 32)
    memory_entries = list(memory or [])

    if len(regs) != 32:
        raise ValueError("se requieren exactamente 32 registros")

    data = bytearray()

    # Header: 'd', version, status, flags, IF PC.
    data += bytes([0x64, 0x01, int(status), flags & 0xFF])
    data += u32(if_pc)

    # Register File.
    data += bytes([0x52, 32])
    for index, value in enumerate(regs):
        data += bytes([index])
        data += u32(value & 0xFFFFFFFF)

    # IF/ID.
    data += bytes([0x49, int(if_id_valid)])
    data += u32(if_id_pc)
    data += u32(if_id_instruction)

    # ID/EX: tag, valid, PC, read1, read2, imm,
    # rs1, rs2, rd, opcode, funct3, funct7, control16.
    data += bytes([0x58, int(id_ex_valid)])
    data += u32(id_ex_pc)
    data += u32(0)
    data += u32(0)
    data += u32(0)
    data += bytes([0, 0, 0, 0, 0, 0])
    data += u16(0)

    # EX/MEM: tag, valid, PC, alu, store,
    # rs2, rd, opcode, funct3, control8.
    data += bytes([0x45, int(ex_mem_valid)])
    data += u32(ex_mem_pc)
    data += u32(0)
    data += u32(0)
    data += bytes([0, 0, 0, 0, 0])

    # MEM/WB: tag, valid, PC, alu, load,
    # rd, opcode, control8.
    data += bytes([0x42, int(mem_wb_valid)])
    data += u32(mem_wb_pc)
    data += u32(0)
    data += u32(0)
    data += bytes([0, 0, 0])

    # Used Data Memory.
    data += bytes([0x4D])
    data += u16(len(memory_entries))
    for address, value in memory_entries:
        data += u16(address)
        data += u32(value & 0xFFFFFFFF)

    data += bytes([0x7E])

    expected = 246 + 6 * len(memory_entries)
    if len(data) != expected:
        raise AssertionError(
            f"snapshot de prueba inválido: {len(data)} bytes; esperado {expected}"
        )

    return bytes(data)


class SimulatedProcessorTransport(ByteTransport):
    """FPGA mínima simulada a nivel del protocolo de bytes.

    No simula el datapath RISC-V. Su objetivo es verificar que las capas
    de software se conectan correctamente entre sí: assembler, LOAD,
    STEP, snapshots, RUN y consultas Q.
    """

    def __init__(self) -> None:
        self.incoming = bytearray()
        self.loaded_words: list[int] = []
        self.closed = False
        self.step_count = 0
        self.run_started = False
        self.halted = False
        self.query_index = 0
        self.commands: list[int] = []

    def _queue(self, data: bytes) -> None:
        self.incoming.extend(data)

    def _handle_load(self, data: bytes) -> None:
        if len(data) < 4 or data[0] != CMD_LOAD:
            raise AssertionError("trama LOAD inválida")

        count = int.from_bytes(data[1:3], "big")
        index = 3
        words: list[int] = []

        for expected_index in range(count):
            if index + 7 > len(data):
                raise AssertionError("trama LOAD truncada")

            if data[index] != CMD_WRITE:
                raise AssertionError("falta comando W en trama LOAD")

            address = int.from_bytes(data[index + 1:index + 3], "big")
            word = int.from_bytes(data[index + 3:index + 7], "big")

            if address != expected_index * 4:
                raise AssertionError(
                    f"dirección LOAD incorrecta: {address} != {expected_index * 4}"
                )

            words.append(word)
            index += 7

        if index >= len(data) or data[index] != CMD_END:
            raise AssertionError("falta comando E en trama LOAD")

        if index != len(data) - 1:
            raise AssertionError("sobran bytes después de E")

        self.loaded_words = words
        self.step_count = 0
        self.run_started = False
        self.halted = False
        self.query_index = 0
        self._queue(b"\x06")

    def _mid_snapshot(self) -> bytes:
        registers = [0] * 32

        first_instruction = self.loaded_words[0] if self.loaded_words else 0

        # Después del primer STEP: IF avanzó a PC=4 e IF/ID contiene PC=0.
        return build_snapshot(
            status=ProcessorStatus.READY,
            flags=0x01,  # core_running=1, pausado entre STEP.
            if_pc=4,
            registers=registers,
            if_id_valid=True,
            if_id_pc=0,
            if_id_instruction=first_instruction,
        )

    def _final_snapshot(self) -> bytes:
        registers = [0] * 32
        registers[1] = 10
        registers[2] = 20
        registers[3] = 30

        return build_snapshot(
            status=ProcessorStatus.HALTED,
            flags=0x0C,  # halted + pipeline_empty.
            if_pc=20,
            registers=registers,
            memory=[(64, 30)],
        )

    def write(self, data: bytes) -> None:
        if self.closed:
            raise RuntimeError("transporte cerrado")

        if not data:
            return

        command = data[0]
        self.commands.append(command)

        if command == CMD_LOAD:
            self._handle_load(data)
            return

        if command == CMD_STEP:
            if not self.loaded_words or self.halted:
                self._queue(bytes([0x15, 0x05]))
                return

            self.step_count += 1
            self._queue(b"\x06")
            return

        if command == CMD_DEBUG:
            if self.halted:
                self._queue(self._final_snapshot())
            else:
                self._queue(self._mid_snapshot())
            return

        if command == CMD_RUN:
            if not self.loaded_words or self.halted:
                self._queue(bytes([0x15, 0x05]))
                return

            self.run_started = True
            self.query_index = 0
            self._queue(b"\x06")
            return

        if command == CMD_QUERY:
            if not self.run_started:
                state = ProcessorStatus.HALTED if self.halted else ProcessorStatus.READY
            else:
                sequence = [
                    ProcessorStatus.RUNNING,
                    ProcessorStatus.DRAINING,
                    ProcessorStatus.HALTED,
                ]
                state = sequence[min(self.query_index, len(sequence) - 1)]
                self.query_index += 1

                if state == ProcessorStatus.HALTED:
                    self.halted = True
                    self.run_started = False

            self._queue(bytes([0x71, int(state)]))
            return

        raise AssertionError(f"comando no simulado: 0x{command:02X}")

    def read_exact(self, size: int) -> bytes:
        if len(self.incoming) < size:
            raise TimeoutError(
                f"simulador: faltan bytes ({len(self.incoming)}/{size})"
            )

        result = bytes(self.incoming[:size])
        del self.incoming[:size]
        return result

    def close(self) -> None:
        self.closed = True


class SoftwareEndToEndTests(unittest.TestCase):
    def test_complete_software_flow(self) -> None:
        source = """
        .text
        .globl _start

        _start:
            addi x1, x0, 10
            addi x2, x0, 20
            add  x3, x1, x2
            sw   x3, 64(x0)
            HALT
        """

        # 1) Assembly -> código máquina.
        program = assemble_program(source)
        self.assertEqual(len(program.instructions), 5)
        self.assertEqual(program.instructions[0].address, 0)
        self.assertEqual(program.instructions[-1].word, 0x0000000B)

        # 2) Cliente de protocolo sobre una FPGA simulada.
        transport = SimulatedProcessorTransport()
        client = ProcessorClient(transport)

        # 3) LOAD completo L/W/E.
        client.load_program(program.words)
        self.assertEqual(transport.loaded_words, program.words)

        # 4) STEP -> ACK -> D -> snapshot intermedio.
        mid = client.step_and_snapshot()
        self.assertEqual(transport.step_count, 1)
        self.assertEqual(mid.status, ProcessorStatus.READY)
        self.assertEqual(mid.if_pc, 4)
        self.assertTrue(mid.if_id.valid)
        self.assertEqual(mid.if_id.pc, 0)
        self.assertEqual(mid.if_id.instruction, program.instructions[0].word)

        # El PC del snapshot puede volver a relacionarse con el programa fuente.
        self.assertIn("addi x1", program.instruction_at(mid.if_id.pc).text)

        # 5) RUN -> Q hasta RUNNING/DRAINING/HALTED -> D final.
        seen_states: list[ProcessorStatus] = []
        final = client.run_and_snapshot(
            poll_interval=0,
            timeout=1,
            on_state=seen_states.append,
        )

        self.assertEqual(
            seen_states,
            [
                ProcessorStatus.RUNNING,
                ProcessorStatus.DRAINING,
                ProcessorStatus.HALTED,
            ],
        )

        # 6) Estado arquitectónico final simulado.
        self.assertEqual(final.status, ProcessorStatus.HALTED)
        self.assertTrue(final.flags.halted)
        self.assertTrue(final.pipeline_empty)
        self.assertEqual(final.registers[1], 10)
        self.assertEqual(final.registers[2], 20)
        self.assertEqual(final.registers[3], 30)
        self.assertEqual(len(final.used_memory), 1)
        self.assertEqual(final.used_memory[0].address, 64)
        self.assertEqual(final.used_memory[0].value, 30)

        # 7) El flujo dejó exactamente las familias de comandos esperadas.
        self.assertEqual(transport.commands[0], CMD_LOAD)
        self.assertIn(CMD_STEP, transport.commands)
        self.assertIn(CMD_RUN, transport.commands)
        self.assertEqual(transport.commands.count(CMD_DEBUG), 2)
        self.assertEqual(transport.commands.count(CMD_QUERY), 3)

        client.close()
        self.assertTrue(transport.closed)


if __name__ == "__main__":
    unittest.main()
