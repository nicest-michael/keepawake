# KeepAwake

> **Fixes the macOS 26 Tahoe lid-close login screen bug on Apple Silicon.**

A lightweight menu bar app that prevents your Mac from sleeping — and showing the lock screen — when you close and reopen the lid. One click to toggle. No configuration needed.

```
Menu bar:  ☕  ←→  💤
           ON       OFF
```

---

## The Problem

On **macOS 26 Tahoe with Apple Silicon** (M-series), closing the lid while plugged in still triggers the lock screen on wake — even with "Require password" set to a long delay or disabled entirely. This happens because:

1. IOKit `PreventSystemSleep` assertions are **silently ignored on battery** on Apple Silicon / macOS 26
2. The `lockoutagent` daemon enforces lock screen on sleep-wake events **regardless** of screensaver preferences
3. `pmset` reports the assertions as active but they have no effect

The only reliable fix is `sudo pmset -a disablesleep 1`, which prevents the sleep event entirely. KeepAwake handles this for you — including the privileged helper so you never have to type a password again after the first run.

---

## How It Works

| Layer | What it does |
|-------|-------------|
| `pmset -a disablesleep 1` | Prevents sleep at the OS level — no sleep = no lock screen |
| IOKit assertions | `PreventSystemSleep` + `PreventUserIdleDisplaySleep` + `NoIdleSleep` as belt-and-suspenders |
| Screensaver prefs | Sets `askForPassword = 0` and `askForPasswordDelay = 86400` while active, restores your originals on disable |
| Privileged helper | One-time admin prompt installs `/usr/local/bin/keepawake-helper` + `/etc/sudoers.d/keepawake` — passwordless forever after |

---

## Requirements

- macOS 26 Tahoe (Darwin 25+) — tested on M5 Pro, should work on any Apple Silicon Mac
- Xcode Command Line Tools (`xcode-select --install`) for building from source

---

## Install

### Build from source

```bash
git clone https://github.com/nicest-michael/keepawake.git
cd keepawake
./build.sh
```

`build.sh` compiles the Swift source, assembles `KeepAwake.app` in the repo folder (icon included), ad-hoc signs it, and launches it. Drag `KeepAwake.app` into `/Applications` to keep it around.

> **Why source-only?** The build is ad-hoc signed, not notarized, so a downloaded `.zip` would be blocked by Gatekeeper. Building from source sidesteps that entirely — locally-compiled apps aren't quarantined. (`KEEPAWAKE_NO_LAUNCH=1 ./build.sh` builds without launching.)

### First launch

On first run, KeepAwake prompts for your admin password **once** to install a privileged helper. After that, toggling sleep prevention is completely passwordless — even across reboots.

### Menu bar

- **💤** — sleep is allowed (default)
- **☕** — sleep is prevented

Click the icon → **Prevent Sleep** to toggle. The app lives in your menu bar only (no Dock icon).

---

## Uninstall

```bash
# Remove the app (wherever you put it)
rm -rf /Applications/KeepAwake.app

# Remove the privileged helper (optional)
sudo rm -f /usr/local/bin/keepawake-helper /etc/sudoers.d/keepawake
```

---

## Regenerate the icon

The repo ships a prebuilt `AppIcon.icns`, so a normal build needs no Python. The icon is a coffee cup rendered via Pillow — to regenerate it:

```bash
pip install pillow
python3 gen_icon.py
iconutil -c icns /tmp/KeepAwake.iconset -o AppIcon.icns
```

The next `./build.sh` picks up the new `AppIcon.icns` automatically.

---

## License

MIT — see [LICENSE](LICENSE)
