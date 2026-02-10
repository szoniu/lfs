# CLAUDE.md — Kontekst projektu dla Claude Code

## Co to jest

Interaktywny TUI installer Linux From Scratch w Bashu. Cel: boot z dowolnego live ISO, sklonować repo, `./install.sh` — i zostać przeprowadzonym przez kompilację i instalację pełnego systemu LFS od zera.

Kluczowa różnica vs inne installery: LFS kompiluje WSZYSTKO ze źródeł (toolchain, ~80 pakietów Chapter 8, kernel). Czas instalacji: 4-12+ godzin. Brak package managera — czysta edukacyjna dystrybucja.

LFS wersja: **12.4**, kernel **6.16.1**.

## Architektura

### Model: outer process + chroot

1. Wizard TUI → konfiguracja
2. Partycjonowanie dysku
3. Pobranie i weryfikacja źródeł (~1 GB)
4. Toolchain pass 1 + pass 2 (cross-compilation)
5. Temporary tools (chroot preparation)
6. Wejście do chroot → final system (~80 pakietów)
7. System config + kernel + bootloader + użytkownicy
8. Finalizacja

### Struktura plików

```
install.sh              — Entry point, parsowanie argumentów, orchestracja
configure.sh            — Wrapper: exec install.sh --configure

lib/
├── protection.sh       — Guard: sprawdza $_LFS_INSTALLER
├── constants.sh        — Stałe: LFS_VERSION, ścieżki, CONFIG_VARS[], CHECKPOINTS[]
├── logging.sh          — elog/einfo/ewarn/eerror/die/die_trace, kolory, log do pliku
├── utils.sh            — try (interaktywne recovery), checkpoint_set/reached, is_root/is_efi/has_network, check_host_versions
├── dialog.sh           — Wrapper dialog/whiptail, primitives (msgbox/yesno/menu/radiolist/checklist/gauge/inputbox/passwordbox), wizard runner
├── config.sh           — config_save/load/set/get (${VAR@Q} quoting)
├── hardware.sh         — detect_cpu/gpu/disks/esp, CPU march detection
├── disk.sh             — Dwufazowe: disk_plan → disk_execute_plan, mount/unmount_filesystems
├── network.sh          — Konfiguracja sieci (static IP / DHCP)
├── sources.sh          — Pobranie wget-list + md5sums, weryfikacja, ekstrakcja
├── toolchain.sh        — Chapter 5: cross-compilation (binutils, gcc pass1/2, glibc, libstdc++)
├── temptools.sh        — Chapter 6-7: temporary tools (m4, ncurses, bash, coreutils...)
├── chroot.sh           — LFS user, chroot_setup/teardown/exec, virtual kernel FS
├── finalsystem.sh      — Chapter 8: ~80 pakietów w kolejności zależności
├── system.sh           — Chapter 9: bootscripts, timezone, locale, hostname, fstab
├── kernel.sh           — Chapter 10: kompilacja kernela (defconfig/custom/file)
├── bootloader.sh       — GRUB (x86_64-efi), dual-boot z os-prober
├── desktop.sh          — Framework na pakiety BLFS (post-boot)
├── swap.sh             — zram / partition / file / none
├── hooks.sh            — maybe_exec 'before_X' / 'after_X'
└── preset.sh           — preset_export/import (hardware overlay)

tui/
├── welcome.sh          — screen_welcome: branding + prereq check (root, UEFI, sieć, host tools)
├── preset_load.sh      — screen_preset_load: skip/file/browse
├── hw_detect.sh        — screen_hw_detect: detect_all_hardware + summary
├── disk_select.sh      — screen_disk_select: dysk + scheme (auto/dual-boot/manual)
├── filesystem_select.sh — screen_filesystem_select: ext4/btrfs/xfs + btrfs subvolumes
├── swap_config.sh      — screen_swap_config: zram/partition/file/none
├── network_config.sh   — screen_network_config: hostname
├── locale_config.sh    — screen_locale_config: timezone + locale + keymap
├── kernel_config.sh    — screen_kernel_config: defconfig/custom/file
├── gpu_config.sh       — screen_gpu_config: wykryty GPU + info
├── user_config.sh      — screen_user_config: root pwd, user, grupy, SSH
├── extra_packages.sh   — screen_extra_packages: notatki o pakietach BLFS
├── preset_save.sh      — screen_preset_save: opcjonalny eksport
└── summary.sh          — screen_summary: pełne podsumowanie + "YES" + countdown

tui/progress.sh         — screen_progress: gauge + fazowa instalacja (14 faz)

data/
├── cpu_march_database.sh — CPU_MARCH_MAP[vendor:family:model] → -march flag
└── gpu_database.sh     — GPU PCI IDs → rekomendacja sterownika

presets/                — base-ext4.conf, base-btrfs.conf, dualboot-windows.conf
hooks/                  — before_install.sh.example
tests/                  — test_config.sh, test_disk.sh, shellcheck.sh
```

### Konwencje ekranów TUI

Każdy ekran to funkcja `screen_*()` która zwraca:
- `0` (`TUI_NEXT`) — dalej
- `1` (`TUI_BACK`) — cofnij
- `2` (`TUI_ABORT`) — przerwij

`run_wizard()` w `lib/dialog.sh` zarządza indeksem ekranu na podstawie return code.

### Konwencje zmiennych konfiguracyjnych

