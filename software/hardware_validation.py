from __future__ import annotations

import argparse

from software.assembler import assemble_program
from software.models import ProcessorStatus
from software.protocol import ProcessorClient
from software.serial_link import SerialLink


PROGRAM_SMOKE = """
.text
.globl _start

_start:
    addi x1, x0, 5
    addi x2, x0, 7
    add  x3, x1, x2
    HALT
"""


PROGRAM_MEMORY = """
.text
.globl _start

_start:
    addi x1, x0, 64
    addi x2, x0, 85

    sw   x2, 0(x1)
    lw   x3, 0(x1)

    HALT
"""


PROGRAM_CONTROL = """
.text
.globl _start

_start:
    addi x1, x0, 3
    addi x2, x0, 0

loop:
    addi x2, x2, 2
    addi x1, x1, -1

    bne  x1, x0, loop

    jal  x3, after_jal

    addi x4, x0, 99

after_jal:
    addi x6, x0, 41

    jalr x7, 0(x6)

    addi x8, x0, 99

jalr_target:
    addi x5, x2, 1

    HALT
"""


def check(
    name: str,
    condition: bool,
) -> None:

    if not condition:
        raise AssertionError(
            f"FAIL: {name}"
        )

    print(
        f"PASS: {name}"
    )


def memory_dict(snapshot) -> dict[int, int]:

    return {
        entry.address: entry.value
        for entry in snapshot.used_memory
    }


def run_case(
    client: ProcessorClient,
    name: str,
    source: str,
    expected_registers: dict[int, int],
    expected_memory: dict[int, int] | None = None,
) -> None:

    print()
    print(
        f"=== {name} ==="
    )

    program = assemble_program(
        source
    )

    client.load_program(
        program.words
    )

    state = client.query_state()

    check(
        "READY despues de LOAD",
        state == ProcessorStatus.READY,
    )

    snapshot = client.run_and_snapshot(
        timeout=5.0,
    )

    check(
        "termina HALTED",
        snapshot.status
        == ProcessorStatus.HALTED,
    )

    check(
        "pipeline vacio",
        snapshot.pipeline_empty,
    )

    for register, value in (
        expected_registers.items()
    ):

        check(
            f"x{register} = {value}",
            snapshot.registers[
                register
            ] == value,
        )

    if expected_memory is not None:

        memory = memory_dict(
            snapshot
        )

        for address, value in (
            expected_memory.items()
        ):

            check(
                f"DMEM[{address}] = {value}",
                memory.get(address)
                == value,
            )


def main() -> None:

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "port",
        help=(
            "Puerto serie de la Basys 3, "
            "por ejemplo /dev/ttyUSB1"
        ),
    )

    parser.add_argument(
        "--smoke-only",
        action="store_true",
    )

    args = parser.parse_args()

    link = SerialLink(
        args.port,
        timeout=5.0,
    )

    client = ProcessorClient(
        link
    )

    try:

        link.reset_input_buffer()

        state = client.query_state()

        print(
            f"Estado inicial: "
            f"{state.name}"
        )

        check(
            "UART PC <-> Basys 3",
            state
            == ProcessorStatus.READY,
        )

        if args.smoke_only:
            return

        run_case(
            client,
            "ALU",
            PROGRAM_SMOKE,
            {
                1: 5,
                2: 7,
                3: 12,
            },
        )

        run_case(
            client,
            "MEMORIA",
            PROGRAM_MEMORY,
            {
                1: 64,
                2: 85,
                3: 85,
            },
            {
                64: 85,
            },
        )

        run_case(
            client,
            "CONTROL FLOW",
            PROGRAM_CONTROL,
            {
                1: 0,
                2: 6,
                3: 24,
                4: 0,
                5: 7,
                6: 41,
                7: 36,
                8: 0,
            },
        )

        print()
        print(
            "=" * 64
        )

        print(
            "PASS VALIDACION FISICA BASYS 3"
        )

        print(
            "PC -> USB UART -> FPGA -> "
            "pipeline -> USB UART -> PC"
        )

        print(
            "=" * 64
        )

    finally:

        client.close()


if __name__ == "__main__":
    main()
    