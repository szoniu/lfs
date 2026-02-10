#!/usr/bin/env bash
# tui/extra_packages.sh — Additional packages note
source "${LIB_DIR}/protection.sh"

screen_extra_packages() {
    local packages
    packages=$(dialog_inputbox "Extra Packages" \
        "Enter any additional packages to build from BLFS (space-separated).\n\n\
These will be noted for manual compilation after first boot.\n\n\
Examples: openssh wget curl git sudo\n\n\
Leave empty to skip:" \
        "${EXTRA_PACKAGES:-}") || return "${TUI_BACK}"

    EXTRA_PACKAGES="${packages}"
    export EXTRA_PACKAGES

    einfo "Extra packages: ${EXTRA_PACKAGES:-none}"
    return "${TUI_NEXT}"
}
