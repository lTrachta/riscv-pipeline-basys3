from __future__ import annotations

import unittest
from pathlib import Path

from software.assembler import (
    AssemblerError,
    HALT_INSTRUCTION,
    assemble,
    assemble_program,
)


class AssemblerTests(unittest.TestCase):
    def test_basic_program(self) -> None:
        source = """
        .text
        .globl _start
        _start:
            addi x1, x0, 10
            addi x2, x0, 20
            add  x3, x1, x2
            HALT
        """

        self.assertEqual(
            assemble(source),
            [
                0x00A00093,
                0x01400113,
                0x002081B3,
                HALT_INSTRUCTION,
            ],
        )

    def test_backward_label(self) -> None:
        source = """
        addi x1, x0, 3
        loop:
            addi x1, x1, -1
            bne x1, x0, loop
            HALT
        """
        program = assemble_program(source)

        self.assertEqual(program.labels["loop"], 4)
        self.assertEqual(program.words[2], 0xFE009EE3)

    def test_forward_label(self) -> None:
        source = """
            beq x1, x2, target
            addi x3, x0, 99
        target:
            HALT
        """
        words = assemble(source)
        self.assertEqual(words[0], 0x00208463)

    def test_word_and_halt(self) -> None:
        self.assertEqual(assemble(".word 0x0000000b"), [HALT_INSTRUCTION])
        self.assertEqual(assemble("HALT"), [HALT_INSTRUCTION])

    def test_invalid_register(self) -> None:
        with self.assertRaisesRegex(AssemblerError, "x32"):
            assemble("add x32, x1, x2")

    def test_unsupported_instruction(self) -> None:
        with self.assertRaisesRegex(AssemblerError, "no soportada"):
            assemble("mul x1, x2, x3")

    def test_immediate_out_of_range(self) -> None:
        with self.assertRaisesRegex(AssemblerError, "fuera de rango"):
            assemble("addi x1, x2, 9000")

    def test_duplicate_label(self) -> None:
        source = """
        loop:
            addi x1, x0, 1
        loop:
            HALT
        """
        with self.assertRaisesRegex(AssemblerError, "duplicado"):
            assemble(source)

    def test_empty_program(self) -> None:
        with self.assertRaisesRegex(AssemblerError, "no contiene instrucciones"):
            assemble(".text\n.globl _start\n")

    def test_program_too_large(self) -> None:
        source = "\n".join("addi x1, x0, 0" for _ in range(257))
        with self.assertRaisesRegex(AssemblerError, "demasiado grande"):
            assemble(source)

    def test_existing_integrated_programs_match_hex(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        program_dir = repo_root / "programs" / "integrated_verification"

        if not program_dir.exists():
            self.skipTest("programs/integrated_verification no está disponible")

        names = [
            "alu_immediates",
            "hazards",
            "integration",
            "memory",
        ]

        for name in names:
            with self.subTest(program=name):
                source = (program_dir / f"{name}.S").read_text(encoding="utf-8")
                expected = [
                    int(line.strip(), 16)
                    for line in (program_dir / f"{name}.hex")
                    .read_text(encoding="utf-8")
                    .splitlines()
                    if line.strip()
                ]
                self.assertEqual(assemble(source), expected)

    def test_control_flow_source_uses_real_label_addresses(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        program_dir = repo_root / "programs" / "integrated_verification"
        source_path = program_dir / "control_flow.S"

        if not source_path.exists():
            self.skipTest("control_flow.S no está disponible")

        program = assemble_program(source_path.read_text(encoding="utf-8"))

        # Los dos branches no tomados del .hex histórico usan offsets
        # arbitrarios cortos. El assembler nuevo resuelve los labels reales
        # escritos al final del .S.
        self.assertEqual(program.instructions[6].word, 0x04209263)
        self.assertEqual(program.instructions[12].word, 0x02208663)

        # Los saltos que sí forman parte del flujo esperado coinciden con
        # las palabras históricas conocidas.
        self.assertEqual(program.instructions[2].word, 0x00208663)
        self.assertEqual(program.instructions[9].word, 0x00209663)
        self.assertEqual(program.instructions[14].word, 0x00C0036F)
        self.assertEqual(program.instructions[18].word, 0x00238467)


if __name__ == "__main__":
    unittest.main()
