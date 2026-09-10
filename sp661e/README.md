# sp661e — scripting the under-cabinet lights

CLI for the **BanlanX SP661E** Bluetooth LE controller that ships with the
LANXEE 16.4ft COB under-cabinet lighting kit (2700K warm white). Lets you
control the strip from a laptop or Raspberry Pi instead of the BanlanX
phone app — and therefore schedule it with cron.

## How it works

The SP661E is Bluetooth-LE-only (no WiFi, no cloud API). Its exact
protocol isn't published, but the BanlanX SPxxxE family has been
reverse-engineered by the [UniLED](https://github.com/monty68/uniled)
Home Assistant project. All of them accept plain command packets on GATT
characteristic `0000ffe1-0000-1000-8000-00805f9b34fb`, in one of two
dialects:

| Dialect | Header | Used by | Notes |
|---------|--------|---------|-------|
| `6xx` (default) | `0x53` | SP630E-generation (SP631E–SP64AE) | Matches the app UI the SP661E uses — most likely correct |
| `v2` | `0xA0` | SP611E / SP617E / SP620E / SP621E | Fallback: `--protocol v2` |

Since the SP661E itself is undocumented, the `6xx` default is an educated
guess. If the strip ignores commands, retry with `--protocol v2`; the
`raw` and `status` subcommands print every reply byte to help probe.

## Setup

Needs a machine with a Bluetooth radio in range of the strip (Linux,
macOS, or Windows — a Raspberry Pi in the kitchen is ideal).

```sh
pip install -r requirements.txt
```

**Important:** the controller accepts only one BLE connection. Force-quit
the BanlanX app on your phone (or toggle the phone's Bluetooth off)
before running the script.

## Usage

```sh
python sp661e.py scan                       # find the strip's MAC address
python sp661e.py -a <MAC> on
python sp661e.py -a <MAC> off
python sp661e.py -a <MAC> brightness 60     # percent
python sp661e.py -a <MAC> fade --to 100 --duration 30
python sp661e.py -a <MAC> effect 2 --mode 4 --speed 5   # "flow" effects
python sp661e.py -a <MAC> status            # dump raw state reply
python sp661e.py -a <MAC> raw 51 01 ff      # hand-craft a command
```

On macOS, `scan` prints a UUID instead of a MAC address — use that as the
address.

## Scheduling (cron)

On a Pi or always-on machine, `crontab -e`:

```cron
# fade up to full at 6:30am on weekdays
30 6 * * 1-5  cd /home/pi/sp661e && python sp661e.py -a AA:BB:CC:DD:EE:FF fade --to 100 --duration 60
# dim to 20% at 9pm, off at midnight
0 21 * * *    cd /home/pi/sp661e && python sp661e.py -a AA:BB:CC:DD:EE:FF brightness 20
0 0  * * *    cd /home/pi/sp661e && python sp661e.py -a AA:BB:CC:DD:EE:FF off
```

## Home Assistant instead?

If you run Home Assistant with a Bluetooth adapter (or an ESPHome
Bluetooth proxy), install [UniLED](https://github.com/monty68/uniled) via
HACS — it auto-discovers BanlanX controllers and exposes the strip as a
light entity with brightness and effects, which is nicer for automations
than cron. An SP661E owner has reported it being discovered
([issue #94](https://github.com/monty68/uniled/issues/94)), though the
model isn't officially on the supported list yet.

## Protocol reference (as implemented)

`6xx` dialect — packet is `53 <cmd> 00 01 00 <len> <data…>`:

| Command | Bytes |
|---------|-------|
| Power | `0x50` → `01`/`00` |
| Brightness | `0x51` → `<channel 00=color/01=white> <0-255>` |
| Light mode + effect | `0x53` → `<mode> <effect>` |
| Effect speed | `0x54` → `<1-10>` |
| CCT mix | `0x61` → `<cold 0-255> <warm 0-255>` |
| State query | `0x02` → `01` |

`v2` dialect — packet is `A0 <cmd> <len> <data…>`:

| Command | Bytes |
|---------|-------|
| Power | `0x62` → `01`/`00` |
| Brightness | `0x66` → `<0-255>` |
| White level | `0x76` → `<0-255> 00` |
| Effect | `0x63` → `<effect>` |
| Effect speed | `0x67` → `<1-10>` |

Command tables derived from UniLED's `banlanx_6xx.py` and `banlanx2.py`.
