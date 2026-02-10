#!/usr/bin/env bash
# tui/kernel_config.sh — Kernel configuration selection
source "${LIB_DIR}/protection.sh"

screen_kernel_config() {
    local current="${KERNEL_CONFIG:-defconfig}"
    local on_def="off" on_custom="off"
    [[ "${current}" == "defconfig" ]] && on_def="on"
    [[ "${current}" == "custom" ]] && on_custom="on"

    local choice
    choice=$(dialog_radiolist "Kernel Configuration" \
        "defconfig" "Default config — good hardware support, fast build" "${on_def}" \
        "custom"    "Custom config — menuconfig during build (interactive)" "${on_custom}") \
        || return "${TUI_BACK}"

    if [[ -z "${choice}" ]]; then
        return "${TUI_BACK}"
    fi

    KERNEL_CONFIG="${choice}"
    export KERNEL_CONFIG

    if [[ "${KERNEL_CONFIG}" == "defconfig" ]]; then
        dialog_msgbox "Default Kernel Config" \
            "The kernel will be built with 'make defconfig'.\n\n\
This provides a good default configuration with broad\n\
hardware support. Essential options for your setup\n\
(EFI, filesystem, NVMe, etc.) will be enabled automatically.\n\n\
Kernel version: ${LFS_KERNEL_VERSION}"
    else
        dialog_msgbox "Custom Kernel Config" \
            "During kernel build, 'make menuconfig' will be launched.\n\n\
You will need to manually configure kernel options.\n\
This is for advanced users who know what they need.\n\n\
Kernel version: ${LFS_KERNEL_VERSION}"
    fi

    einfo "Kernel config: ${KERNEL_CONFIG}"
    return "${TUI_NEXT}"
}
