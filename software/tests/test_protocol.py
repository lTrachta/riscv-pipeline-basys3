from __future__ import annotations

import unittest

from software.models import ProcessorStatus
from software.protocol import (
    CMD_DEBUG,
    CMD_END,
    CMD_LOAD,
    CMD_MEM,
    CMD_QUERY,
    CMD_REG,
    CMD_RUN,
    CMD_STEP,
    CMD_WRITE,
    ProcessorClient,
    ProtocolNackError,
)
from software.transport import ByteTransport


def u16(value: int) -> bytes:
    return value.to_bytes(2, "big")


def u32(value: int) -> bytes:
    return value.to_bytes(4, "big")


def build_minimal_snapshot() -> bytes:
    data = bytearray()
    data += bytes([0x64, 0x01, ProcessorStatus.HALTED, 0x0C])
    data += u32(0x18)
    data += bytes([0x52, 32])
    for register in range(32):
        data += bytes([register]) + u32(register)
    data += bytes([0x49, 0]) + u32(0) + u32(0)
    data += bytes([0x58, 0])
    data += u32(0) + u32(0) + u32(0) + u32(0)
    data += bytes([0, 0, 0, 0, 0, 0]) + u16(0)
    data += bytes([0x45, 0])
    data += u32(0) + u32(0) + u32(0)
    data += bytes([0, 0, 0, 0, 0])
    data += bytes([0x42, 0])
    data += u32(0) + u32(0) + u32(0)
    data += bytes([0, 0, 0])
    data += bytes([0x4D]) + u16(0)
    data += bytes([0x7E])
    assert len(data) == 246
    return bytes(data)


class FakeTransport(ByteTransport):
    def __init__(self, incoming: bytes = b"") -> None:
        self.incoming = bytearray(incoming)
        self.written = bytearray()
        self.closed = False

    def queue(self, data: bytes) -> None:
        self.incoming.extend(data)

    def write(self, data: bytes) -> None:
        self.written.extend(data)

    def read_exact(self, size: int) -> bytes:
        if len(self.incoming) < size:
            raise TimeoutError(
                f"fake transport: faltan bytes ({len(self.incoming)}/{size})"
            )
        result = bytes(self.incoming[:size])
        del self.incoming[:size]
        return result

    def close(self) -> None:
        self.closed = True


class ProtocolTests(unittest.TestCase):
    def test_load_program_generates_expected_frame(self) -> None:
        transport = FakeTransport(b"\x06")
        client = ProcessorClient(transport)
        words = [0x00A00093, 0x0000000B]

        client.load_program(words)

        expected = bytearray([CMD_LOAD, 0x00, 0x02])
        expected += bytes([CMD_WRITE, 0x00, 0x00]) + u32(words[0])
        expected += bytes([CMD_WRITE, 0x00, 0x04]) + u32(words[1])
        expected += bytes([CMD_END])
        self.assertEqual(bytes(transport.written), bytes(expected))

    def test_step_and_run(self) -> None:
        transport = FakeTransport(b"\x06\x06")
        client = ProcessorClient(transport)
        client.step()
        client.run()
        self.assertEqual(bytes(transport.written), bytes([CMD_STEP, CMD_RUN]))

    def test_query_state(self) -> None:
        transport = FakeTransport(bytes([0x71, ProcessorStatus.DRAINING]))
        client = ProcessorClient(transport)
        state = client.query_state()
        self.assertEqual(state, ProcessorStatus.DRAINING)
        self.assertEqual(bytes(transport.written), bytes([CMD_QUERY]))

    def test_read_register(self) -> None:
        transport = FakeTransport(bytes([0x67, 5]) + u32(0x12345678))
        client = ProcessorClient(transport)
        value = client.read_register(5)
        self.assertEqual(value, 0x12345678)
        self.assertEqual(bytes(transport.written), bytes([CMD_REG, 5]))

    def test_read_memory(self) -> None:
        transport = FakeTransport(bytes([0x6D]) + u16(0x40) + u32(0x55))
        client = ProcessorClient(transport)
        value = client.read_memory(0x40)
        self.assertEqual(value, 0x55)
        self.assertEqual(bytes(transport.written), bytes([CMD_MEM, 0x00, 0x40]))

    def test_snapshot(self) -> None:
        raw = build_minimal_snapshot()
        transport = FakeTransport(raw)
        client = ProcessorClient(transport)
        snapshot = client.debug_snapshot()
        self.assertEqual(snapshot.status, ProcessorStatus.HALTED)
        self.assertEqual(snapshot.if_pc, 0x18)
        self.assertEqual(bytes(transport.written), bytes([CMD_DEBUG]))

    def test_nack(self) -> None:
        transport = FakeTransport(bytes([0x15, 0x05]))
        client = ProcessorClient(transport)
        with self.assertRaises(ProtocolNackError) as context:
            client.step()
        self.assertEqual(context.exception.error_code, 0x05)

    def test_run_and_snapshot(self) -> None:
        incoming = bytearray()
        incoming += b"\x06"
        incoming += bytes([0x71, ProcessorStatus.RUNNING])
        incoming += bytes([0x71, ProcessorStatus.DRAINING])
        incoming += bytes([0x71, ProcessorStatus.HALTED])
        incoming += build_minimal_snapshot()

        transport = FakeTransport(bytes(incoming))
        client = ProcessorClient(transport)
        seen_states: list[ProcessorStatus] = []

        snapshot = client.run_and_snapshot(
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
        self.assertEqual(snapshot.status, ProcessorStatus.HALTED)
        self.assertEqual(
            bytes(transport.written),
            bytes([CMD_RUN, CMD_QUERY, CMD_QUERY, CMD_QUERY, CMD_DEBUG]),
        )


if __name__ == "__main__":
    unittest.main()
