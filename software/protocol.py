from __future__ import annotations

import time
from collections.abc import Callable, Sequence

from .models import ProcessorStatus, Snapshot
from .snapshot import (
    FIXED_PREFIX_SIZE,
    SNAPSHOT_TAG,
    memory_count_from_prefix,
    parse_snapshot,
)
from .transport import ByteTransport


CMD_LOAD = 0x4C  # L
CMD_WRITE = 0x57  # W
CMD_END = 0x45  # E
CMD_RUN = 0x52  # R
CMD_STEP = 0x53  # S
CMD_REG = 0x47  # G
CMD_MEM = 0x4D  # M
CMD_QUERY = 0x51  # Q
CMD_DEBUG = 0x44  # D

RESP_ACK = 0x06
RESP_NACK = 0x15
RESP_REG = 0x67  # g
RESP_MEM = 0x6D  # m
RESP_STATE = 0x71  # q

ERR_UNKNOWN_COMMAND = 0x01
ERR_INVALID_ARGUMENT = 0x02
ERR_INVALID_ADDRESS = 0x03
ERR_LOAD = 0x04
ERR_INVALID_STATE = 0x05

ERROR_NAMES = {
    ERR_UNKNOWN_COMMAND: "comando desconocido",
    ERR_INVALID_ARGUMENT: "argumento inválido",
    ERR_INVALID_ADDRESS: "dirección inválida",
    ERR_LOAD: "error de carga",
    ERR_INVALID_STATE: "operación no permitida en el estado actual",
}


class ProtocolError(Exception):
    """Respuesta inesperada o inválida del procesador."""


class ProtocolNackError(ProtocolError):
    def __init__(self, error_code: int) -> None:
        self.error_code = error_code
        description = ERROR_NAMES.get(error_code, "error desconocido")
        super().__init__(f"NACK 0x{error_code:02X}: {description}")


class ProcessorClient:
    def __init__(self, transport: ByteTransport) -> None:
        self.transport = transport

    def close(self) -> None:
        self.transport.close()

    def _raise_nack(self) -> None:
        error_code = self.transport.read_exact(1)[0]
        raise ProtocolNackError(error_code)

    def _read_first_or_nack(self) -> int:
        first = self.transport.read_exact(1)[0]
        if first == RESP_NACK:
            self._raise_nack()
        return first

    def _expect_ack(self) -> None:
        first = self._read_first_or_nack()
        if first != RESP_ACK:
            raise ProtocolError(
                f"respuesta inesperada: 0x{first:02X}; esperado ACK 0x{RESP_ACK:02X}"
            )

    def load_program(self, words: Sequence[int]) -> None:
        if not words:
            raise ValueError("el programa no contiene instrucciones")

        if len(words) > 256:
            raise ValueError(
                f"el programa tiene {len(words)} instrucciones; máximo 256"
            )

        frame = bytearray()
        frame.append(CMD_LOAD)
        frame.extend(len(words).to_bytes(2, byteorder="big"))

        for index, word in enumerate(words):
            if not 0 <= int(word) <= 0xFFFFFFFF:
                raise ValueError(
                    f"palabra fuera de 32 bits en índice {index}: {word}"
                )

            address = index * 4
            frame.append(CMD_WRITE)
            frame.extend(address.to_bytes(2, byteorder="big"))
            frame.extend(int(word).to_bytes(4, byteorder="big"))

        frame.append(CMD_END)
        self.transport.write(bytes(frame))
        self._expect_ack()

    def run(self) -> None:
        self.transport.write(bytes([CMD_RUN]))
        self._expect_ack()

    def step(self) -> None:
        self.transport.write(bytes([CMD_STEP]))
        self._expect_ack()

    def query_state(self) -> ProcessorStatus:
        self.transport.write(bytes([CMD_QUERY]))
        first = self._read_first_or_nack()

        if first != RESP_STATE:
            raise ProtocolError(
                f"respuesta de estado inválida: 0x{first:02X}; esperado 0x{RESP_STATE:02X}"
            )

        raw_state = self.transport.read_exact(1)[0]
        try:
            return ProcessorStatus(raw_state)
        except ValueError as exc:
            raise ProtocolError(f"estado desconocido: {raw_state}") from exc

    def read_register(self, register: int) -> int:
        if not 0 <= register <= 31:
            raise ValueError(f"registro fuera de rango: x{register}")

        self.transport.write(bytes([CMD_REG, register]))
        first = self._read_first_or_nack()

        if first != RESP_REG:
            raise ProtocolError(
                f"respuesta de registro inválida: 0x{first:02X}; esperado 0x{RESP_REG:02X}"
            )

        payload = self.transport.read_exact(5)
        returned_register = payload[0]

        if returned_register != register:
            raise ProtocolError(
                f"la FPGA respondió x{returned_register} pero se solicitó x{register}"
            )

        return int.from_bytes(payload[1:5], byteorder="big")

    def read_memory(self, address: int) -> int:
        if not 0 <= address <= 0xFFFF:
            raise ValueError(f"dirección fuera de 16 bits: {address}")

        if address % 4 != 0:
            raise ValueError(f"dirección no alineada a palabra: 0x{address:04X}")

        self.transport.write(
            bytes([CMD_MEM]) + address.to_bytes(2, byteorder="big")
        )
        first = self._read_first_or_nack()

        if first != RESP_MEM:
            raise ProtocolError(
                f"respuesta de memoria inválida: 0x{first:02X}; esperado 0x{RESP_MEM:02X}"
            )

        payload = self.transport.read_exact(6)
        returned_address = int.from_bytes(payload[0:2], byteorder="big")

        if returned_address != address:
            raise ProtocolError(
                "la FPGA respondió una dirección diferente: "
                f"0x{returned_address:04X} != 0x{address:04X}"
            )

        return int.from_bytes(payload[2:6], byteorder="big")

    def debug_snapshot(self) -> Snapshot:
        self.transport.write(bytes([CMD_DEBUG]))
        first = self._read_first_or_nack()

        if first != SNAPSHOT_TAG:
            raise ProtocolError(
                f"respuesta de snapshot inválida: 0x{first:02X}; esperado 0x{SNAPSHOT_TAG:02X}"
            )

        prefix = bytes([first]) + self.transport.read_exact(FIXED_PREFIX_SIZE - 1)
        memory_count = memory_count_from_prefix(prefix)
        tail = self.transport.read_exact(memory_count * 6 + 1)
        return parse_snapshot(prefix + tail)

    def step_and_snapshot(self) -> Snapshot:
        self.step()
        return self.debug_snapshot()

    def wait_until_halted(
        self,
        *,
        poll_interval: float = 0.05,
        timeout: float | None = None,
        on_state: Callable[[ProcessorStatus], None] | None = None,
    ) -> ProcessorStatus:
        start = time.monotonic()

        while True:
            state = self.query_state()

            if on_state is not None:
                on_state(state)

            if state == ProcessorStatus.HALTED:
                return state

            if state == ProcessorStatus.ERROR:
                raise ProtocolError("el procesador informó estado ERROR")

            if timeout is not None and (time.monotonic() - start) >= timeout:
                raise TimeoutError(
                    "el programa no alcanzó HALTED antes del timeout"
                )

            time.sleep(poll_interval)

    def run_and_snapshot(
        self,
        *,
        poll_interval: float = 0.05,
        timeout: float | None = None,
        on_state: Callable[[ProcessorStatus], None] | None = None,
    ) -> Snapshot:
        self.run()
        self.wait_until_halted(
            poll_interval=poll_interval,
            timeout=timeout,
            on_state=on_state,
        )
        return self.debug_snapshot()
