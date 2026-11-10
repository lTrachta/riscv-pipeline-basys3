from __future__ import annotations

import unittest

from textual.widgets import Static

from software.app import (
    PipelineDebuggerApp,
    format_user_error,
    source_instruction_text,
)
from software.assembler import AssemblerError, assemble_program
from software.models import (
    ExMemState,
    IdExState,
    IfIdState,
    MemWbState,
    ProcessorStatus,
    Snapshot,
    SnapshotFlags,
)
from software.protocol import ProtocolNackError
from software.serial_link import SerialLinkError
from software.snapshot import SnapshotError


class AppTests(unittest.IsolatedAsyncioTestCase):
    async def test_app_mount_and_unmount(self) -> None:
        app = PipelineDebuggerApp()

        async with app.run_test(size=(140, 45)) as pilot:
            status = app.query_one("#status", Static)
            self.assertIsNotNone(status)
            await pilot.pause()

    def test_does_not_shadow_textual_internal_methods(self) -> None:
        self.assertNotIn("log", PipelineDebuggerApp.__dict__)
        self.assertNotIn("run_action", PipelineDebuggerApp.__dict__)

    def test_source_instruction_text(self) -> None:
        program = assemble_program(
            """
            addi x1, x0, 10
            addi x2, x0, 20
            add  x3, x1, x2
            HALT
            """
        )

        self.assertIn("addi x1, x0, 10", source_instruction_text(program, 0))
        self.assertIn("add  x3, x1, x2", source_instruction_text(program, 8))
        self.assertEqual(
            source_instruction_text(program, 4, valid=False),
            "<burbuja>",
        )
        self.assertEqual(
            source_instruction_text(program, 0x100),
            "<fuera del programa>",
        )

    def test_pipeline_view_maps_pcs_to_source(self) -> None:
        program = assemble_program(
            """
            addi x1, x0, 1
            addi x2, x0, 2
            add  x3, x1, x2
            sw   x3, 0(x0)
            HALT
            """
        )

        snapshot = Snapshot(
            version=1,
            status=ProcessorStatus.READY,
            flags=SnapshotFlags(0x01),
            if_pc=16,
            registers=tuple(0 for _ in range(32)),
            if_id=IfIdState(True, 12, program.instructions[3].word),
            id_ex=IdExState(
                True, 8, 0, 0, 0, 1, 2, 3, 0x33, 0, 0, 0
            ),
            ex_mem=ExMemState(
                True, 4, 0, 0, 0, 2, 0x13, 0, 0
            ),
            mem_wb=MemWbState(
                True, 0, 0, 0, 1, 0x13, 0
            ),
            used_memory=(),
        )

        app = PipelineDebuggerApp()
        app.current_program = program
        text = app.format_pipeline(snapshot)

        self.assertIn("HALT", text)
        self.assertIn("sw   x3, 0(x0)", text)
        self.assertIn("add  x3, x1, x2", text)
        self.assertIn("addi x2, x0, 2", text)
        self.assertIn("addi x1, x0, 1", text)

    def test_error_messages_are_classified(self) -> None:
        cases = [
            (AssemblerError("registro inválido"), "assembler"),
            (ProtocolNackError(0x05), "FPGA rechazó"),
            (SnapshotError("tag inválido"), "snapshot inválido"),
            (SerialLinkError("puerto cerrado"), "UART"),
            (TimeoutError("sin respuesta"), "UART"),
            (ValueError("dato malo"), "dato inválido"),
        ]

        for exc, expected in cases:
            with self.subTest(exc=type(exc).__name__):
                self.assertIn(expected, format_user_error("TEST", exc))


if __name__ == "__main__":
    unittest.main()
