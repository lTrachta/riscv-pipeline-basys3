from __future__ import annotations

import sys
from pathlib import Path

from software.assembler import (
    assemble_program,
)

from software.models import (
    ProcessorStatus,
)

from software.protocol import (
    CMD_DEBUG,
    CMD_LOAD,
    CMD_MEM,
    CMD_REG,
    ERR_INVALID_ADDRESS,
    ERR_INVALID_ARGUMENT,
    ERR_INVALID_STATE,
    ERR_LOAD,
    ERR_UNKNOWN_COMMAND,
    RESP_NACK,
    ProcessorClient,
    ProtocolNackError,
)

from software.serial_link import (
    SerialLink,
)


ROOT = Path(
    __file__
).resolve().parents[1]

PORT = (
    "/tmp/riscv_pipeline_uart"
)

STOP_FILE = (
    ROOT
    / "simulation"
    / ".stop_virtual_uart"
)


PROGRAM_A = """
.text
.globl _start

_start:
    addi x1, x0, 64
    addi x2, x0, 5

    sw   x2, 0(x1)

    lw   x3, 0(x1)
    add  x4, x3, x2

    HALT
"""


PROGRAM_B = """
.text
.globl _start

_start:
    addi x1, x0, 80

    addi x2, x0, 7
    sw   x2, 0(x1)

    addi x2, x0, 9
    sw   x2, 4(x1)

    lw   x3, 0(x1)
    lw   x4, 4(x1)

    add  x5, x3, x4

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


PROGRAM_NO_HALT = """
.text
.globl _start

_start:
    addi x1, x0, 0

loop:
    addi x1, x1, 1

    jal x0, loop
