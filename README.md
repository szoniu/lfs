# LFS TUI Installer

Interaktywny installer Linux From Scratch z interfejsem TUI (dialog). Przeprowadza za rękę przez cały proces — od partycjonowania dysku po działający system LFS 12.4 skompilowany ze źródeł.

W przeciwieństwie do Gentoo/NixOS/Chimera — tu kompilujesz WSZYSTKO od zera: toolchain, ~80 pakietów bazowych, kernel. Pełna edukacyjna dystrybucja. Czas instalacji: 4-12+ godzin (zależy od CPU).

## Krok po kroku

### 1. Przygotuj bootowalny pendrive

Potrzebujesz dowolnego live ISO z Linuxem, który ma wymagane narzędzia (bash 3.2+, gcc, make, bison, dialog, git, parted, wget). Rekomendowane:

- **Gentoo LiveGUI** — ma wszystko out of the box
- **Fedora Live** — `dnf install dialog git parted`
- **Ubuntu Live** — `apt install dialog git parted build-essential bison`

Nagraj na pendrive:

```bash
# UWAGA: /dev/sdX to pendrive, nie dysk systemowy!
sudo dd if=live-iso.iso of=/dev/sdX bs=4M status=progress
sync
```

Na Windows: [Rufus](https://rufus.ie) lub [balenaEtcher](https://etcher.balena.io).

### 2. Bootuj z pendrive

- BIOS/UEFI: F2, F12, lub Del przy starcie
- **Wyłącz Secure Boot**
- Boot z USB w trybie **UEFI**

### 3. Połącz się z internetem

#### Kabel LAN

Powinno działać od razu:

```bash
ping -c 3 linuxfromscratch.org
```

#### WiFi

**`nmcli`** (NetworkManager):

```bash
nmcli device wifi list
nmcli device wifi connect "NazwaSieci" password "TwojeHaslo"
```

**`iwctl`** (iwd):

```bash
iwctl
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "NazwaSieci"
exit
```

Sprawdź: `ping -c 3 linuxfromscratch.org`

### 4. Sprawdź wymagania hosta

LFS wymaga konkretnych wersji narzędzi na hoście. Installer sprawdzi to automatycznie, ale możesz też ręcznie:

```bash
# Na Fedora/RHEL:
sudo dnf install bash binutils bison coreutils diffutils findutils \
  gawk gcc glibc grep gzip m4 make patch perl python3 sed tar \
  texinfo xz dialog git parted wget

# Na Ubuntu/Debian:
sudo apt install build-essential bison gawk texinfo dialog git parted wget
```

### 5. Sklonuj repo i uruchom

```bash
sudo su
git clone https://github.com/szoniu/lfs.git
cd lfs
./install.sh
```

Albo bez git:

```bash
sudo su
curl -L https://github.com/szoniu/lfs/archive/main.tar.gz | tar xz
cd lfs-main
./install.sh
```

### 6. Po instalacji

Po zakończeniu installer zapyta o reboot. Wyjmij pendrive — zobaczysz GRUB, potem konsolę LFS.

LFS to system bazowy (bez GUI). Żeby mieć desktop:
- Zainstaluj pakiety z [BLFS](https://www.linuxfromscratch.org/blfs/) (Beyond LFS)
- Skrypty pomocnicze w `/root/blfs-scripts/`

## Alternatywne uruchomienie

```bash
./install.sh                    # Pełna instalacja (wizard + install)
./install.sh --configure        # Tylko wizard (generuje config)
./install.sh --config plik.conf --install   # Z gotowego configa
./install.sh --dry-run          # Symulacja bez dotykania dysków
```

## Wymagania

- Komputer z **UEFI** (nie Legacy BIOS)
- **Secure Boot wyłączony**
- Minimum **30 GiB** wolnego miejsca na dysku
- Internet (LAN lub WiFi) — do pobrania ~1 GB źródeł
- Live ISO z Linuxem z wymaganymi narzędziami (bash, gcc, make, bison, dialog, git, parted, wget)

## Co robi installer

14 ekranów TUI prowadzi przez konfigurację:

| # | Ekran | Co konfigurujesz |
|---|-------|-------------------|
| 1 | Welcome | Sprawdzenie wymagań (root, UEFI, sieć, wersje narzędzi hosta) |
| 2 | Preset | Opcjonalne załadowanie gotowej konfiguracji |
| 3 | Hardware | Podgląd wykrytego CPU, GPU, dysków, Windows |
| 4 | Dysk | Wybór dysku + schemat (auto/dual-boot/manual) |
| 5 | Filesystem | ext4 / btrfs (ze snapshotami) / XFS |
| 6 | Swap | zram (domyślnie) / partycja / plik / brak |
| 7 | Sieć | Hostname |
| 8 | Locale | Timezone, język, keymap |
| 9 | Kernel | defconfig (szybki) / custom (menuconfig) / plik .config |
| 10 | GPU | Podgląd wykrytego GPU |
| 11 | Użytkownicy | Hasło root, konto użytkownika, grupy, SSH |
| 12 | Pakiety | Notatki o pakietach BLFS do zainstalowania post-boot |
| 13 | Preset save | Opcjonalny eksport konfiguracji |
| 14 | Podsumowanie | Pełny przegląd + potwierdzenie "YES" + countdown |

Po potwierdzeniu installer przechodzi przez 14 faz:

1. Preflight checks
2. Partycjonowanie + formatowanie dysku
3. Pobranie i weryfikacja ~1 GB źródeł (wget-list + md5sums)
4. Toolchain pass 1 (cross-compilation: binutils, gcc)
5. Toolchain pass 2 (gcc, glibc, libstdc++)
6. Temporary tools (m4, ncurses, bash, coreutils...)
7. Przygotowanie chroota (virtual kernel FS)
8. Final system: biblioteki
9. Final system: narzędzia
10. Final system: reszta (~80 pakietów Chapter 8)
11. Konfiguracja systemu (bootscripts, timezone, locale, hostname, fstab)
12. Kompilacja kernela Linux 6.16.1
13. Instalacja GRUB (EFI)
14. Utworzenie użytkowników + finalizacja

## Dual-boot z Windows

- Auto-wykrywanie ESP z Windows Boot Manager
- ESP nigdy nie jest formatowany przy reuse
- GRUB + os-prober automatycznie widzi Windows

Wystarczy wybrać "Dual-boot with Windows" w ekranie partycjonowania.

## Presety

```
presets/base-ext4.conf          # Minimalna instalacja + ext4
presets/base-btrfs.conf         # Btrfs ze snapshotami
presets/dualboot-windows.conf   # Dual-boot z Windows
```

Presety przenośne — wartości sprzętowe re-wykrywane przy imporcie.

## Co jeśli coś pójdzie nie tak

- **Błąd podczas kompilacji** — menu: Retry / Shell / Continue / Log / Abort. Możesz wejść do shella, naprawić problem i wrócić.
- **Przerwa w prądzie / reboot** — checkpointy po każdej fazie. Uruchom ponownie — wznowi od ostatniego ukończonego kroku. Kluczowe przy 4-12h instalacji!
- **Log** — pełny log: `/tmp/lfs-installer.log`
- **Coś jest nie tak z konfiguracją** — `./install.sh --configure` żeby przejść wizarda ponownie

## Hooki (zaawansowane)

```bash
cp hooks/before_install.sh.example hooks/before_install.sh
chmod +x hooks/before_install.sh
# Edytuj hook...
```

Dostępne hooki: `before_install`, `after_install`, `before_disks`, `after_disks`, `before_kernel`, `after_kernel`, itd.

## Opcje CLI

```
./install.sh [OPCJE] [POLECENIE]

Polecenia:
  (domyślnie)      Pełna instalacja (wizard + install)
  --configure       Tylko wizard konfiguracyjny
  --install         Tylko instalacja (wymaga configa)

Opcje:
  --config PLIK     Użyj podanego pliku konfiguracji
  --dry-run         Symulacja bez destrukcyjnych operacji
  --force           Kontynuuj mimo nieudanych prereq
  --non-interactive Przerwij na każdym błędzie (bez recovery menu)
  --help            Pokaż pomoc
```

## Testy

```bash
bash tests/test_config.sh      # Config round-trip
bash tests/test_disk.sh        # Disk planning dry-run
bash tests/shellcheck.sh       # Lint (wymaga shellcheck)
```

## Struktura

```
install.sh              — Główny entry point
configure.sh            — Wrapper: tylko wizard
lfs.conf.example        — Przykładowa konfiguracja z komentarzami

lib/                    — Moduły biblioteczne (sourcowane, nie uruchamiane)
tui/                    — Ekrany TUI (każdy = funkcja, return 0/1/2)
data/                   — Bazy danych (CPU march, GPU)
presets/                — Gotowe presety
hooks/                  — Hooki (*.sh.example)
tests/                  — Testy
```

## Różnice vs inne installery

| | LFS | Gentoo | NixOS | Chimera |
|---|-----|--------|-------|---------|
| Czas | 4-12h | 3-8h | ~15-30 min | ~15-30 min |
| Kompilacja | wszystko od zera | ze źródeł (z cache) | binarne | binarne |
| Pkg manager | brak | emerge | nix | apk |
| Init | SysVinit | systemd/OpenRC | systemd | dinit |
| Desktop | BLFS (post-boot) | w installerze | w installerze | w installerze |
| Toolchain | budowany od zera | prebuilt (stage3) | prebuilt | prebuilt |
| Rollback | brak (btrfs snapshots) | brak | wbudowany | btrfs snapshots |

## FAQ

**P: Jak długo trwa instalacja?**
Zależy od CPU. Na nowoczesnym 8-core: ~4-6h. Na starszym 4-core: 8-12h. Większość czasu to kompilacja GCC i Chapter 8 packages.

**P: Mogę na VM?**
Tak, UEFI mode. VirtualBox: Settings → System → Enable EFI. Przydziel minimum 4 CPU cores i 4 GB RAM żeby kompilacja nie trwała wieczność.

**P: Po co budować LFS skoro są binarne dystrybucje?**
Edukacja. LFS uczy jak Linux działa od środka — toolchain, init, kernel, bootloader. Po zbudowaniu LFS rozumiesz każdy pakiet w systemie.

**P: Co po instalacji? Nie ma GUI!**
LFS to system bazowy z konsolą. Desktop (X11/Wayland, KDE, Firefox...) instalujesz z [BLFS](https://www.linuxfromscratch.org/blfs/). Installer zostawia notatki w `/root/blfs-scripts/`.

**P: Jakie live ISO jest najlepsze?**
Gentoo LiveGUI — ma wszystkie wymagane narzędzia. Fedora/Ubuntu też działają po doinstalowaniu `build-essential`/`@development-tools`, `dialog`, `git`, `parted`.

**P: Co jeśli kompilacja się wysypie w połowie?**
Checkpointy. Installer zapamiętuje ukończone fazy i wznawia od ostatniej. Możesz też wejść do shella z recovery menu, naprawić problem i kontynuować.
