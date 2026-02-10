#!/usr/bin/env bash
# tui/summary.sh — Full summary + confirmation + countdown
source "${LIB_DIR}/protection.sh"

screen_summary() {
    local summary=""
    summary+="=== Installation Summary ===\n\n"
    summary+="Target disk:  ${TARGET_DISK:-?}\n"
    summary+="Partitioning: ${PARTITION_SCHEME:-auto}\n"
    summary+="Filesystem:   ${FILESYSTEM:-ext4}\n"
    [[ "${FILESYSTEM}" == "btrfs" ]] && summary+="Subvolumes:   ${BTRFS_SUBVOLUMES:-default}\n"
    summary+="Swap:         ${SWAP_TYPE:-zram}"
    [[ -n "${SWAP_SIZE_MIB:-}" ]] && summary+=" (${SWAP_SIZE_MIB} MiB)"
    summary+="\n"
    summary+="\n"
    summary+="Hostname:     ${HOSTNAME:-lfs}\n"
    summary+="Timezone:     ${TIMEZONE:-UTC}\n"
    summary+="Locale:       ${LOCALE:-en_US.UTF-8}\n"
    summary+="Keymap:       ${KEYMAP:-us}\n"
    summary+="\n"
    summary+="Kernel:       ${LFS_KERNEL_VERSION} (config: ${KERNEL_CONFIG:-defconfig})\n"
    summary+="GPU:          ${GPU_VENDOR:-unknown} (${GPU_DRIVER:-auto})\n"
    summary+="CPU march:    ${CPU_MARCH:-x86-64}\n"
    summary+="CPU cores:    ${CPU_CORES:-?} (MAKEFLAGS=-j${CPU_CORES:-4})\n"
    summary+="\n"
    summary+="Username:     ${USERNAME:-user}\n"
    summary+="SSH:          ${ENABLE_SSH:-no}\n"
    summary+="LFS Version:  ${LFS_VERSION}\n"
    [[ -n "${EXTRA_PACKAGES:-}" ]] && summary+="Extra pkgs:   ${EXTRA_PACKAGES}\n"

    if [[ "${ESP_REUSE:-no}" == "yes" ]]; then
        summary+="\nDual-boot:    YES (reusing ESP ${ESP_PARTITION:-?})\n"
    fi

    summary+="\n!!! WARNING: This is a FROM-SOURCE build !!!\n"
    summary+="Estimated time: 4-12+ hours depending on hardware.\n"

    dialog_msgbox "Installation Summary" "${summary}" || return "${TUI_BACK}"

    if [[ "${PARTITION_SCHEME:-auto}" == "auto" ]]; then
        local warning=""
        warning+="!!! WARNING: DATA DESTRUCTION !!!\n\n"
        warning+="The following disk will be COMPLETELY ERASED:\n\n"
        warning+="  ${TARGET_DISK:-?}\n\n"
        warning+="ALL existing data on this disk will be permanently lost.\n"
        warning+="This action CANNOT be undone.\n\n"
        warning+="Type 'YES' in the next dialog to confirm."

        dialog_msgbox "WARNING" "${warning}" || return "${TUI_BACK}"

        local confirmation
        confirmation=$(dialog_inputbox "Confirm Installation" \
            "Type YES (all caps) to confirm and begin installation:" \
            "") || return "${TUI_BACK}"

        if [[ "${confirmation}" != "YES" ]]; then
            dialog_msgbox "Cancelled" "Installation cancelled. You typed: '${confirmation}'"
            return "${TUI_BACK}"
        fi
    else
        dialog_yesno "Confirm Installation" \
            "Ready to begin installation. This will take many hours. Continue?" \
            || return "${TUI_BACK}"
    fi

    einfo "Installation starting in ${COUNTDOWN_DEFAULT} seconds..."
    (
        local i
        for (( i = COUNTDOWN_DEFAULT; i > 0; i-- )); do
            echo "$(( (COUNTDOWN_DEFAULT - i) * 100 / COUNTDOWN_DEFAULT ))"
            sleep 1
        done
        echo "100"
    ) | dialog_gauge "Starting Installation" \
        "Installation will begin in ${COUNTDOWN_DEFAULT} seconds...\nPress Ctrl+C to abort."

    return "${TUI_NEXT}"
}
