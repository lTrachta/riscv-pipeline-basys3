from __future__ import annotations

import unittest

from software.models import ProcessorStatus
from software.snapshot import (
    FIXED_PREFIX_SIZE,
    SnapshotError,
    expected_snapshot_size_from_prefix,
    parse_snapshot,
)


def u16(value: int) -> bytes:
    return value.to_bytes(2, "big")


def u32(value: int) -> bytes:
    return value.to_bytes(4, "big")


def build_snapshot(memory_entries: list[tuple[int, int]] | None = None) -> bytes:
    memory_entries = memory_entries or []
    data = bytearray()

    data += bytes([0x64, 0x01, ProcessorStatus.HALTED, 0x0C])
    data += u32(0x00000028)

    data += bytes([0x52, 32])
    for register in range(32):
        data += bytes([register])
        data += u32(register * 10)

    data += bytes([0x49, 0x01])
    data += u32(0x20)
    data += u32(0x00700293)

    id_ex_control = (
        (2 << 11)
        | (1 << 10)
        | (1 << 9)
        | (1 << 8)
        | (2 << 6)
        | (1 << 5)
        | (5 << 2)
        | (1 << 1)
        | 1
    )
    data += bytes([0x58, 0x01])
    data += u32(0x1C)
    data += u32(0x11111111)
    data += u32(0x22222222)
    data += u32(0xFFFFFFFC)
    data += bytes([1, 2, 3, 0x33, 0x5, 0x20])
    data += u16(id_ex_control)

    ex_mem_control = (2 << 3) | (1 << 2) | (1 << 1) | 1
    data += bytes([0x45, 0x01])
    data += u32(0x18)
    data += u32(0xABCDEF01)
    data += u32(0x00000055)
    data += bytes([4, 5, 0x23, 0x2, ex_mem_control])

    mem_wb_control = (2 << 1) | 1
    data += bytes([0x42, 0x01])
    data += u32(0x14)
    data += u32(0x12345678)
    data += u32(0x87654321)
    data += bytes([6, 0x03, mem_wb_control])

    data += bytes([0x4D])
    data += u16(len(memory_entries))
    for address, value in memory_entries:
        data += u16(address)
        data += u32(value)

    data += bytes([0x7E])
    return bytes(data)


class SnapshotTests(unittest.TestCase):
    def test_parse_complete_snapshot(self) -> None:
        raw = build_snapshot([(0x0040, 0x00000055), (0x0080, 0x00000000)])
        snapshot = parse_snapshot(raw)

        self.assertEqual(len(raw), 258)
        self.assertEqual(snapshot.version, 1)
        self.assertEqual(snapshot.status, ProcessorStatus.HALTED)
        self.assertTrue(snapshot.flags.halted)
        self.assertTrue(snapshot.flags.pipeline_empty)
        self.assertFalse(snapshot.flags.running)
        self.assertEqual(snapshot.if_pc, 0x28)
        self.assertEqual(snapshot.registers[5], 50)
        self.assertEqual(snapshot.if_id.pc, 0x20)
        self.assertEqual(snapshot.id_ex.pc, 0x1C)
        self.assertEqual(snapshot.id_ex.rs1, 1)
        self.assertEqual(snapshot.id_ex.wb_sel, 2)
        self.assertEqual(snapshot.id_ex.jump_type, 2)
        self.assertEqual(snapshot.ex_mem.alu_result, 0xABCDEF01)
        self.assertEqual(snapshot.ex_mem.mem_write, 1)
        self.assertEqual(snapshot.mem_wb.load_data, 0x87654321)
        self.assertEqual(snapshot.mem_wb.reg_write, 1)
        self.assertEqual(len(snapshot.used_memory), 2)
        self.assertEqual(snapshot.used_memory[0].address, 0x40)
        self.assertEqual(snapshot.used_memory[1].value, 0)

    def test_fixed_snapshot_size_without_memory(self) -> None:
        raw = build_snapshot([])
        self.assertEqual(len(raw), 246)
        self.assertEqual(len(raw[:FIXED_PREFIX_SIZE]), 245)
        self.assertEqual(
            expected_snapshot_size_from_prefix(raw[:FIXED_PREFIX_SIZE]),
            246,
        )

    def test_dynamic_snapshot_size(self) -> None:
        raw = build_snapshot([(0x40, 1), (0x44, 2), (0x48, 3)])
        self.assertEqual(
            expected_snapshot_size_from_prefix(raw[:FIXED_PREFIX_SIZE]),
            len(raw),
        )

    def test_reject_wrong_version(self) -> None:
        raw = bytearray(build_snapshot())
        raw[1] = 2
        with self.assertRaisesRegex(SnapshotError, "versión"):
            parse_snapshot(bytes(raw))

    def test_reject_wrong_tag(self) -> None:
        raw = bytearray(build_snapshot())
        raw[170] = 0x00
        with self.assertRaisesRegex(SnapshotError, "IF/ID"):
            parse_snapshot(bytes(raw))

    def test_reject_truncated_snapshot(self) -> None:
        raw = build_snapshot([(0x40, 0x55)])
        with self.assertRaises(SnapshotError):
            parse_snapshot(raw[:-1])

    def test_reject_extra_bytes(self) -> None:
        raw = build_snapshot() + b"\x00"
        with self.assertRaisesRegex(SnapshotError, "sobran"):
            parse_snapshot(raw)


if __name__ == "__main__":
    unittest.main()
