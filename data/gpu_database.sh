#!/usr/bin/env bash
# gpu_database.sh — GPU vendor detection and driver recommendations
source "${LIB_DIR}/protection.sh"

readonly GPU_VENDOR_NVIDIA="10de"
readonly GPU_VENDOR_AMD="1002"
readonly GPU_VENDOR_INTEL="8086"

nvidia_generation() {
    local device_id="$1"
    local dec_id
    dec_id=$((16#${device_id}))

    if (( dec_id >= 0x2900 )); then
        echo "blackwell"
    elif (( dec_id >= 0x2700 )); then
        echo "ada"
    elif (( dec_id >= 0x2200 )); then
        echo "ampere"
    elif (( dec_id >= 0x1e00 )); then
        echo "turing"
    elif (( dec_id >= 0x1380 )); then
        echo "pre-turing"
    else
        echo "pre-turing"
    fi
}

get_gpu_recommendation() {
    local vendor_id="$1" device_id="${2:-0000}"

    case "${vendor_id}" in
        "${GPU_VENDOR_NVIDIA}")
            echo "nvidia-proprietary|nvidia|yes"
            ;;
        "${GPU_VENDOR_AMD}")
            echo "amdgpu-kernel|amdgpu|no"
            ;;
        "${GPU_VENDOR_INTEL}")
            echo "i915-kernel|intel|no"
            ;;
        *)
            echo "none|fbdev|no"
            ;;
    esac
}
