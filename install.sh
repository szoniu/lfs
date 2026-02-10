#!/usr/bin/env bash
# install.sh — Main entry point for the LFS TUI Installer
#
# Usage:
#   ./install.sh              — Run full installation (TUI wizard + install)
#   ./install.sh --configure  — Run only the TUI wizard (generate config)
#   ./install.sh --install    — Run only the installation (using existing config)
#   ./install.sh --dry-run    — Run wizard + simulate installation
#
set -euo pipefail
shopt -s inherit_errexit

export _LFS_INSTALLER=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
export LIB_DIR="${SCRIPT_DIR}/lib"
export TUI_DIR="${SCRIPT_DIR}/tui"
export DATA_DIR="${SCRIPT_DIR}/data"

# --- Source library modules ---
source "${LIB_DIR}/constants.sh"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/utils.sh"
source "${LIB_DIR}/dialog.sh"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/hardware.sh"
source "${LIB_DIR}/disk.sh"
source "${LIB_DIR}/network.sh"
source "${LIB_DIR}/sources.sh"
source "${LIB_DIR}/toolchain.sh"
source "${LIB_DIR}/temptools.sh"
source "${LIB_DIR}/chroot.sh"
source "${LIB_DIR}/finalsystem.sh"
source "${LIB_DIR}/system.sh"
source "${LIB_DIR}/kernel.sh"
source "${LIB_DIR}/bootloader.sh"
source "${LIB_DIR}/desktop.sh"
source "${LIB_DIR}/swap.sh"
source "${LIB_DIR}/hooks.sh"
source "${LIB_DIR}/preset.sh"

# --- Source TUI screens ---
source "${TUI_DIR}/welcome.sh"
source "${TUI_DIR}/preset_load.sh"
source "${TUI_DIR}/hw_detect.sh"
source "${TUI_DIR}/disk_select.sh"
source "${TUI_DIR}/filesystem_select.sh"
source "${TUI_DIR}/swap_config.sh"
source "${TUI_DIR}/network_config.sh"
source "${TUI_DIR}/locale_config.sh"
source "${TUI_DIR}/kernel_config.sh"
source "${TUI_DIR}/gpu_config.sh"
source "${TUI_DIR}/user_config.sh"
source "${TUI_DIR}/extra_packages.sh"
source "${TUI_DIR}/preset_save.sh"
source "${TUI_DIR}/summary.sh"
source "${TUI_DIR}/progress.sh"

# --- Source data files ---
source "${DATA_DIR}/cpu_march_database.sh"
source "${DATA_DIR}/gpu_database.sh"

# --- Cleanup trap ---
cleanup() {
    local rc=$?
    if mountpoint -q "${LFS}/proc" 2>/dev/null; then
        ewarn "Cleaning up mount points..."
        chroot_teardown || true
    fi
    if [[ ${rc} -ne 0 ]]; then
        eerror "Installer exited with code ${rc}"
        eerror "Log file: ${LOG_FILE}"
    fi
    return ${rc}
}
trap cleanup EXIT

# --- Parse arguments ---
MODE="full"
DRY_RUN=0
FORCE=0
NON_INTERACTIVE=0
export DRY_RUN FORCE NON_INTERACTIVE

usage() {
    cat <<'EOF'
LFS TUI Installer

Usage:
  install.sh [OPTIONS] [COMMAND]

Commands:
  (default)       Run full installation (wizard + install)
  --configure     Run only the TUI configuration wizard
  --install       Run only the installation phase (requires config)

Options:
  --config FILE   Use specified config file
  --dry-run       Simulate installation without destructive operations
  --force         Continue past failed prerequisite checks
  --non-interactive  Abort on any error (no recovery menu)
  --help          Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configure)
            MODE="configure"
            shift
            ;;
        --install)
            MODE="install"
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            eerror "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

# --- Main functions ---

run_configuration_wizard() {
    init_dialog

    register_wizard_screens \
        screen_welcome \
        screen_preset_load \
        screen_hw_detect \
        screen_disk_select \
        screen_filesystem_select \
        screen_swap_config \
        screen_network_config \
        screen_locale_config \
        screen_kernel_config \
        screen_gpu_config \
        screen_user_config \
        screen_extra_packages \
        screen_preset_save \
        screen_summary

    run_wizard

    # Set MAKEFLAGS based on detected CPU
    MAKEFLAGS="-j${CPU_CORES:-4}"
    export MAKEFLAGS

    config_save "${CONFIG_FILE}"
    einfo "Configuration complete. Saved to ${CONFIG_FILE}"
}

run_post_install() {
    einfo "=== Post-installation ==="

    chroot_teardown || true
    unmount_filesystems

    dialog_msgbox "Installation Complete" \
        "Linux From Scratch ${LFS_VERSION} has been successfully installed!\n\n\
You can now reboot into your new system.\n\n\
Remember to remove the installation media.\n\n\
Post-boot tasks:\n\
  - Build BLFS packages for desktop environment\n\
  - Install additional software as needed\n\
  - See /root/blfs-scripts/ for guided setup\n\n\
Log file saved to: ${LOG_FILE}"

    if dialog_yesno "Reboot" "Would you like to reboot now?"; then
        einfo "Rebooting..."
        if [[ "${DRY_RUN}" != "1" ]]; then
            reboot
        else
            einfo "[DRY-RUN] Would reboot now"
        fi
    else
        einfo "You can reboot manually when ready."
        einfo "Log file: ${LOG_FILE}"
    fi
}

preflight_checks() {
    einfo "Running preflight checks..."

    if [[ "${DRY_RUN}" != "1" ]]; then
        is_root || die "Must run as root"
        is_efi || die "UEFI boot mode required"
        has_network || die "Network connectivity required"
    fi

    check_host_versions || ewarn "Some host tool version checks failed"
    check_dependencies || die "Missing required dependencies"

    # Sync clock
    if command -v ntpd &>/dev/null && [[ "${DRY_RUN}" != "1" ]]; then
        try "Syncing system clock" ntpd -q -g || true
    elif command -v chronyd &>/dev/null && [[ "${DRY_RUN}" != "1" ]]; then
        try "Syncing system clock" chronyd -q || true
    fi

    einfo "Preflight checks passed"
}

# --- Entry point ---
main() {
    init_logging

    einfo "========================================="
    einfo "${INSTALLER_NAME} v${INSTALLER_VERSION}"
    einfo "LFS Version: ${LFS_VERSION}"
    einfo "========================================="
    einfo "Mode: ${MODE}"
    [[ "${DRY_RUN}" == "1" ]] && ewarn "DRY-RUN mode enabled"

    case "${MODE}" in
        full)
            run_configuration_wizard
            screen_progress
            run_post_install
            ;;
        configure)
            run_configuration_wizard
            ;;
        install)
            config_load "${CONFIG_FILE}"
            init_dialog
            screen_progress
            run_post_install
            ;;
        *)
            die "Unknown mode: ${MODE}"
            ;;
    esac

    einfo "Done."
}

main "$@"
