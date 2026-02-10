#!/usr/bin/env bash
# constants.sh — Global constants for the LFS installer
source "${LIB_DIR}/protection.sh"

readonly INSTALLER_VERSION="1.0.0"
readonly INSTALLER_NAME="LFS TUI Installer"

# LFS version
readonly LFS_VERSION="12.4"
readonly LFS_KERNEL_VERSION="6.16.1"

# Paths (allow override from environment)
: "${LFS:=/mnt/lfs}"
: "${LOG_FILE:=/tmp/lfs-installer.log}"
: "${CHECKPOINT_DIR:=/tmp/lfs-installer-checkpoints}"
: "${CONFIG_FILE:=/tmp/lfs-installer.conf}"

# LFS build target triplet
: "${LFS_TGT:=$(uname -m)-lfs-linux-gnu}"
export LFS LFS_TGT

# Partition sizes (MiB)
readonly ESP_SIZE_MIB=512
readonly SWAP_DEFAULT_SIZE_MIB=4096

# Timeouts
readonly COUNTDOWN_DEFAULT=10

# Exit codes for TUI screens
readonly TUI_NEXT=0
readonly TUI_BACK=1
readonly TUI_ABORT=2

# Source download URLs
readonly LFS_SOURCES_BASE="https://www.linuxfromscratch.org/lfs/downloads/${LFS_VERSION}"
readonly LFS_WGET_LIST="${LFS_SOURCES_BASE}/wget-list-sysv"
readonly LFS_MD5SUMS="${LFS_SOURCES_BASE}/md5sums"

# Checkpoint names
readonly -a CHECKPOINTS=(
    "preflight"
    "disks"
    "sources"
    "toolchain_pass1"
    "toolchain_pass2"
    "temptools"
    "chroot_prep"
    "finalsystem_libs"
    "finalsystem_tools"
    "finalsystem_system"
    "system_config"
    "kernel"
    "bootloader"
    "users"
    "finalize"
)

# Configuration variable names (for save/load)
readonly -a CONFIG_VARS=(
    TARGET_DISK
    PARTITION_SCHEME
    FILESYSTEM
    BTRFS_SUBVOLUMES
    SWAP_TYPE
    SWAP_SIZE_MIB
    HOSTNAME
    TIMEZONE
    LOCALE
    KEYMAP
    KERNEL_CONFIG
    MAKEFLAGS
    ROOT_PASSWORD_HASH
    USERNAME
    USER_PASSWORD_HASH
    USER_GROUPS
    ENABLE_SSH
    NETWORK_IP
    NETWORK_GATEWAY
    NETWORK_DNS
    NETWORK_IFACE
    ESP_PARTITION
    ESP_REUSE
    ROOT_PARTITION
    SWAP_PARTITION
    BOOT_PARTITION
    EXTRA_PACKAGES
)

# Chroot installer path
readonly CHROOT_INSTALLER_DIR="/tmp/lfs-installer"