"""


def check(
    name: str,
    condition: bool,
    detail: str = "",
) -> None:

    if not condition:

        suffix = (
            f" | {detail}"
            if detail
            else ""
        )

        raise AssertionError(
            f"FAIL: {name}{suffix}"
        )

    print(
        f"PASS: {name}"
    )


def expect_nack(
    link: SerialLink,
    payload: bytes,
    expected_error: int,
) -> None:

    link.write(
        payload
    )

    response = (
        link.read_exact(2)
    )

    expected = bytes([
        RESP_NACK,
        expected_error,
    ])

    check(
        (
            "NACK "
            f"0x{expected_error:02X}"
        ),
        response == expected,
        (
            "respuesta="
            + response.hex(" ")
        ),
    )


def memory_dict(
    snapshot,
) -> dict[int, int]:

    return {
        entry.address:
            entry.value
        for entry
        in snapshot.used_memory
    }


def main() -> None:

    if not Path(PORT).exists():

        raise RuntimeError(
            f"No existe {PORT}. "
            "Primero inicia "
            "simulation.run_virtual_uart"
        )

    STOP_FILE.unlink(
        missing_ok=True
    )

    link = SerialLink(
        PORT,
        timeout=10.0,
    )

    client = ProcessorClient(
        link
    )

    try:

        link.reset_input_buffer()

        # =====================================================
        # 7. LOAD END-TO-END
        # =====================================================

        print()
        print(
            "=== LOAD + STEP + RUN ==="
        )

        program_a = (
            assemble_program(
                PROGRAM_A
            )
        )

        client.load_program(
            program_a.words
        )

        state = (
            client.query_state()
        )

        check(
            "LOAD deja READY",
            state
            == ProcessorStatus.READY,
        )

        # =====================================================
        # 8. STEP END-TO-END
        # =====================================================

        snapshot = (
            client.step_and_snapshot()
        )

        check(
            "STEP1 IF PC = 4",
            snapshot.if_pc == 4,
        )

        check(
            "STEP1 IF/ID valido",
            snapshot.if_id.valid,
        )

        check(
            "STEP1 IF/ID PC = 0",
            snapshot.if_id.pc == 0,
        )

        instruction = (
            program_a.instruction_at(
                snapshot.if_id.pc
            )
        )

        check(
            "PC del snapshot "
            "mapea al assembly",
            instruction
            is not None,
        )

        snapshot = (
            client.step_and_snapshot()
        )

        check(
            "STEP2 IF PC = 8",
            snapshot.if_pc == 8,
        )

        check(
            "STEP2 ID/EX valido",
            snapshot.id_ex.valid,
        )

        check(
            "STEP2 ID/EX PC = 0",
            snapshot.id_ex.pc == 0,
        )

        # =====================================================
        # 9. RUN + HALT + DRAIN
        # =====================================================

        final_a = (
            client.run_and_snapshot(
                poll_interval=0.01,
                timeout=10.0,
            )
        )

        check(
            "A termina HALTED",
            final_a.status
            == ProcessorStatus.HALTED,
        )

        check(
            "A termina con "
            "pipeline vacio",
            final_a.pipeline_empty,
        )

        check(
            "flag halted",
            final_a.flags.halted,
        )

        # =====================================================
        # 10. REGISTROS Y MEMORIA
        # =====================================================

        check(
            "snapshot x1 = 64",
            final_a.registers[1]
            == 64,
        )

        check(
            "snapshot x2 = 5",
            final_a.registers[2]
            == 5,
        )

        check(
            "snapshot x3 = 5",
            final_a.registers[3]
            == 5,
        )

        check(
            "snapshot x4 = 10",
            final_a.registers[4]
            == 10,
        )

        memory_a = (
            memory_dict(
                final_a
            )
        )

        check(
            "snapshot DMEM[64] = 5",
            memory_a.get(64)
            == 5,
        )

        check(
            "G x4 = 10",
            client.read_register(4)
            == 10,
        )

        check(
            "M 64 = 5",
            client.read_memory(64)
            == 5,
        )

        # =====================================================
        # 11. REPROGRAMACION DINAMICA
        # =====================================================

        print()
        print(
            "=== REPROGRAMACION ==="
        )

        program_b = (
            assemble_program(
                PROGRAM_B
            )
        )

        client.load_program(
            program_b.words
        )

        check(
            "reload vuelve a READY",
            client.query_state()
            == ProcessorStatus.READY,
        )

        final_b = (
            client.run_and_snapshot(
                poll_interval=0.01,
                timeout=10.0,
            )
        )

        check(
            "B termina HALTED",
            final_b.status
            == ProcessorStatus.HALTED,
        )

        check(
            "B pipeline vacio",
            final_b.pipeline_empty,
        )

        check(
            "B x3 = 7",
            final_b.registers[3]
            == 7,
        )

        check(
            "B x4 = 9",
            final_b.registers[4]
            == 9,
        )

        check(
            "B x5 = 16",
            final_b.registers[5]
            == 16,
        )

        memory_b = (
            memory_dict(
                final_b
            )
        )

        check(
            "B DMEM[80] = 7",
            memory_b.get(80)
            == 7,
        )

        check(
            "B DMEM[84] = 9",
            memory_b.get(84)
            == 9,
        )

        check(
            "bitmap memoria usada "
            "se reinicio",
            64 not in memory_b,
        )

        # =====================================================
        # 13. ERRORES DE PROTOCOLO
        # =====================================================

        print()
        print(
            "=== ERRORES ==="
        )

        expect_nack(
            link,
            bytes([
                0x99,
            ]),
            ERR_UNKNOWN_COMMAND,
        )

        expect_nack(
            link,
            bytes([
                CMD_REG,
                32,
            ]),
            ERR_INVALID_ARGUMENT,
        )

        expect_nack(
            link,
            bytes([
                CMD_MEM,
                0x00,
                0x02,
            ]),
            ERR_INVALID_ADDRESS,
        )

        # Estamos HALTED.
        # RUN debe ser rechazado.

        try:

            client.run()

        except ProtocolNackError as exc:

            check(
                "RUN rechazado "
                "estando HALTED",
                exc.error_code
                == ERR_INVALID_STATE,
            )

        else:

            raise AssertionError(
                "RUN debio dar NACK05"
            )

        # LOAD con cantidad 0.
        #
        # El loader debe responder
        # ERR_LOAD.

        expect_nack(
            link,
            bytes([
                CMD_LOAD,
                0x00,
                0x00,
            ]),
            ERR_LOAD,
        )

        # =====================================================
        # 12. PROGRAMA REPRESENTATIVO
        #
        # Branch + loop + JAL + JALR.
        # =====================================================

        print()
        print(
            "=== CONTROL FLOW ==="
        )

        program_c = (
            assemble_program(
                PROGRAM_CONTROL
            )
        )

        client.load_program(
            program_c.words
        )

        final_c = (
            client.run_and_snapshot(
                poll_interval=0.01,
                timeout=10.0,
            )
        )

        check(
            "control termina HALTED",
            final_c.status
            == ProcessorStatus.HALTED,
        )

        check(
            "control pipeline vacio",
            final_c.pipeline_empty,
        )

        check(
            "BNE loop deja x1 = 0",
            final_c.registers[1]
            == 0,
        )

        check(
            "loop acumula x2 = 6",
            final_c.registers[2]
            == 6,
        )

        # jal esta en PC=20.
        # link = PC+4 = 24.

        check(
            "JAL link x3 = 24",
            final_c.registers[3]
            == 24,
        )

        check(
            "JAL elimina wrong path",
            final_c.registers[4]
            == 0,
        )

        # x6 = 41.
        #
        # JALR limpia bit 0:
        #
        # target = 40.

        check(
            "base JALR x6 = 41",
            final_c.registers[6]
            == 41,
        )

        # jalr esta en PC=32.
        # link = 36.

        check(
            "JALR link x7 = 36",
            final_c.registers[7]
            == 36,
        )

        check(
            "JALR elimina wrong path",
            final_c.registers[8]
            == 0,
        )

        check(
            "destino final x5 = 7",
            final_c.registers[5]
            == 7,
        )

        # =====================================================
        # 14. PROGRAMA SIN HALT
        #
        # Lo dejamos para el final porque
        # no existe comando STOP del core.
        # =====================================================

        print()
        print(
            "=== SIN HALT ==="
        )

        program_d = (
            assemble_program(
                PROGRAM_NO_HALT
            )
        )

        client.load_program(
            program_d.words
        )

        client.run()

        # Durante RUN solamente Q
        # está permitido.

        expect_nack(
            link,
            bytes([
                CMD_DEBUG,
            ]),
            ERR_INVALID_STATE,
        )

        state = (
            client.query_state()
        )

        check(
            "sin HALT sigue RUNNING",
            state
            == ProcessorStatus.RUNNING,
            f"estado={state.name}",
        )

        print()
        print("=" * 70)
        print(
            "PASS END-TO-END RTL"
        )
        print(
            "PC -> UART -> RTL -> "
            "pipeline -> UART -> PC"
        )
        print("=" * 70)

    finally:

        try:
            client.close()

        finally:
            STOP_FILE.touch()


if __name__ == "__main__":

    try:
        main()

    except KeyboardInterrupt:

        STOP_FILE.touch()

        print(
            "\nPrueba interrumpida"
        )

        sys.exit(130)

    except Exception:

        STOP_FILE.touch()

        raise
    