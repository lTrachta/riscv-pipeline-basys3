from __future__ import annotations

import asyncio
from pathlib import Path

from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import (
    Button,
    DataTable,
    Footer,
    Header,
    Input,
    RichLog,
    Select,
    Static,
    TextArea,
)

from .assembler import AssemblerError, HALT_INSTRUCTION, assemble_program
from .models import AssembledProgram, ProcessorStatus, Snapshot
from .protocol import (
    ProcessorClient,
    ProtocolError,
    ProtocolNackError,
)
from .serial_link import SerialLink, SerialLinkError
from .snapshot import SnapshotError
from .transport import TransportError


DEFAULT_SOURCE = """.text
.globl _start

_start:
    addi x1, x0, 10
    addi x2, x0, 20
    add  x3, x1, x2
    HALT
"""


def format_user_error(operation: str, exc: Exception) -> str:
    """Convierte excepciones internas en mensajes claros para la TUI."""

    if isinstance(exc, AssemblerError):
        return f"{operation}: error de assembler: {exc}"

    if isinstance(exc, ProtocolNackError):
        return f"{operation}: la FPGA rechazó la operación: {exc}"

    if isinstance(exc, SnapshotError):
        return f"{operation}: snapshot inválido: {exc}"

    if isinstance(exc, (SerialLinkError, TransportError, TimeoutError)):
        return f"{operation}: error UART: {exc}"

    if isinstance(exc, ProtocolError):
        return f"{operation}: error de protocolo: {exc}"

    if isinstance(exc, OSError):
        return f"{operation}: error de archivo: {exc}"

    if isinstance(exc, ValueError):
        return f"{operation}: dato inválido: {exc}"

    if isinstance(exc, RuntimeError):
        return f"{operation}: {exc}"

    return (
        f"{operation}: error inesperado "
        f"({type(exc).__name__}): {exc}"
    )


def source_instruction_text(
    program: AssembledProgram | None,
    address: int,
    *,
    valid: bool = True,
) -> str:
    """Devuelve la instrucción fuente asociada a un PC del snapshot."""

    if not valid:
        return "<burbuja>"

    if program is None:
        return "<programa no disponible>"

    instruction = program.instruction_at(address)

    if instruction is None:
        return "<fuera del programa>"

    return f"L{instruction.line_number}: {instruction.text}"


