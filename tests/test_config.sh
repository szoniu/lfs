#!/usr/bin/env bash
# tests/test_config.sh — Test config save/load round-trip
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export _LFS_INSTALLER=1
export LIB_DIR="${SCRIPT_DIR}/lib"
export DATA_DIR="${SCRIPT_DIR}/data"
export LOG_FILE="/tmp/lfs-test-config.log"
: > "${LOG_FILE}"

source "${LIB_DIR}/constants.sh"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/config.sh"

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

echo "=== Test: Config Round-Trip ==="

FILESYSTEM="btrfs"
HOSTNAME="test-host"
LOCALE="pl_PL.UTF-8"
BTRFS_SUBVOLUMES="@:/:@home:/home:@var-log:/var/log"
SWAP_TYPE="zram"
EXTRA_PACKAGES="wget curl git"
KERNEL_CONFIG="defconfig"
export FILESYSTEM HOSTNAME LOCALE BTRFS_SUBVOLUMES SWAP_TYPE EXTRA_PACKAGES KERNEL_CONFIG

TMPFILE="/tmp/lfs-test-config-$$.conf"
config_save "${TMPFILE}"

unset FILESYSTEM HOSTNAME LOCALE BTRFS_SUBVOLUMES SWAP_TYPE EXTRA_PACKAGES KERNEL_CONFIG

config_load "${TMPFILE}"

assert_eq "FILESYSTEM" "btrfs" "${FILESYSTEM:-}"
assert_eq "HOSTNAME" "test-host" "${HOSTNAME:-}"
assert_eq "LOCALE" "pl_PL.UTF-8" "${LOCALE:-}"
assert_eq "BTRFS_SUBVOLUMES" "@:/:@home:/home:@var-log:/var/log" "${BTRFS_SUBVOLUMES:-}"
assert_eq "SWAP_TYPE" "zram" "${SWAP_TYPE:-}"
assert_eq "EXTRA_PACKAGES" "wget curl git" "${EXTRA_PACKAGES:-}"
assert_eq "KERNEL_CONFIG" "defconfig" "${KERNEL_CONFIG:-}"

echo ""
echo "=== Test: config_set / config_get ==="
config_set "HOSTNAME" "new-host"
assert_eq "config_set HOSTNAME" "new-host" "$(config_get HOSTNAME)"

config_set "EXTRA_PACKAGES" "pkg with spaces"
assert_eq "Spaces in value" "pkg with spaces" "$(config_get EXTRA_PACKAGES)"

config_set "BTRFS_SUBVOLUMES" '@:/:@home:/home'
assert_eq "Special chars (@/:)" "@:/:@home:/home" "$(config_get BTRFS_SUBVOLUMES)"

# Round-trip with special chars
TMPFILE2="/tmp/lfs-test-config-special-$$.conf"
config_save "${TMPFILE2}"
unset HOSTNAME EXTRA_PACKAGES BTRFS_SUBVOLUMES
config_load "${TMPFILE2}"
assert_eq "Round-trip HOSTNAME" "new-host" "${HOSTNAME:-}"
assert_eq "Round-trip EXTRA_PACKAGES" "pkg with spaces" "${EXTRA_PACKAGES:-}"
assert_eq "Round-trip BTRFS_SUBVOLUMES" "@:/:@home:/home" "${BTRFS_SUBVOLUMES:-}"

# Cleanup
rm -f "${TMPFILE}" "${TMPFILE2}" "${LOG_FILE}"

echo ""
echo "=== Results ==="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"

[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
