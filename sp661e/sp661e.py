#!/usr/bin/env python3
"""CLI for controlling a BanlanX SP661E BLE LED controller over Bluetooth LE.

Built for the LANXEE 16.4ft COB under-cabinet lighting kit (2700K warm
white), whose bundled controller is an SP661E — one of the BanlanX SPxxxE
family of Bluetooth LE LED controllers normally driven by the BanlanX
phone app.

The SP661E's protocol has not been formally published. This tool speaks
the two reverse-engineered BanlanX BLE dialects documented by the UniLED
project (https://github.com/monty68/uniled):

  * "6xx" — the newer 0x53-header protocol used by the SP630E-generation
    controllers (SP631E..SP64AE). The SP661E's app UI matches this
    generation, so this is the default.
  * "v2"  — the older 0xA0-header protocol used by SP611E/SP617E/SP620E/
    SP621E, kept as a fallback (--protocol v2) in case the strip does not
    respond to the default.

Both dialects write plain (unencrypted, no checksum) packets to GATT
characteristic 0000ffe1-0000-1000-8000-00805f9b34fb.

Only one BLE central can hold the connection: force-quit the BanlanX app
(or disable the phone's Bluetooth) before running this, or the connection
will fail.

Usage examples:

    python sp661e.py scan
    python sp661e.py -a AA:BB:CC:DD:EE:FF on
    python sp661e.py -a AA:BB:CC:DD:EE:FF brightness 60
    python sp661e.py -a AA:BB:CC:DD:EE:FF fade --to 100 --duration 20
    python sp661e.py -a AA:BB:CC:DD:EE:FF effect 2 --speed 5
    python sp661e.py -a AA:BB:CC:DD:EE:FF status
    python sp661e.py -a AA:BB:CC:DD:EE:FF raw 51 01 ff

Requires: bleak (pip install bleak), Python 3.9+.
"""

from __future__ import annotations

import argparse
import asyncio
import sys

try:
    from bleak import BleakClient, BleakScanner
except ImportError:  # pragma: no cover
    sys.exit("bleak is required: pip install bleak")

WRITE_CHAR = "0000ffe1-0000-1000-8000-00805f9b34fb"

# Device names the BanlanX SPxxxE family advertises.
NAME_PREFIX = "SP"


# ---------------------------------------------------------------------------
# Protocol encoders (sources: UniLED banlanx_6xx.py and banlanx2.py)
# ---------------------------------------------------------------------------

def encode_6xx(cmd: int, data: bytes) -> bytes:
    """Newer BanlanX dialect: 53 <cmd> <key=00> 01 00 <len> <data...>.

    With key 0x00 the payload is sent in the clear — no XOR, no checksum.
    """
    return bytes([0x53, cmd & 0xFF, 0x00, 0x01, 0x00, len(data) & 0xFF]) + bytes(data)


def encode_v2(cmd: int, data: bytes) -> bytes:
    """Older BanlanX dialect: A0 <cmd> <len> <data...>."""
    return bytes([0xA0, cmd & 0xFF, len(data) & 0xFF]) + bytes(data)


def build_commands(protocol: str, action: str, args: argparse.Namespace) -> list[bytes]:
    """Return the packet sequence for an action under the chosen dialect."""
    if protocol == "6xx":
        if action == "on":
            return [encode_6xx(0x50, b"\x01")]
        if action == "off":
            return [encode_6xx(0x50, b"\x00")]
        if action == "brightness":
            level = pct_to_byte(args.percent)
            # which: 0x00 = color channel, 0x01 = white channel. The COB kit
            # is single-color (white); send both so it works either way the
            # firmware maps the channel.
            return [encode_6xx(0x51, bytes([0x01, level])),
                    encode_6xx(0x51, bytes([0x00, level]))]
        if action == "effect":
            packets = [encode_6xx(0x53, bytes([args.mode & 0xFF, args.number & 0xFF]))]
            if args.speed is not None:
                packets.append(encode_6xx(0x54, bytes([clamp(args.speed, 1, 10)])))
            return packets
        if action == "cct":
            return [encode_6xx(0x61, bytes([pct_to_byte(args.cold), pct_to_byte(args.warm)]))]
        if action == "status":
            return [encode_6xx(0x02, b"\x01")]
    elif protocol == "v2":
        if action == "on":
            return [encode_v2(0x62, b"\x01")]
        if action == "off":
            return [encode_v2(0x62, b"\x00")]
        if action == "brightness":
            level = pct_to_byte(args.percent)
            return [encode_v2(0x66, bytes([level])),
                    encode_v2(0x76, bytes([level, 0x00]))]
        if action == "effect":
            packets = [encode_v2(0x63, bytes([args.number & 0xFF]))]
            if args.speed is not None:
                packets.append(encode_v2(0x67, bytes([clamp(args.speed, 1, 10)])))
            return packets
        if action == "cct":
            raise SystemExit("cct is not available in the v2 dialect")
        if action == "status":
            raise SystemExit("status query is not documented for the v2 dialect; "
                             "use `raw` to experiment")
    raise SystemExit(f"unsupported action {action!r} for protocol {protocol!r}")


