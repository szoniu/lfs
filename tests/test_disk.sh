#!/usr/bin/env bash
# tests/test_disk.sh — Test disk planning (dry-run)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export _LFS_INSTALLER=1
export LIB_DIR="${SCRIPT_DIR}/lib"
export DATA_DIR="${SCRIPT_DIR}/data"
export LOG_FILE="/tmp/lfs-test-disk.log"
export DRY_RUN=1
: > "${LOG_FILE}"

source "${LIB_DIR}/constants.sh"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/utils.sh"
source "${LIB_DIR}/disk.sh"

# Mock dialog_menu for non-interactive
dialog_menu() { echo "retry"; }
dialog_textbox() { true; }

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${expected}" == "${actual}" ]]; then
        echo "  PASS: ${desc}"
        (( PASS++ )) || true
    else
        echo "  FAIL: ${desc} — expected '${expected}', got '${actual}'"
        (( FAIL++ )) || true
    fi
}

echo "=== Test: Auto-partition plan ==="

TARGET_DISK="/dev/sda"
FILESYSTEM="ext4"
SWAP_TYPE="zram"
export TARGET_DISK FILESYSTEM SWAP_TYPE

disk_plan_auto

assert_eq "Plan has actions" "true" "$( [[ ${#DISK_ACTIONS[@]} -gt 0 ]] && echo true || echo false )"
assert_eq "Action count (no swap partition)" "6" "${#DISK_ACTIONS[@]}"
assert_eq "ESP partition" "/dev/sda1" "${ESP_PARTITION:-}"
assert_eq "Root partition" "/dev/sda2" "${ROOT_PARTITION:-}"

echo ""
echo "=== Test: Auto-partition with swap ==="

disk_plan_reset
SWAP_TYPE="partition"
SWAP_SIZE_MIB="4096"
export SWAP_TYPE SWAP_SIZE_MIB

disk_plan_auto

assert_eq "Plan has more actions" "true" "$( [[ ${#DISK_ACTIONS[@]} -gt 6 ]] && echo true || echo false )"
assert_eq "ESP partition" "/dev/sda1" "${ESP_PARTITION:-}"
assert_eq "Swap partition" "/dev/sda2" "${SWAP_PARTITION:-}"
assert_eq "Root partition" "/dev/sda3" "${ROOT_PARTITION:-}"

echo ""
echo "=== Test: NVMe partition names ==="

disk_plan_reset
TARGET_DISK="/dev/nvme0n1"
SWAP_TYPE="zram"
export TARGET_DISK SWAP_TYPE

disk_plan_auto

assert_eq "NVMe ESP" "/dev/nvme0n1p1" "${ESP_PARTITION:-}"
assert_eq "NVMe Root" "/dev/nvme0n1p2" "${ROOT_PARTITION:-}"

# Cleanup
rm -f "${LOG_FILE}"

echo ""
echo "=== Results ==="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"

[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
