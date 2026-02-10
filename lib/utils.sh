#!/usr/bin/env bash
# utils.sh — Utility functions: try (interactive recovery), countdown, dependency checks
source "${LIB_DIR}/protection.sh"

# try — Execute a command with interactive recovery on failure
# Usage: try "description" command [args...]
try() {
    local desc="$1"
    shift

    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        einfo "[DRY-RUN] Would execute: $*"
        return 0
    fi

    while true; do
        einfo "Running: ${desc}"
        elog "Command: $*"

        if "$@" >> "${LOG_FILE}" 2>&1; then
            einfo "Success: ${desc}"
            return 0
        fi

        local exit_code=$?
        eerror "Failed (exit ${exit_code}): ${desc}"
        eerror "Command: $*"

        if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
            die "Non-interactive mode — aborting on failure: ${desc}"
        fi

        local choice
        choice=$(dialog_menu "Command Failed: ${desc}" \
            "retry"    "Retry the command" \
            "shell"    "Drop to a shell (type 'exit' to return)" \
            "continue" "Skip this step and continue" \
            "log"      "View last 50 lines of log" \
            "abort"    "Abort installation") || choice="abort"

        case "${choice}" in
            retry)
                ewarn "Retrying: ${desc}"
                continue
                ;;
            shell)
                ewarn "Dropping to shell. Type 'exit' to return to installer."
                PS1="(lfs-installer rescue) \w \$ " bash --norc --noprofile || true
                continue
                ;;
            continue)
                ewarn "Skipping: ${desc} (user chose to continue)"
                return 0
                ;;
            log)
                dialog_textbox "Log Output" "${LOG_FILE}" || true
                continue
                ;;
            abort)
                die "Aborted by user after failure: ${desc}"
                ;;
        esac
    done
}

# countdown — Display a countdown timer
# Usage: countdown <seconds> <message>
countdown() {
    local seconds="${1:-${COUNTDOWN_DEFAULT}}"
    local msg="${2:-Continuing in}"

    if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
        return 0
    fi

    local i
    for ((i = seconds; i > 0; i--)); do
        printf "\r%s %d seconds... " "${msg}" "${i}" >&2
        sleep 1
    done
    printf "\r%s\n" "$(printf '%-60s' '')" >&2
}

# check_dependencies — Verify required tools are available
check_dependencies() {
    local -a missing=()
    local dep

    local -a required_deps=(
        bash
        gcc
        g++
        make
        bison
        gawk
        m4
        patch
        tar
        xz
        wget
        mkfs.ext4
        mkfs.vfat
        parted
        mount
        umount
        blkid
        lsblk
        chroot
    )

    for dep in "${required_deps[@]}"; do
        if ! command -v "${dep}" &>/dev/null; then
            missing+=("${dep}")
        fi
    done

    # dialog or whiptail
    if ! command -v dialog &>/dev/null && ! command -v whiptail &>/dev/null; then
        missing+=("dialog|whiptail")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        eerror "Missing required dependencies:"
        local m
        for m in "${missing[@]}"; do
            eerror "  - ${m}"
        done
        return 1
    fi

    einfo "All dependencies satisfied"
    return 0
}

# check_host_versions — Verify host system meets LFS requirements
check_host_versions() {
    einfo "Checking host system tool versions..."

    local ok=1

    # Bash >= 3.2
    local bash_ver
    bash_ver=$(bash --version | head -1 | grep -oP '\d+\.\d+')
    einfo "  Bash: ${bash_ver}"

    # GCC >= 5.2
    if command -v gcc &>/dev/null; then
        local gcc_ver
        gcc_ver=$(gcc --version | head -1 | grep -oP '\d+\.\d+' | head -1)
        einfo "  GCC: ${gcc_ver}"
    else
        eerror "  GCC: not found"
        ok=0
    fi

    # Make >= 4.0
    if command -v make &>/dev/null; then
        local make_ver
        make_ver=$(make --version | head -1 | grep -oP '\d+\.\d+' | head -1)
        einfo "  Make: ${make_ver}"
    else
        eerror "  Make: not found"
        ok=0
    fi

    # Perl >= 5.8.8
    if command -v perl &>/dev/null; then
        local perl_ver
        perl_ver=$(perl -V:version 2>/dev/null | grep -oP "'[\d.]+'") || perl_ver="unknown"
        einfo "  Perl: ${perl_ver}"
    fi

    # Python 3
    if command -v python3 &>/dev/null; then
        local py_ver
        py_ver=$(python3 --version 2>&1 | awk '{print $2}')
        einfo "  Python3: ${py_ver}"
    fi

    # Texinfo
    if command -v makeinfo &>/dev/null; then
        local ti_ver
        ti_ver=$(makeinfo --version | head -1 | grep -oP '\d+\.\d+' | head -1)
        einfo "  Texinfo: ${ti_ver}"
    fi

    # Check /bin/sh is bash
    local sh_link
    sh_link=$(readlink -f /bin/sh 2>/dev/null) || sh_link="unknown"
    if [[ "${sh_link}" == *bash* ]]; then
        einfo "  /bin/sh -> bash (OK)"
    else
        ewarn "  /bin/sh -> ${sh_link} (LFS expects bash)"
    fi

    return ${ok}
}

# is_efi — Check if booted in EFI mode
is_efi() {
    [[ -d /sys/firmware/efi ]]
}

# is_root — Check if running as root
is_root() {
    [[ "$(id -u)" -eq 0 ]]
}

# has_network — Check basic network connectivity
has_network() {
    ping -c 1 -W 3 linuxfromscratch.org &>/dev/null || \
    ping -c 1 -W 3 google.com &>/dev/null
}

# checkpoint_set — Mark a phase as completed
checkpoint_set() {
    local name="$1"
    mkdir -p "${CHECKPOINT_DIR}"
    touch "${CHECKPOINT_DIR}/${name}"
    einfo "Checkpoint set: ${name}"
}

# checkpoint_reached — Check if a phase is already completed
checkpoint_reached() {
    local name="$1"
    [[ -f "${CHECKPOINT_DIR}/${name}" ]]
}

# checkpoint_clear — Remove all checkpoints
checkpoint_clear() {
    rm -rf "${CHECKPOINT_DIR}"
    einfo "All checkpoints cleared"
}

# bytes_to_human — Convert bytes to human readable
bytes_to_human() {
    local bytes="$1"
    if ((bytes >= 1073741824)); then
        printf "%.1f GiB" "$(echo "scale=1; ${bytes}/1073741824" | bc)"
    elif ((bytes >= 1048576)); then
        printf "%.1f MiB" "$(echo "scale=1; ${bytes}/1048576" | bc)"
    elif ((bytes >= 1024)); then
        printf "%.1f KiB" "$(echo "scale=1; ${bytes}/1024" | bc)"
    else
        printf "%d B" "${bytes}"
    fi
}

# get_cpu_count — Number of CPUs
get_cpu_count() {
    nproc 2>/dev/null || echo 4
}

# generate_password_hash — Create SHA-512 password hash
generate_password_hash() {
    local password="$1"
    openssl passwd -6 "${password}" 2>/dev/null || \
    python3 -c "import crypt; print(crypt.crypt('${password}', crypt.mksalt(crypt.METHOD_SHA512)))" 2>/dev/null
}
