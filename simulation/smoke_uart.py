from software.models import (
    ProcessorStatus,
)

from software.protocol import (
    ProcessorClient,
)

from software.serial_link import (
    SerialLink,
)


PORT = (
    "/tmp/riscv_pipeline_uart"
)


def main() -> None:

    link = SerialLink(
        PORT,
        timeout=10.0,
    )

    client = ProcessorClient(
        link
    )

    try:

        state = (
            client.query_state()
        )

        print(
            f"Estado recibido: "
            f"{state.name}"
        )

        assert (
            state
            == ProcessorStatus.READY
        )

        print(
            "PASS: Python -> UART RTL "
            "-> protocolo -> UART RTL "
            "-> Python"
        )

    finally:

        client.close()


if __name__ == "__main__":
    main()
    