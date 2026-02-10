#!/usr/bin/env bash
# tui/gpu_config.sh — GPU driver information
source "${LIB_DIR}/protection.sh"

screen_gpu_config() {
    local vendor="${GPU_VENDOR:-unknown}"
    local device="${GPU_DEVICE_NAME:-Unknown GPU}"

    local info_text=""
    info_text+="Detected GPU: ${device}\n"
    info_text+="Vendor: ${vendor}\n\n"

    case "${vendor}" in
        nvidia)
            info_text+="NVIDIA GPU detected.\n\n"
            info_text+="In LFS, NVIDIA drivers must be built from source (BLFS).\n"
            info_text+="The kernel will include basic framebuffer support.\n"
            info_text+="After first boot, you can build nvidia-drivers from:\n"
            info_text+="  https://www.nvidia.com/drivers\n"
            ;;
        amd)
            info_text+="AMD GPU detected.\n\n"
            info_text+="The AMDGPU driver is built into the Linux kernel.\n"
            info_text+="The kernel config will enable AMDGPU support.\n"
            info_text+="For full acceleration, build Mesa from BLFS after boot.\n"
            ;;
        intel)
            info_text+="Intel GPU detected.\n\n"
            info_text+="The i915 driver is built into the Linux kernel.\n"
            info_text+="For full acceleration, build Mesa from BLFS after boot.\n"
            ;;
        *)
            info_text+="No specific GPU detected.\n"
            info_text+="Basic framebuffer will be used.\n"
            ;;
    esac

    info_text+="\nNote: GPU driver compilation from source is a BLFS task.\n"
    info_text+="Scripts will be provided in /root/blfs-scripts/ after install."

    dialog_msgbox "GPU Information" "${info_text}" || return "${TUI_BACK}"

    return "${TUI_NEXT}"
}
