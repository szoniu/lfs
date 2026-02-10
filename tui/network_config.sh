#!/usr/bin/env bash
# tui/network_config.sh — Hostname configuration
source "${LIB_DIR}/protection.sh"

screen_network_config() {
    local hostname
    hostname=$(dialog_inputbox "Hostname" \
        "Enter the hostname for your system:" \
        "${HOSTNAME:-lfs}") || return "${TUI_BACK}"

    HOSTNAME="${hostname}"
    export HOSTNAME

    einfo "Hostname: ${HOSTNAME}"
    return "${TUI_NEXT}"
}
