# Wizzo Server

A kneeboard for **Falcon BMS**, **DCS World** and **IL-2 Sturmovik: Great
Battles**, served over HTTP. Run it on the machine the games are installed on and
open the board on a tablet, phone or another PC. It reads the files the sim
writes, matches the charts, and rebuilds when you take a new mission.

Want a desktop window on the same PC instead? Use
**[Wizzo](https://github.com/CyberM00/wizzo)**, the packaged Windows app. Both
read the same files and show the same pages.

> **For a network you trust only.** No authentication, no TLS, no rate limiting,
> and it runs on Flask's development server. Anyone who can reach the port can
> read your route, target, loadout and frequencies. Never forward a port to it.
> See [Who else can reach it](#who-else-can-reach-it).

![The mission brief](docs/brief.png)

| | |
|---|---|
| ![Loadout](docs/loadout.png) | ![Steerpoints](docs/steer.png) |
| **Loadout** | **Steer** |

## Running it

Requires Python **3.10+** (CI tests 3.10 and 3.13 on Windows and Linux).

```bash
pip install -r requirements.txt
python wizzo.py
```

It prints a local address and a LAN address. Open the LAN one on your tablet and
press **F11** for fullscreen. It never opens a browser unless you pass `--browser`.

Run it **on the machine with the games**: it reads mission files, chart PDFs and
sim data straight off disk. A separate box only works if it can see the game
folders over a mount or share.

### Options

| Option | Effect |
|---|---|
| `--host` | Bind address (default `0.0.0.0`, all interfaces) |
| `--port` | Port (default `5000`) |
| `--bms-path`, `--dcs-path`, `--il2-path` | Override a game folder |
| `--browser` | Open a browser on this machine once serving |
| `--no-browser` | Accepted and ignored |
| `--log-file PATH` | Write output to a file instead of stdout (also `WIZZO_LOG`) |
| `--no-update` | Skip the self-update check |
| `--check-update` | Report whether an update is waiting, then exit |

| Environment variable | Effect |
|---|---|
| `BMS_PATH`, `DCS_PATH`, `IL2_PATH` | Game folders |
| `WIZZO_STATE_DIR` | Where settings and caches are written (default: beside the checkout) |
| `WIZZO_LOG` | Same as `--log-file` |

Set `WIZZO_STATE_DIR` if the checkout is read-only or replaced on deploy. The
caches rebuild, but a theatre's chart cache is slow to rebuild.

```bash
WIZZO_STATE_DIR=/var/lib/wizzo-server python wizzo.py
```

### Keeping it running

**Windows scheduled task** (starts at logon, restarts on failure, logs to
`%LOCALAPPDATA%\WizzoServer\wizzo.log`):

```bash
powershell -ExecutionPolicy Bypass -File deploy\install-task.ps1
```

Remove it with `Unregister-ScheduledTask -TaskName "Wizzo Server" -Confirm:$false`.

**Linux systemd.** Copy [`deploy/wizzo-server.service`](deploy/wizzo-server.service),
adjust the user and the three paths, then:

```bash
sudo systemctl enable --now wizzo-server
journalctl -u wizzo-server -f
```

**Docker** (only if the games are on storage the host can mount). Edit the three
paths in [`docker-compose.yml`](docker-compose.yml), then:

```bash
docker compose up -d
```

Game folders mount read-only. Settings and the chart cache live in a named
volume; keep it, or each theatre's chart is rebuilt after every restart.

The systemd unit and the container both run with `--no-update` and set
`WIZZO_STATE_DIR`.

### Who else can reach it

By default it serves on every interface, so anyone on the network can read your
mission. On a shared, work or public network, bind it to this machine:

```bash
python wizzo.py --host 127.0.0.1
```

- **Yes:** your own home network.
- **Yes:** bound to `127.0.0.1` and reached over a VPN or SSH tunnel.
- **No:** a forwarded port, a public IP, a cloud host.

No authentication is planned. It only ever reads; it cannot change game files.

## Game folders

All three sims are found automatically (BMS and DCS from the registry, IL-2 from
Steam's library list, then a scan of the usual folders).

If one is missed, the **Game folders** panel appears on first run, and later under
**Change game folders** on the Home page. Each row takes a path, **Find it**
(automatic) or **Not installed**. Changes apply immediately. Paths are typed (no
folder picker in this build).

A folder is accepted only if it contains `Data\TerrData` (BMS),
`Mods\terrains` (DCS) or `data\Swf.gtp` (IL-2).

Priority: command line, environment, saved setting, automatic discovery.

```bash
python wizzo.py --bms-path "D:\Falcon BMS 4.38"
```

## Updates

A **git clone** updates itself on every start: it fast-forwards from GitHub and
relaunches before serving. It skips the update, and says why, when there are
uncommitted changes, unpushed commits, or GitHub is unreachable. Only fast-forward
pulls are done. A copied (not cloned) folder shows `not auto-updating`.

If an update changes `requirements.txt`, run `pip install -r requirements.txt`
again. The version and commit are shown at the bottom of the sidebar.

## Using the board

The board opens on a **sim chooser** showing each sim's status and current
mission. Click one to pin the board to it, or cycle the button under the nav to
`(auto)` to follow whichever sim wrote a mission most recently. The board checks
for a new mission every two seconds.

| Page | Contents |
|---|---|
| **Home** | Sim chooser |
| **Brief** | Flight, package, TOT, target, situation, roster, ROE, emergency procedures |
| **Loadout** | Stores with weights, missile ranges and employment detail; laser-code panel |
| **Aircraft** | IL-2: limits, engine modes and settings from game data. BMS/DCS: the aircraft manual |
| **Steer** | Steerpoint table: time, distance, heading, CAS, altitude, action, formation |
| **Comms** | Comm ladder, UHF/VHF presets, IFF, Link 16 |
| **Threats** | Air and surface threats, support assets with TACAN channels |
| **Weather** | Conditions at takeoff, target and landing |
| **Charts** | Approach plates for departure, recovery, alternate and target fields; all KTO airfields browsable |
| **Maps** | BMS theatre maps; DCS and IL-2 charts with your route drawn on |

| Key | Action |
|---|---|
| `1`-`9` | Switch page |
| `H` | Sim chooser |
| `R` | Force reload |
| `T` | Toggle theme (Amber night / Paper day), stored per device |

Portrait screens get a top nav and a taller chart viewer.

## What each sim provides

### BMS

| Data | Source |
|---|---|
| Brief, steerpoints, comms, IFF, Link 16, weather, ordnance | `User\Briefings\briefing.txt` |
| UHF/VHF presets | `User\Briefings\dtc_comm.txt` |
| Weapon weights, missile ranges | `Data\TerrData\Objects\Falcon4_WCD.xml` |
| Approach plates, airfield diagrams | `Docs\03 KTO Charts\` |
| Theatre maps | `Docs\05 Maps\` |
| Employment guidance, fuzing, laser applicability | `bmskb/data/f16_stores.json` (curated) |

- Laser codes are entered by hand (BMS does not export them), validated as `1xyz`
  with each digit 1-8.
- Bomb ranges and guidance types are not shown from game data (WCD values are
  placeholders); the curated library covers them.
- Radio presets are flagged as stale if `dtc_comm.txt` and `briefing.txt` differ
  by more than five minutes.
- Tank weights are dry weights.
- Other theatres work if their `Docs` tree follows the same layout.
- Employment notes are planning guidance, not certified release tables.

### DCS support

Read from the mission `.miz`.

| Page | Contents |
|---|---|
| Brief | Briefing text, airframe, task, theatre, date, times, fuel, flares, chaff, gun |
| Loadout | Every station; employment detail for curated stores |
| Steer | Route with altitudes, speeds, ETAs, leg distance and bearing |
| Comms | Preset channels per radio, tanker and AWACS frequencies |
| Weather | Clouds, wind at three altitudes, visibility, temperature, QNH |
| Charts | Kneeboard pages embedded in the `.miz` (e.g. by Retribution) |
| Maps | The terrain's own raster chart (`Mods\terrains\<terrain>\RasterCharts`), cropped to the mission, with route, airfields and bullseye |
| Threats | Not shown |

- Weapon names are curated for the **F/A-18C, A-10C and AV-8B N/A** only; other
  stores show their raw CLSID.
- No weights, ranges or threat picture (DCS provides no reliable source).
- Wind is converted to "from" direction.
- Only tanker and AWACS groups are listed as support.
- Stitched charts are cached in `dcs_map_cache/`. If a chart cannot be placed or
  is missing, a land/water outline with a graticule is shown instead.

### IL-2 support

Career mode is fully supported; scripted DLC campaigns partially (briefing text,
briefing map and as-flown loadout only). PWCG missions are ignored.

| Page | Contents |
|---|---|
| Brief | Title, callsign, airframe, date, takeoff time, briefing, roster, fuel and ammo |
| Loadout | Store names from the game's own tables; planned vs as-flown |
| Steer | Route with altitudes, speeds, formations, leg distance and bearing (no ETAs) |
| Comms | Callsigns only |
| Weather | Five wind layers, clouds, temperature, pressure, haze, turbulence, sea state |
| Charts | Taxi diagrams for departure and recovery fields |
| Maps | The sim's planner map with your route |
| Threats | Not shown |

- Weapon names are cached in `il2_name_cache.json` and rebuild after a game patch.
- The as-flown loadout comes from `data\missionReport(...)[0].txt`, which needs
  `mission_text_log = 1` in `data\startup.cfg` (on by default).
- Weapon modifications and gun round counts are not shown. Wind direction is shown
  as the file states it.

## Development

```bash
pip install -r requirements.txt -r requirements-dev.txt
python -m pytest
```

Runtime dependencies are Flask and Pillow only; no GUI toolkit, so it runs
headless. Entry point is `wizzo.py`; the parsers live in `bmskb/` (`dcs/` and
`il2/` per sim). See [CONTRIBUTING.md](CONTRIBUTING.md).

## Support

If this saved you time, you can [buy me a coffee](https://ko-fi.com/cyberm00).
