from __future__ import annotations

import errno
import fcntl
import os
import shutil
import sys
import tty
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer

from cocotb_vivado.runner import get_runner


ROOT = Path(__file__).resolve().parents[1]

RTL_DIR = ROOT / "rtl"
SIM_DIR = ROOT / "simulation"

BUILD_DIR = (
    SIM_DIR
    / "build"
    / "virtual_uart"
)

TOPLEVEL = (
    "processor_system_virtual_top"
)

TOP_FILE = (
    SIM_DIR
    / "processor_system_virtual_top.sv"
)

VIRTUAL_UART = Path(
    "/tmp/riscv_pipeline_uart"
)

STOP_FILE = (
    SIM_DIR
    / ".stop_virtual_uart"
)


# El wrapper usa:
#
# 1 MHz
# 62500 baud
#
# Cada bit dura exactamente 16 us.

BIT_TIME_US = 16

CLOCK_PERIOD_US = 1


def remove_if_exists(
    path: Path,
) -> None:

    try:
        path.unlink()

    except FileNotFoundError:
        pass


def set_nonblocking(
    fd: int,
) -> None:

    flags = fcntl.fcntl(
        fd,
        fcntl.F_GETFL,
    )

    fcntl.fcntl(
        fd,
        fcntl.F_SETFL,
        flags | os.O_NONBLOCK,
    )


def create_virtual_uart() -> tuple[
    int,
    int,
    str,
]:
    master_fd, slave_fd = (
        os.openpty()
    )

    slave_name = os.ttyname(
        slave_fd
    )

    tty.setraw(
        slave_fd
    )

    set_nonblocking(
        master_fd
    )

    remove_if_exists(
        VIRTUAL_UART
    )

    os.symlink(
        slave_name,
        VIRTUAL_UART,
    )

    return (
        master_fd,
        slave_fd,
        slave_name,
    )


async def send_uart_byte(
    dut,
    value: int,
) -> None:

    # START BIT
    dut.uart_rx.value = 0

    await Timer(
        BIT_TIME_US,
        unit="us",
    )

    # 8 DATA BITS - LSB FIRST
    for bit in range(8):

        dut.uart_rx.value = (
            value >> bit
        ) & 1

        await Timer(
            BIT_TIME_US,
            unit="us",
        )

    # STOP BIT
    dut.uart_rx.value = 1

    await Timer(
        BIT_TIME_US,
        unit="us",
    )


async def host_to_fpga(
    dut,
    master_fd: int,
) -> None:

    while True:

        try:
            data = os.read(
                master_fd,
                4096,
            )

        except BlockingIOError:
            data = b""

        except OSError as exc:

            if exc.errno in (
                errno.EIO,
                errno.EBADF,
            ):
                data = b""

            else:
                raise

        if not data:

            await Timer(
                100,
                unit="us",
            )

            continue

        for byte in data:

            await send_uart_byte(
                dut,
                byte,
            )


async def fpga_to_host(
    dut,
    master_fd: int,
) -> None:

    while True:

        # uart_tx = 1 durante IDLE.
        #
        # 1 -> 0 indica el comienzo
        # del START bit.

        await FallingEdge(
            dut.uart_tx
        )

        # Centro del bit 0:
        #
        # START completo = 16 us
        # medio DATA0    = 8 us

        await Timer(
            BIT_TIME_US
            + BIT_TIME_US // 2,
            unit="us",
        )

        value = 0

        for bit in range(8):

            if int(
                dut.uart_tx.value
            ):

                value |= (
                    1 << bit
                )

            await Timer(
                BIT_TIME_US,
                unit="us",
            )

        # Ahora estamos aproximadamente
        # en el centro del STOP bit.

        stop_bit = int(
            dut.uart_tx.value
        )

        if stop_bit != 1:

            dut._log.warning(
                "STOP UART invalido "
                "para byte 0x%02X",
                value,
            )

        try:
            os.write(
                master_fd,
                bytes([value]),
            )

        except OSError as exc:

            if exc.errno not in (
                errno.EIO,
                errno.EBADF,
            ):
                raise


@cocotb.test()
async def virtual_uart_bridge(
    dut,
) -> None:

    remove_if_exists(
        STOP_FILE
    )

    master_fd = -1
    slave_fd = -1

    dut.clk.value = 0
    dut.reset.value = 1
    dut.uart_rx.value = 1

    clock = Clock(
        dut.clk,
        CLOCK_PERIOD_US,
        unit="us",
    )

    cocotb.start_soon(
        clock.start()
    )

    try:

        (
            master_fd,
            slave_fd,
            slave_name,
        ) = create_virtual_uart()

        print()
        print("=" * 70)
        print(
            "UART VIRTUAL XSIM ACTIVA"
        )
        print(
            f"PTY Linux: {slave_name}"
        )
        print(
            f"Puerto estable: "
            f"{VIRTUAL_UART}"
        )
        print("=" * 70)
        print()

        # RESET GENERAL

        await Timer(
            12,
            unit="us",
        )

        dut.reset.value = 0

        await Timer(
            12,
            unit="us",
        )

        cocotb.start_soon(
            host_to_fpga(
                dut,
                master_fd,
            )
        )

        cocotb.start_soon(
            fpga_to_host(
                dut,
                master_fd,
            )
        )

        while not STOP_FILE.exists():

            await Timer(
                5,
                unit="ms",
            )

    finally:

        if VIRTUAL_UART.is_symlink():

            remove_if_exists(
                VIRTUAL_UART
            )

        if master_fd >= 0:

            try:
                os.close(
                    master_fd
                )
            except OSError:
                pass

        if slave_fd >= 0:

            try:
                os.close(
                    slave_fd
                )
            except OSError:
                pass


def require_vivado() -> None:

    missing = [
        command
        for command in (
            "xvlog",
            "xvhdl",
            "xelab",
        )
        if shutil.which(
            command
        ) is None
    ]

    if missing:

        raise RuntimeError(
            "No se encontraron: "
            + ", ".join(missing)
            + ". Carga settings64.sh "
            "de Vivado 2025.1."
        )


def main() -> None:

    require_vivado()

    BUILD_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    remove_if_exists(
        STOP_FILE
    )

    sources = sorted(
        RTL_DIR.glob("*.sv")
    )

    sources.append(
        TOP_FILE
    )

    runner = get_runner(
        "vivado"
    )

    print(
        "Compilando RTL con XSim..."
    )

    runner.build(
        sources=sources,
        hdl_toplevel=TOPLEVEL,
        build_dir=BUILD_DIR,
        timescale=(
            "1ns",
            "1ps",
        ),
    )

    python_path = str(ROOT)

    previous_path = os.environ.get(
        "PYTHONPATH",
        "",
    )

    if previous_path:

        python_path += (
            os.pathsep
            + previous_path
        )

    print(
        "Iniciando UART virtual..."
    )

    runner.test(
        hdl_toplevel=TOPLEVEL,
        hdl_toplevel_lang="verilog",
        test_module=(
            "simulation."
            "run_virtual_uart"
        ),
        testcase=(
            "virtual_uart_bridge"
        ),
        build_dir=BUILD_DIR,
        extra_env={
            "PYTHONPATH": python_path
        },
    )


if __name__ == "__main__":

    try:
        main()

    except KeyboardInterrupt:

        print(
            "\nSimulacion finalizada."
        )

        sys.exit(0)