Wszystkie zmienne konfiguracyjne zdefiniowane w `CONFIG_VARS[]` w `lib/constants.sh`. Kluczowe:
- `TARGET_DISK` — /dev/sda, /dev/nvme0n1
- `PARTITION_SCHEME` — auto/dual-boot/manual
- `FILESYSTEM` — ext4/btrfs/xfs
- `SWAP_TYPE` — zram/partition/file/none
- `KERNEL_CONFIG` — defconfig/custom/ścieżka do .config
- `MAKEFLAGS` — -j${CPU_CORES}

### 14 faz instalacji (checkpointy)

1. `preflight` — root, UEFI, sieć, wersje narzędzi hosta
2. `disks` — partycjonowanie + formatowanie + montowanie
3. `sources` — pobranie + weryfikacja MD5 + ekstrakcja
4. `toolchain_pass1` — binutils, gcc (cross-compile)
5. `toolchain_pass2` — gcc pass 2, glibc, libstdc++
6. `temptools` — m4, ncurses, bash, coreutils (do chroota)
7. `chroot_prep` — virtual kernel FS, wejście do chroot
8. `finalsystem_libs` — biblioteki systemowe
9. `finalsystem_tools` — narzędzia systemowe
10. `finalsystem_system` — reszta Chapter 8
11. `system_config` — bootscripts, timezone, locale, hostname, fstab
12. `kernel` — kompilacja Linux 6.16.1
13. `bootloader` — GRUB EFI
14. `users` — hasła, konta, grupy

### Dwufazowe operacje dyskowe

1. `disk_plan_auto()` / `disk_plan_dualboot()` — buduje `DISK_ACTIONS[]`
2. `disk_execute_plan()` — iteruje i wykonuje przez `try`

### Funkcja `try`

`try "opis" polecenie args...` — na błędzie wyświetla menu Retry/Shell/Continue/Log/Abort. Każde polecenie które może się nie udać MUSI iść przez `try`.

### Checkpointy

`checkpoint_set "nazwa"` tworzy plik w `$CHECKPOINT_DIR`. `checkpoint_reached "nazwa"` sprawdza. Pozwala wznowić po awarii (4-12h build!).

### Różnice vs Gentoo/NixOS/Chimera installer

| | LFS | Gentoo | NixOS | Chimera |
|---|-----|--------|-------|---------|
| Bootstrap | ze źródeł | stage3 | nixos-install | chimera-bootstrap |
| Pkg mgr | brak | emerge | nix | apk |
| Kompilacja | wszystko | wszystko | nic (binarne) | nic (binarne) |
| Czas | 4-12h | 3-8h | ~15-30 min | ~15-30 min |
| Toolchain | budowany od zera | prebuilt | prebuilt | prebuilt |
| Init | SysVinit | systemd/OpenRC | systemd | dinit |
| Desktop | BLFS (post-boot) | KDE w installerze | configuration.nix | apk add |

## Uruchamianie testów

```bash
bash tests/test_config.sh      # Config round-trip
bash tests/test_disk.sh        # Disk planning dry-run
bash tests/shellcheck.sh       # Lint (wymaga shellcheck)
```

Wszystkie testy standalone — nie wymagają root ani hardware. Używają `DRY_RUN=1` i `NON_INTERACTIVE=1`.

## Znane wzorce i pułapki

- `(( var++ ))` przy var=0 zwraca exit 1 pod `set -e` → zawsze dodawać `|| true`
- `lib/constants.sh` używa `: "${VAR:=default}"` zamiast `readonly` żeby testy mogły nadpisywać
- `lib/protection.sh` sprawdza `$_LFS_INSTALLER` — testy muszą to exportować
- `config_save` używa `${VAR@Q}` (bash 4.4+) do bezpiecznego quotingu
- Dialog: `2>&1 >/dev/tty` (dialog) vs `3>&1 1>&2 2>&3` (whiptail) — oba obsłużone w `lib/dialog.sh`
- Pliki lib/ NIGDY nie są uruchamiane bezpośrednio — zawsze sourcowane
- LFS buduje toolchain jako user `lfs` (nie root!) — `chroot.sh` tworzy tego usera
- `$LFS` to mount point (/mnt/lfs) — wszystkie ścieżki build relative do niego
- `$LFS_TGT` = `$(uname -m)-lfs-linux-gnu` — triplet cross-compilacji

## Jak dodawać nowy ekran TUI

1. Utwórz `tui/nowy_ekran.sh` z funkcją `screen_nowy_ekran()`
2. Dodaj `source "${TUI_DIR}/nowy_ekran.sh"` w `install.sh`
3. Dodaj `screen_nowy_ekran` do `register_wizard_screens` w `run_configuration_wizard()`
4. Ekran musi zwracać `TUI_NEXT`/`TUI_BACK`/`TUI_ABORT`

## Jak dodawać nową zmienną konfiguracyjną

1. Dodaj nazwę do `CONFIG_VARS[]` w `lib/constants.sh`
2. Ustaw wartość w odpowiednim ekranie TUI + `export`
3. Użyj w odpowiednim module `lib/`

## Jak dodawać nową fazę instalacji

1. Dodaj checkpoint name do `CHECKPOINTS[]` w `lib/constants.sh`
2. Dodaj logikę w odpowiednim module lib/ lub w `tui/progress.sh`
3. Opatrz blok `if ! checkpoint_reached "nazwa"; then ... checkpoint_set "nazwa"; fi`
