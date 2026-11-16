# Installing Gnomad on an FM-1 (no app needed)

You need an M-VAVE FM-1, a USB data cable and a computer with Chrome or Edge (the browser installer), or
Python 3 (the command-line installer). Installing takes about a minute.

**Installing custom firmware is at your own risk.** Before you start, read "Going back" below, so you know
what's proven and what isn't.

## What has been tested

| | Status |
|---|---|
| Installing with `tools/fm1_install.py` on a **Mac** | **Proven** many times, on a real FM-1, across every Gnomad build so far, including installing an older build back over a newer one. |
| `fm1_install.py` on **Linux** or **Windows** | **Not tested by us.** It's the same Python script and the same MIDI library, so it should work. Please tell us if it does or doesn't. |
| Going back to **M-VAVE's stock firmware** | **Not proven on real hardware yet.** See the warning below. |
| Going back to **Felucca** | **Not tested by us.** |

## The easy way: from the browser

Open **<https://kpalaniuk.github.io/gnomad-firmware/>** in Chrome or Edge, connect the FM-1 by USB, press
**Install** and allow MIDI when the browser asks. Don't unplug the FM-1 while it writes. That's all.

It's Felucca's own web installer (`web/index_pkg.html`, `web/fm1ota.js`), the same update protocol as
`fm1_install.py`, with this release's package built in. The page is made by
`.github/workflows/build-and-pages.yml`: GitHub builds the package from this source with The Firmware Hub's
shared workflow ([zvenson/fm1-build](https://github.com/zvenson/fm1-build)), which attests it, and the build must
have the release's SHA-256 (`8bab81bb…`), byte for byte, before the page is published. To check the package
yourself:

```
gh attestation verify gnomad-v1-115e11e.fwsc --repo kpalaniuk/gnomad-firmware \
  --signer-workflow zvenson/fm1-build/.github/workflows/build.yml
```

It also works over Gnomad, and the page's "Return to official V15" finds an FM-1 that runs Gnomad
(its port is named "Gnomad Synth V1"). Safari and Firefox have no Web MIDI with SysEx: use the steps below.

## The command line: Python

## 1. Get the files

- The package `gnomad-v1-115e11e.fwsc` comes from this repository's **Releases** page. Check its SHA-256 against
  the release's `SHA256SUMS`:
  `8bab81bb3cf3a197a7f9c7a4b07ae962a45a2ae90b85bd88ae267fc2a707d052`
  ```
  shasum -a 256 gnomad-v1-115e11e.fwsc          # macOS / Linux
  certutil -hashfile gnomad-v1-115e11e.fwsc SHA256   # Windows
  ```
- The installer is [`tools/fm1_install.py`](tools/fm1_install.py) in this repository. It's Felucca's
  command-line installer, GPL-3.0, © Leo Kuroshita / Hügelton Instruments, unchanged.

## 2. Set up Python (once)

macOS / Linux:
```
python3 -m venv ~/gnomad-venv
source ~/gnomad-venv/bin/activate
pip install mido python-rtmidi
```

Windows (PowerShell):
```
py -3 -m venv $HOME\gnomad-venv
$HOME\gnomad-venv\Scripts\Activate.ps1
pip install mido python-rtmidi
```

On Linux, `python-rtmidi` may first need ALSA's development package (for example `libasound2-dev`) if pip has
to build it.

## 3. Check the synth is seen

Connect the FM-1 by USB, switch it on, and close every other app that might be using it (DAWs, editors,
the Gnomad app). Then run:

```
python3 tools/fm1_install.py --info
```

It prints the FM-1's identity and the port it found, for example `FM-1_015  [running]  port: ...` on stock
firmware (`FM-1_900` once Gnomad is on it). If it says the FM-1 wasn't found, it also lists the MIDI inputs it
can see. Then:

- Check the cable. A charge-only cable won't work.
- **If the FM-1 already runs Gnomad**, add `--port Gnomad`. Gnomad's USB port is named "Gnomad Synth V1", and
  by default the script only looks for ports whose names contain FM-1, Felucca, OTA, composite, sinco or
  usb-midi. `--port NAME` picks the port that has NAME in its name.

## 4. Install

```
python3 tools/fm1_install.py gnomad-v1-115e11e.fwsc
```

The script asks `Install? ... [y/N]`. Type `y`. **Don't unplug the FM-1 while it writes.** The script starts
the update, the FM-1 switches to its update loader, the package is written, the FM-1 restarts, and the
script ends with `done: the FM-1 runs FM-1_900`.

To install over an earlier Gnomad build, add `--port Gnomad`:
```
python3 tools/fm1_install.py --port Gnomad gnomad-v1-115e11e.fwsc
```

These are all the options the script has (from its own `--help`):

| Option | What it does |
|---|---|
| `PACKAGE.fwsc` | the package to install |
| `--info` | print the identity of the connected FM-1 and stop |
| `--port NAME` | use the MIDI port whose name contains NAME |
| `--yes` | don't ask for confirmation |
| `--force` | install a package that has no Felucca loader marker (you don't need this for Gnomad) |

If an install is cut off (for example the cable came out), plug back in and run the same command again. The
script sees that the FM-1 is still in update mode and finishes the write.

Exit codes: 0 done; 1 cancelled or another error; 2 bad arguments or package; 3 FM-1 not found; 4 connection
lost; 5 timeout; 6 wrong model, or a different identity after the install.

## Can I use Felucca's web installer instead?

Felucca's own page installs only the Felucca package it was built with. Use Gnomad's page above: it is the
same installer, made with `web/make_site.py --name Gnomad` around Gnomad's package.

---

## Going back: to M-VAVE's stock firmware, or to Felucca

> **⚠ Warning: going back to stock has NOT been proven on real hardware yet.** Installing Gnomad with
> `fm1_install.py` is proven. Going *from* Gnomad back to M-VAVE's V15 is a different step, and nobody has
> done it on a real FM-1 yet. A test on a spare FM-1 is planned. Until it's done, treat the steps below as
> what we expect to work from reading the code, not as a guarantee. If you aren't comfortable with that
> risk, wait for the test result. It will be posted in this repository.

**Before you go back:** going back erases what Gnomad saved on the FM-1, which means your songs, the 32 user
sounds, the 4 projects, the 3 sample slots and your settings. `fm1_install.py` does not back them up.
M-VAVE's firmware can't open Gnomad or Felucca music anyway.

### Back to M-VAVE stock (V15)

1. Download the official `FM-1.fwsc` (V15) from M-VAVE: <https://www.m-vave.com/download>. We can't include
   it here, because it's M-VAVE's copyrighted file.
2. Check it. The installer accepts the stock file only if it is the **unmodified** V15 file, with this SHA-256:
   `db1642b2b6fa5c2cccb11ffd13878068bb28601678d3644049f99dc40e7edb8a`
3. With the FM-1 running Gnomad:
   ```
   python3 tools/fm1_install.py --port Gnomad FM-1.fwsc
   ```
   This is the way back that Felucca's installer itself supports: "the official V15 file: back to the stock
   firmware", from the script's own help. It's allowed without `--force` because the file matches the
   official SHA-256.

Felucca's web page also has a "Return to official V15" button, and it makes a full backup first. But from its
code, it only looks for ports named FM-1, Felucca, OTA and similar, and Gnomad's port is "Gnomad Synth V1",
so we expect it **not to find** an FM-1 that runs Gnomad. Not tested. M-VAVE's own updater app: not tested
with Gnomad.

### Back to Felucca

Download `felucca-1.0.1.fwsc` from [Felucca's releases](https://github.com/hugelton/Felucca/releases) and run:
```
python3 tools/fm1_install.py --port Gnomad felucca-1.0.1.fwsc
```
This is the same script and the same kind of package as a Gnomad install. **Not tested by us.**

### If the FM-1 won't start at all

Felucca's update loader is what writes every Gnomad install, and Gnomad doesn't change it. If a build can't
start, Felucca's boot guard sends the FM-1 to its built-in update mode after two failed starts within 30
seconds. From there, recovery needs [FM-1-transporter](https://github.com/kurogedelic/FM-1-transporter) by
Leo Kuroshita, which uses a small extra board. That's Felucca's documented recovery path (see
[BUILDING.md](BUILDING.md)). We haven't needed it, and we haven't tested it.