def pct_to_byte(percent: float) -> int:
    return clamp(round(clamp(percent, 0, 100) * 255 / 100), 0, 255)


def clamp(value, lo, hi):
    return max(lo, min(hi, value))


# ---------------------------------------------------------------------------
# BLE plumbing
# ---------------------------------------------------------------------------

async def scan(timeout: float) -> None:
    print(f"Scanning for {timeout:.0f}s ...")
    devices = await BleakScanner.discover(timeout=timeout, return_adv=True)
    found = False
    for device, adv in devices.values():
        name = device.name or adv.local_name or ""
        marker = " <-- likely your strip" if name.upper().startswith(NAME_PREFIX) else ""
        if name or marker:
            print(f"  {device.address}  rssi={adv.rssi:>4}  {name}{marker}")
            found = True
    if not found:
        print("No named BLE devices found. Make sure the strip is powered and the "
              "BanlanX app is fully closed (it holds the only BLE slot).")


async def send(address: str, packets: list[bytes], listen: bool) -> None:
    def on_notify(_char, data: bytearray) -> None:
        print(f"  reply: {data.hex(' ')}")

    async with BleakClient(address, timeout=20.0) as client:
        if listen:
            try:
                await client.start_notify(WRITE_CHAR, on_notify)
            except Exception:
                print("(notifications unavailable on this characteristic)")
        for packet in packets:
            print(f"  send:  {packet.hex(' ')}")
            await client.write_gatt_char(WRITE_CHAR, packet, response=False)
            await asyncio.sleep(0.15)
        if listen:
            await asyncio.sleep(2.0)


async def fade(address: str, protocol: str, start: float | None, end: float,
               duration: float, steps: int = 30) -> None:
    async with BleakClient(address, timeout=20.0) as client:
        ns = argparse.Namespace(percent=0)
        if start is None:
            start = 0.0
        step_delay = duration / max(steps, 1)
        for i in range(steps + 1):
            ns.percent = start + (end - start) * i / steps
            for packet in build_commands(protocol, "brightness", ns):
                await client.write_gatt_char(WRITE_CHAR, packet, response=False)
            await asyncio.sleep(step_delay)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Control a BanlanX SP661E BLE LED controller",
        epilog="Force-quit the BanlanX app first: the strip accepts only one BLE connection.")
    parser.add_argument("-a", "--address", help="BLE MAC address (from `scan`)")
    parser.add_argument("-p", "--protocol", choices=["6xx", "v2"], default="6xx",
                        help="BanlanX dialect (default: 6xx; try v2 if unresponsive)")
    sub = parser.add_subparsers(dest="action", required=True)

    p_scan = sub.add_parser("scan", help="discover nearby BLE devices")
    p_scan.add_argument("--timeout", type=float, default=8.0)

    sub.add_parser("on", help="power on")
    sub.add_parser("off", help="power off")

    p_bri = sub.add_parser("brightness", help="set brightness 0-100%%")
    p_bri.add_argument("percent", type=float)

    p_fx = sub.add_parser("effect", help="select an effect/mode")
    p_fx.add_argument("number", type=int, help="effect number (experiment: 1, 2, 3, ...)")
    p_fx.add_argument("--mode", type=int, default=3,
                      help="6xx light mode byte (default 3 = static white; try 4 for "
                           "dynamic white effects on a single-color strip)")
    p_fx.add_argument("--speed", type=int, help="effect speed 1-10")

    p_cct = sub.add_parser("cct", help="set warm/cold mix (CCT models, 6xx only)")
    p_cct.add_argument("--warm", type=float, default=100)
    p_cct.add_argument("--cold", type=float, default=0)

    p_fade = sub.add_parser("fade", help="fade brightness over time")
    p_fade.add_argument("--from", dest="start", type=float, default=None,
                        help="starting %% (default 0)")
    p_fade.add_argument("--to", type=float, required=True, help="target %%")
    p_fade.add_argument("--duration", type=float, default=10.0, help="seconds")

    sub.add_parser("status", help="request device state and print raw replies")

    p_raw = sub.add_parser("raw", help="send a raw command: <cmd-hex> [data-hex ...]")
    p_raw.add_argument("bytes", nargs="+", help="hex bytes, e.g. 51 01 ff")

    args = parser.parse_args()

    if args.action == "scan":
        asyncio.run(scan(args.timeout))
        return

    if not args.address:
        parser.error("this action requires -a/--address (run `scan` to find it)")

    if args.action == "fade":
        asyncio.run(fade(args.address, args.protocol, args.start, args.to, args.duration))
        print("Fade complete.")
        return

    if args.action == "raw":
        raw = [int(b, 16) for b in args.bytes]
        encoder = encode_6xx if args.protocol == "6xx" else encode_v2
        packets = [encoder(raw[0], bytes(raw[1:]))]
    else:
        packets = build_commands(args.protocol, args.action, args)

    asyncio.run(send(args.address, packets, listen=(args.action in ("status", "raw"))))
    print("Done.")


if __name__ == "__main__":
    main()
