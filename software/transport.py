from __future__ import annotations

from abc import ABC, abstractmethod


class TransportError(Exception):
    """Error genérico de transporte."""


class ByteTransport(ABC):
    """Interfaz mínima usada por la capa de protocolo."""

    @abstractmethod
    def write(self, data: bytes) -> None:
        raise NotImplementedError

    @abstractmethod
    def read_exact(self, size: int) -> bytes:
        raise NotImplementedError

    @abstractmethod
    def close(self) -> None:
        raise NotImplementedError
