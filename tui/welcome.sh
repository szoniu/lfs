#!/usr/bin/env bash
# tui/welcome.sh — Welcome screen + prerequisite checks
source "${LIB_DIR}/protection.sh"

screen_welcome() {
    local welcome_text
    welcome_text="Welcome to the ${INSTALLER_NAME} v${INSTALLER_VERSION}

This wizard will guide you through the complete installation
of Linux From Scratch ${LFS_VERSION}.

What this installer will do:
  * Detect your hardware (CPU, GPU, disks)
  * Partition and format your disk
  * Download and verify all source packages
  * Build cross-compilation toolchain
  * Build the complete LFS system (~80 packages from source)
  * Compile and install the Linux kernel ${LFS_KERNEL_VERSION}
  * Configure bootloader (GRUB, dual-boot supported)

Requirements:
  * Root access
  * UEFI boot mode
  * Working internet connection
  * At least 30 GiB free disk space
  * Host system with GCC, Make, Bash, and other build tools

WARNING: This is a from-source build and will take many hours!

Press OK to check prerequisites and continue."

    dialog_msgbox "Welcome" "${welcome_text}" || return "${TUI_ABORT}"

    local -a errors=()
    local -a warnings=()

    if ! is_root; then
        errors+=("Not running as root. Please run with sudo or as root.")
    fi

    if ! is_efi; then
        errors+=("System is not booted in UEFI mode. This installer requires UEFI.")
    fi

    if ! has_network; then
        warnings+=("No network connectivity detected. You will need internet for installation.")
    fi

    if [[ -z "${DIALOG_CMD:-}" ]]; then
        errors+=("No dialog backend available.")
    fi

    # Check host tool versions
    if ! command -v gcc &>/dev/null; then
        errors+=("GCC not found. Required for building LFS.")
    fi

    if ! command -v make &>/dev/null; then
        errors+=("Make not found. Required for building LFS.")
    fi

    local status_text=""
    local has_errors=0

    status_text+="Prerequisite Check Results:\n\n"

    if is_root 2>/dev/null; then
        status_text+="  [OK] Running as root\n"
    fi
    if is_efi 2>/dev/null; then
        status_text+="  [OK] UEFI boot mode detected\n"
    fi
    if has_network 2>/dev/null; then
        status_text+="  [OK] Network connectivity\n"
    fi
    status_text+="  [OK] Dialog backend: ${DIALOG_CMD:-unknown}\n"
    if command -v gcc &>/dev/null; then
        status_text+="  [OK] GCC: $(gcc --version | head -1)\n"
    fi

    local w
    for w in "${warnings[@]}"; do
        status_text+="\n  [!!] ${w}\n"
    done

    local e
    for e in "${errors[@]}"; do
        status_text+="\n  [FAIL] ${e}\n"
        has_errors=1
    done

    if [[ ${has_errors} -eq 1 ]]; then
        status_text+="\nCritical errors found. Installation cannot proceed."
        dialog_msgbox "Prerequisites — FAILED" "${status_text}"

        if [[ "${FORCE:-0}" != "1" ]]; then
            return "${TUI_ABORT}"
        fi

        dialog_yesno "Force Mode" \
            "Prerequisites failed but --force is set.\n\nContinue anyway? This may cause errors." \
            || return "${TUI_ABORT}"
    else
        if [[ ${#warnings[@]} -gt 0 ]]; then
            status_text+="\nWarnings found but installation can proceed."
            dialog_yesno "Prerequisites — Warnings" "${status_text}" \
                || return "${TUI_ABORT}"
        else
            status_text+="\nAll prerequisites passed!"
            dialog_msgbox "Prerequisites — OK" "${status_text}"
        fi
    fi

    return "${TUI_NEXT}"
}