class PipelineDebuggerApp(App[None]):
    TITLE = "RISC-V Pipeline Debugger"
    SUB_TITLE = "UART 115200 8N1"

    CSS = """
    Screen {
        layout: vertical;
    }

    #connection-row, #control-row, #file-row {
        height: auto;
        padding: 0 1;
    }

    #main-row {
        height: 1fr;
    }

    #left-panel {
        width: 2fr;
    }

    #center-panel {
        width: 2fr;
    }

    #right-panel {
        width: 2fr;
    }

    #source {
        height: 1fr;
        border: round $accent;
    }

    #pipeline {
        height: 1fr;
        border: round $accent;
        padding: 1;
    }

    #registers, #memory {
        height: 1fr;
        border: round $accent;
    }

    #log {
        height: 8;
        border: round $accent;
    }

    #status {
        height: 3;
        border: round $accent;
        padding: 0 1;
    }

    Select {
        width: 1fr;
    }

    Input {
        width: 1fr;
    }

    Button {
        margin: 0 1;
    }
    """

    BINDINGS = [
        ("ctrl+q", "quit", "Salir"),
        ("f5", "step", "STEP"),
        ("f6", "run_program", "RUN"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.link: SerialLink | None = None
        self.client: ProcessorClient | None = None
        self.current_program: AssembledProgram | None = None
        self.last_snapshot: Snapshot | None = None
        self.cycle_count = 0
        self.busy = False

    def compose(self) -> ComposeResult:
        yield Header()

        with Horizontal(id="connection-row"):
            yield Select(
                [("Sin puertos", "")],
                id="port-select",
                allow_blank=False,
            )
            yield Button("Refrescar", id="refresh-ports")
            yield Button("Conectar", id="connect", variant="primary")
            yield Button("Desconectar", id="disconnect")

        with Horizontal(id="file-row"):
            yield Input(
                placeholder="Ruta opcional a un archivo .S",
                id="source-path",
            )
            yield Button("Abrir .S", id="open-source")

        yield Static("Estado: DISCONNECTED", id="status")

        with Horizontal(id="main-row"):
            with Vertical(id="left-panel"):
                yield Static("PROGRAMA")
                yield TextArea(
                    DEFAULT_SOURCE,
                    id="source",
                    soft_wrap=False,
                    show_line_numbers=True,
                )

            with Vertical(id="center-panel"):
                yield Static("PIPELINE")
                yield Static("Sin snapshot", id="pipeline")
                yield Static("MEMORIA USADA")
                yield DataTable(id="memory")

            with Vertical(id="right-panel"):
                yield Static("REGISTROS")
                yield DataTable(id="registers")

        with Horizontal(id="control-row"):
            yield Button("LOAD", id="load", variant="primary")
            yield Button("STEP", id="step")
            yield Button("RUN", id="run", variant="success")
            yield Button("SNAPSHOT", id="snapshot")
            yield Button("Q", id="query")

        yield RichLog(id="log", wrap=True, highlight=True)
        yield Footer()

    def on_mount(self) -> None:
        registers = self.query_one("#registers", DataTable)
        registers.cursor_type = "row"
        registers.add_columns("Reg", "Hex", "Dec")

        memory = self.query_one("#memory", DataTable)
        memory.cursor_type = "row"
        memory.add_columns("Dirección", "Valor")

        self.refresh_ports()
        self.add_log("Aplicación iniciada")

    def add_log(self, message: str) -> None:
        self.query_one("#log", RichLog).write(message)

    def set_status(self, text: str) -> None:
        self.query_one("#status", Static).update(text)

    def refresh_ports(self) -> None:
        select = self.query_one("#port-select", Select)

        try:
            ports = SerialLink.list_ports()
        except SerialLinkError as exc:
            self.add_log(str(exc))
            select.set_options([("Sin puertos", "")])
            return

        if not ports:
            select.set_options([("Sin puertos detectados", "")])
            return

        select.set_options(
            [
                (
                    f"{port.device} - {port.description}" if port.description else port.device,
                    port.device,
                )
                for port in ports
            ]
        )
        self.add_log(f"Puertos detectados: {len(ports)}")

    def require_client(self) -> ProcessorClient:
        if self.client is None:
            raise RuntimeError("primero conectá un puerto serie")
        return self.client

    def set_busy(self, value: bool) -> None:
        self.busy = value
        for button_id in ("load", "step", "run", "snapshot", "query"):
            self.query_one(f"#{button_id}", Button).disabled = value

    def on_button_pressed(self, event: Button.Pressed) -> None:
        button_id = event.button.id

        if button_id == "refresh-ports":
            self.refresh_ports()
            return

        if button_id == "connect":
            self.connect_selected_port()
            return

        if button_id == "disconnect":
            self.disconnect()
            return

        if button_id == "open-source":
            self.open_source_file()
            return

        if self.busy:
            self.add_log("Hay una operación en curso")
            return

        if button_id == "load":
            self.run_worker(self.load_program_action(), exclusive=True)
        elif button_id == "step":
            self.run_worker(self.step_action(), exclusive=True)
        elif button_id == "run":
            self.run_worker(self.run_program_action(), exclusive=True)
        elif button_id == "snapshot":
            self.run_worker(self.snapshot_action(), exclusive=True)
        elif button_id == "query":
            self.run_worker(self.query_action(), exclusive=True)

    def action_step(self) -> None:
        if not self.busy:
            self.run_worker(self.step_action(), exclusive=True)

    def action_run_program(self) -> None:
        if not self.busy:
            self.run_worker(self.run_program_action(), exclusive=True)

    def connect_selected_port(self) -> None:
        select = self.query_one("#port-select", Select)
        value = select.value

        if value is Select.NULL or not value:
            self.add_log("No hay un puerto seleccionado")
            return

        self.disconnect(log_message=False)

        try:
            self.link = SerialLink(str(value))
            self.client = ProcessorClient(self.link)
        except Exception as exc:
            self.link = None
            self.client = None
            self.add_log(format_user_error("CONNECT", exc))
            self.set_status("Estado: DISCONNECTED")
            return

        self.add_log(f"Conectado a {value} @ 115200 8N1")
        self.set_status(f"Puerto: {value} | Estado: CONNECTED")

    def disconnect(
        self,
        *,
        log_message: bool = True,
        update_ui: bool = True,
    ) -> None:
        if self.client is not None:
            try:
                self.client.close()
            except Exception:
                pass

        self.client = None
        self.link = None

        if update_ui:
            self.set_status("Estado: DISCONNECTED")

            if log_message:
                self.add_log("Puerto desconectado")

    def open_source_file(self) -> None:
        path_text = self.query_one("#source-path", Input).value.strip()
        if not path_text:
            self.add_log("Ingresá una ruta a un archivo .S")
            return

        try:
            source = Path(path_text).read_text(encoding="utf-8")
        except OSError as exc:
            self.add_log(format_user_error("ABRIR .S", exc))
            return

        text_area = self.query_one("#source", TextArea)
        text_area.load_text(source)
        self.add_log(f"Archivo abierto: {path_text}")

    async def load_program_action(self) -> None:
        self.set_busy(True)
        try:
            client = self.require_client()
            source = self.query_one("#source", TextArea).text
            program = assemble_program(source)

            await asyncio.to_thread(client.load_program, program.words)

            self.current_program = program
            self.last_snapshot = None
            self.cycle_count = 0
            self.clear_snapshot_view()
            self.add_log(
                f"Programa cargado: {len(program.instructions)} instrucciones"
            )
            self.set_status("Estado: READY | Ciclo: 0")
        except Exception as exc:
            self.add_log(format_user_error("LOAD", exc))
        finally:
            self.set_busy(False)

    async def step_action(self) -> None:
        self.set_busy(True)
        try:
            client = self.require_client()
            snapshot = await asyncio.to_thread(client.step_and_snapshot)
            self.cycle_count += 1
            self.render_snapshot(snapshot)
            self.add_log(f"STEP completado - ciclo {self.cycle_count}")
        except Exception as exc:
            self.add_log(format_user_error("STEP", exc))
        finally:
            self.set_busy(False)

    async def snapshot_action(self) -> None:
        self.set_busy(True)
        try:
            client = self.require_client()
            snapshot = await asyncio.to_thread(client.debug_snapshot)
            self.render_snapshot(snapshot)
            self.add_log("Snapshot recibido")
        except Exception as exc:
            self.add_log(format_user_error("SNAPSHOT", exc))
        finally:
            self.set_busy(False)

    async def query_action(self) -> None:
        self.set_busy(True)
        try:
            client = self.require_client()
            state = await asyncio.to_thread(client.query_state)
            self.set_status(
                f"Estado: {state.name} | Ciclo STEP: {self.cycle_count}"
            )
            self.add_log(f"Q -> {state.name}")
        except Exception as exc:
            self.add_log(format_user_error("Q", exc))
        finally:
            self.set_busy(False)

    async def run_program_action(self) -> None:
        self.set_busy(True)
        try:
            client = self.require_client()

            if (
                self.current_program is not None
                and HALT_INSTRUCTION not in self.current_program.words
            ):
                self.add_log(
                    "ADVERTENCIA: el programa cargado no contiene HALT; "
                    "RUN puede continuar indefinidamente"
                )

            await asyncio.to_thread(client.run)
            self.add_log("RUN iniciado")
            self.set_status("Estado: RUNNING")

            last_state: ProcessorStatus | None = None

            while True:
                await asyncio.sleep(0.05)
                state = await asyncio.to_thread(client.query_state)

                if state != last_state:
                    self.add_log(f"Estado -> {state.name}")
                    last_state = state

                self.set_status(f"Estado: {state.name}")

                if state == ProcessorStatus.HALTED:
                    break

                if state == ProcessorStatus.ERROR:
                    raise RuntimeError("el procesador informó estado ERROR")

            snapshot = await asyncio.to_thread(client.debug_snapshot)
            self.render_snapshot(snapshot)
            self.add_log("RUN finalizado - snapshot final recibido")
        except Exception as exc:
            self.add_log(format_user_error("RUN", exc))
        finally:
            self.set_busy(False)

    def clear_snapshot_view(self) -> None:
        self.query_one("#pipeline", Static).update("Sin snapshot")
        self.query_one("#registers", DataTable).clear()
        self.query_one("#memory", DataTable).clear()

    def render_snapshot(self, snapshot: Snapshot) -> None:
        self.last_snapshot = snapshot
        self.set_status(
            " | ".join(
                [
                    f"Estado: {snapshot.status.name}",
                    f"IF PC: 0x{snapshot.if_pc:08X}",
                    f"Pipeline vacío: {'sí' if snapshot.pipeline_empty else 'no'}",
                    f"Ciclo STEP: {self.cycle_count}",
                ]
            )
        )

        pipeline_text = self.format_pipeline(snapshot)
        self.query_one("#pipeline", Static).update(pipeline_text)

        registers = self.query_one("#registers", DataTable)
        registers.clear()
        for index, value in enumerate(snapshot.registers):
            signed = value if value < 0x80000000 else value - 0x1_0000_0000
            registers.add_row(
                f"x{index}",
                f"0x{value:08X}",
                str(signed),
            )

        memory = self.query_one("#memory", DataTable)
        memory.clear()
        for entry in snapshot.used_memory:
            memory.add_row(
                f"0x{entry.address:04X}",
                f"0x{entry.value:08X}",
            )

    def format_pipeline(self, snapshot: Snapshot) -> str:
        def validity(value: bool) -> str:
            return "VALID" if value else "BUBBLE"

        def source(pc: int, *, valid: bool = True) -> str:
            return source_instruction_text(
                self.current_program,
                pc,
                valid=valid,
            )

        lines = [
            f"IF      PC=0x{snapshot.if_pc:08X}",
            f"        {source(snapshot.if_pc)}",
            "",
            (
                f"IF/ID   {validity(snapshot.if_id.valid)} "
                f"PC=0x{snapshot.if_id.pc:08X} "
                f"INST=0x{snapshot.if_id.instruction:08X}"
            ),
            f"        {source(snapshot.if_id.pc, valid=snapshot.if_id.valid)}",
            "",
            (
                f"ID/EX   {validity(snapshot.id_ex.valid)} "
                f"PC=0x{snapshot.id_ex.pc:08X} "
                f"rs1=x{snapshot.id_ex.rs1} rs2=x{snapshot.id_ex.rs2} "
                f"rd=x{snapshot.id_ex.rd}"
            ),
            f"        {source(snapshot.id_ex.pc, valid=snapshot.id_ex.valid)}",
            (
                f"        imm=0x{snapshot.id_ex.immediate:08X} "
                f"op=0x{snapshot.id_ex.opcode:02X} "
                f"ctrl=0x{snapshot.id_ex.control:04X}"
            ),
            "",
            (
                f"EX/MEM  {validity(snapshot.ex_mem.valid)} "
                f"PC=0x{snapshot.ex_mem.pc:08X} "
                f"ALU=0x{snapshot.ex_mem.alu_result:08X} "
                f"rd=x{snapshot.ex_mem.rd}"
            ),
            f"        {source(snapshot.ex_mem.pc, valid=snapshot.ex_mem.valid)}",
            (
                f"        STORE=0x{snapshot.ex_mem.store_data:08X} "
                f"ctrl=0x{snapshot.ex_mem.control:02X}"
            ),
            "",
            (
                f"MEM/WB  {validity(snapshot.mem_wb.valid)} "
                f"PC=0x{snapshot.mem_wb.pc:08X} "
                f"ALU=0x{snapshot.mem_wb.alu_result:08X} "
                f"rd=x{snapshot.mem_wb.rd}"
            ),
            f"        {source(snapshot.mem_wb.pc, valid=snapshot.mem_wb.valid)}",
            (
                f"        LOAD=0x{snapshot.mem_wb.load_data:08X} "
                f"ctrl=0x{snapshot.mem_wb.control:02X}"
            ),
        ]

        return "\n".join(lines)

    def on_unmount(self) -> None:
        self.disconnect(log_message=False, update_ui=False)


def main() -> None:
    PipelineDebuggerApp().run()


if __name__ == "__main__":
    main()
