from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path

from .transport import ByteTransport, TransportError


VIRTUAL_UART_DEVICE = Path(
    "/tmp/riscv_pipeline_uart"
)

class SerialLinkError(TransportError):
    """Error de conexión, lectura o escritura serie."""


@dataclass(frozen=True)
class SerialPortInfo:
    device: str
    description: str


class SerialLink(ByteTransport):
    BAUD_RATE = 115_200

    def __init__(
        self,
        port: str,
        *,
        timeout: float = 2.0,
        baudrate: int = BAUD_RATE,
    ) -> None:
        try:
            import serial
        except ImportError as exc:
            raise SerialLinkError(
                "pySerial no está instalado. Ejecutá: pip install pyserial"
            ) from exc

        self._serial_module = serial
        self._timeout = timeout

        try:
            self._serial = serial.Serial(
                port=port,
                baudrate=baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=min(timeout, 0.10),
                write_timeout=timeout,
                xonxoff=False,
                rtscts=False,
                dsrdtr=False,
            )
        except serial.SerialException as exc:
            raise SerialLinkError(
                f"no se pudo abrir el puerto serie {port}: {exc}"
            ) from exc

    @property
    def port(self) -> str:
        return str(self._serial.port)

    @property
    def is_open(self) -> bool:
        return bool(self._serial.is_open)

    @staticmethod
    def list_ports() -> list[SerialPortInfo]:

        try:

            from serial.tools import (
                list_ports,
            )

        except ImportError as exc:

            raise SerialLinkError(
                "pySerial no está instalado. "
                "Ejecutá: pip install pyserial"
            ) from exc

        ports = [
            SerialPortInfo(
                device=port.device,
                description=(
                    port.description
                    or ""
                ),
            )
            for port
            in list_ports.comports()
        ]

        devices = {
            port.device
            for port in ports
        }

        if (
            VIRTUAL_UART_DEVICE.exists()
            and str(
                VIRTUAL_UART_DEVICE
            ) not in devices
        ):

            ports.append(
                SerialPortInfo(
                    device=str(
                        VIRTUAL_UART_DEVICE
                    ),
                    description=(
                        "UART virtual XSim"
                    ),
                )
            )

        return sorted(
            ports,
            key=lambda item: item.device,
        )

    def write(self, data: bytes) -> None:
        if not self.is_open:
            raise SerialLinkError("el puerto serie está cerrado")

        try:
            written = self._serial.write(data)
            self._serial.flush()
        except (
            self._serial_module.SerialException,
            self._serial_module.SerialTimeoutException,
        ) as exc:
            raise SerialLinkError(f"error escribiendo UART: {exc}") from exc

        if written != len(data):
            raise SerialLinkError(
                f"escritura UART incompleta: {written}/{len(data)} bytes"
            )

    def read_exact(self, size: int) -> bytes:
        if size < 0:
            raise ValueError("size no puede ser negativo")

        if size == 0:
            return b""

        if not self.is_open:
            raise SerialLinkError("el puerto serie está cerrado")

        deadline = time.monotonic() + self._timeout
        received = bytearray()

        while len(received) < size:
            remaining_time = deadline - time.monotonic()
            if remaining_time <= 0:
                raise TimeoutError(
                    f"timeout UART: recibidos {len(received)}/{size} bytes"
                )

            try:
                chunk = self._serial.read(size - len(received))
            except self._serial_module.SerialException as exc:
                raise SerialLinkError(f"error leyendo UART: {exc}") from exc

            if chunk:
                received.extend(chunk)

        return bytes(received)

    def reset_input_buffer(self) -> None:
        if self.is_open:
            self._serial.reset_input_buffer()

    def close(self) -> None:
        if getattr(self, "_serial", None) is not None and self._serial.is_open:
            self._serial.close()

    def __enter__(self) -> "SerialLink":
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        self.close()
