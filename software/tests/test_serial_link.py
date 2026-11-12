from __future__ import annotations
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

import types
import unittest

from software.serial_link import SerialLink


class FakeSerialException(Exception):
    pass


class FakeSerialTimeoutException(FakeSerialException):
    pass


class FakeSerial:
    def __init__(self, incoming: bytes = b"") -> None:
        self.incoming = bytearray(incoming)
        self.outgoing = bytearray()
        self.is_open = True
        self.port = "/dev/fake"

    def read(self, size: int) -> bytes:
        if not self.incoming:
            return b""
        amount = min(size, 2, len(self.incoming))
        result = bytes(self.incoming[:amount])
        del self.incoming[:amount]
        return result

    def write(self, data: bytes) -> int:
        self.outgoing.extend(data)
        return len(data)

    def flush(self) -> None:
        pass

    def close(self) -> None:
        self.is_open = False

    def reset_input_buffer(self) -> None:
        self.incoming.clear()


class SerialLinkTests(unittest.TestCase):
    def test_virtual_uart_is_listed_when_active(
        self,
    ) -> None:

        with TemporaryDirectory() as directory:

            virtual_port = (
                Path(directory)
                / "riscv_pipeline_uart"
            )

            virtual_port.touch()

            with (
                patch(
                    "software.serial_link."
                    "VIRTUAL_UART_DEVICE",
                    virtual_port,
                ),
                patch(
                    "serial.tools."
                    "list_ports.comports",
                    return_value=[],
                ),
            ):

                ports = (
                    SerialLink.list_ports()
                )

        self.assertEqual(
            len(ports),
            1,
        )

        self.assertEqual(
            ports[0].device,
            str(virtual_port),
        )

        self.assertEqual(
            ports[0].description,
            "UART virtual XSim",
        )

    def make_link(self, incoming: bytes = b"") -> SerialLink:
        link = object.__new__(SerialLink)
        link._timeout = 0.05
        link._serial = FakeSerial(incoming)
        link._serial_module = types.SimpleNamespace(
            SerialException=FakeSerialException,
            SerialTimeoutException=FakeSerialTimeoutException,
        )
        return link

    def test_read_exact_accumulates_partial_reads(self) -> None:
        link = self.make_link(b"abcdef")
        self.assertEqual(link.read_exact(6), b"abcdef")

    def test_write(self) -> None:
        link = self.make_link()
        link.write(b"abc")
        self.assertEqual(bytes(link._serial.outgoing), b"abc")

    def test_close(self) -> None:
        link = self.make_link()
        link.close()
        self.assertFalse(link.is_open)

    def test_timeout(self) -> None:
        link = self.make_link()
        with self.assertRaises(TimeoutError):
            link.read_exact(1)


if __name__ == "__main__":
    unittest.main()
