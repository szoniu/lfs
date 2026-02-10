#!/usr/bin/env bash
# kernel.sh — Chapter 10: Kernel compilation from source
source "${LIB_DIR}/protection.sh"

# kernel_install — Build and install the Linux kernel
kernel_install() {
    einfo "=== Kernel Installation ==="
    einfo "Kernel version: ${LFS_KERNEL_VERSION}"
    einfo "This may take a while..."

    # Install linux-firmware (if available in sources)
    _install_firmware

    # Build the kernel
    _build_kernel

    einfo "Kernel installation complete"
}

# _install_firmware — Install linux-firmware for hardware support
_install_firmware() {
    einfo "Installing linux-firmware..."

    # Check if firmware tarball exists
    if ls "${LFS}/sources"/linux-firmware-*.tar.* &>/dev/null; then
        chroot_exec "
            cd /sources && \
            tar xf linux-firmware-*.tar.* && cd linux-firmware-*/ && \
            mkdir -p /usr/lib/firmware && \
            cp -a . /usr/lib/firmware/ && \
            cd /sources && rm -rf linux-firmware-*/
        "
        einfo "linux-firmware installed"
    else
        ewarn "linux-firmware tarball not found — firmware not installed"
        ewarn "You may need to install it post-boot for WiFi/GPU support"
    fi
}

# _build_kernel — Compile and install the kernel
_build_kernel() {
    einfo "Building Linux kernel..."

    local kernel_config="${KERNEL_CONFIG:-defconfig}"

    chroot_exec "
        cd /sources && \
        tar xf linux-${LFS_KERNEL_VERSION}.tar.xz && \
        cd linux-${LFS_KERNEL_VERSION} && \
        make mrproper
    "

    # Kernel configuration strategy
    case "${kernel_config}" in
        defconfig)
            einfo "Using default kernel configuration"
            chroot_exec "
                cd /sources/linux-${LFS_KERNEL_VERSION} && \
                make defconfig
            "
            ;;
        allmodconfig)
            einfo "Using allmodconfig (compile everything as modules)"
            chroot_exec "
                cd /sources/linux-${LFS_KERNEL_VERSION} && \
                make allmodconfig
            "
            ;;
        custom)
            einfo "Custom kernel configuration (menuconfig)"
            chroot_exec "
                cd /sources/linux-${LFS_KERNEL_VERSION} && \
                make menuconfig
            "
            ;;
        *)
            # Assume it's a path to a .config file
            if [[ -f "${kernel_config}" ]]; then
                cp "${kernel_config}" "${LFS}/sources/linux-${LFS_KERNEL_VERSION}/.config"
                chroot_exec "
                    cd /sources/linux-${LFS_KERNEL_VERSION} && \
                    make olddefconfig
                "
            else
                einfo "Using defconfig (fallback)"
                chroot_exec "
                    cd /sources/linux-${LFS_KERNEL_VERSION} && \
                    make defconfig
                "
            fi
            ;;
    esac

    # Enable essential options
    _tweak_kernel_config

    # Build the kernel
    chroot_exec "
        cd /sources/linux-${LFS_KERNEL_VERSION} && \
        make ${MAKEFLAGS:--j$(nproc)}
    "

    # Install modules
    chroot_exec "
        cd /sources/linux-${LFS_KERNEL_VERSION} && \
        make modules_install
    "

    # Install kernel image
    chroot_exec "
        cd /sources/linux-${LFS_KERNEL_VERSION} && \
        cp -iv arch/x86/boot/bzImage /boot/vmlinuz-${LFS_KERNEL_VERSION}-lfs && \
        cp -iv System.map /boot/System.map-${LFS_KERNEL_VERSION} && \
        cp -iv .config /boot/config-${LFS_KERNEL_VERSION}
    "

    # Install kernel headers (documentation)
    chroot_exec "
        cd /sources/linux-${LFS_KERNEL_VERSION} && \
        install -d /usr/share/doc/linux-${LFS_KERNEL_VERSION} && \
        cp -r Documentation/* /usr/share/doc/linux-${LFS_KERNEL_VERSION} 2>/dev/null || true
    "

    # Clean up source
    chroot_exec "
        cd /sources && rm -rf linux-${LFS_KERNEL_VERSION}
    "

    einfo "Kernel built: /boot/vmlinuz-${LFS_KERNEL_VERSION}-lfs"
}

# _tweak_kernel_config — Enable required options via scripts/config
_tweak_kernel_config() {
    einfo "Tweaking kernel config for LFS requirements..."

    local config_cmds=""

    # EFI support
    config_cmds+="scripts/config --enable EFI && "
    config_cmds+="scripts/config --enable EFI_STUB && "
    config_cmds+="scripts/config --enable EFI_MIXED && "
    config_cmds+="scripts/config --enable EFIVAR_FS && "

    # Essential filesystems
    config_cmds+="scripts/config --enable EXT4_FS && "
    config_cmds+="scripts/config --enable VFAT_FS && "
    config_cmds+="scripts/config --enable TMPFS && "
    config_cmds+="scripts/config --enable PROC_FS && "
    config_cmds+="scripts/config --enable SYSFS && "
    config_cmds+="scripts/config --enable DEVTMPFS && "
    config_cmds+="scripts/config --enable DEVTMPFS_MOUNT && "

    # Btrfs support if selected
    if [[ "${FILESYSTEM:-ext4}" == "btrfs" ]]; then
        config_cmds+="scripts/config --enable BTRFS_FS && "
    fi

    # XFS support if selected
    if [[ "${FILESYSTEM:-ext4}" == "xfs" ]]; then
        config_cmds+="scripts/config --enable XFS_FS && "
    fi

    # NVMe support
    config_cmds+="scripts/config --enable BLK_DEV_NVME && "

    # AHCI/SATA
    config_cmds+="scripts/config --enable ATA && "
    config_cmds+="scripts/config --enable SATA_AHCI && "

    # USB support
    config_cmds+="scripts/config --enable USB_SUPPORT && "
    config_cmds+="scripts/config --enable USB_XHCI_HCD && "
    config_cmds+="scripts/config --enable USB_EHCI_HCD && "
    config_cmds+="scripts/config --enable USB_STORAGE && "

    # Network
    config_cmds+="scripts/config --enable NETDEVICES && "
    config_cmds+="scripts/config --module E1000E && "
    config_cmds+="scripts/config --module IWLWIFI && "
    config_cmds+="scripts/config --module R8169 && "

    # zram for swap
    config_cmds+="scripts/config --module ZRAM && "
    config_cmds+="scripts/config --enable ZSTD_COMPRESS && "

    # GPU support (basic framebuffer)
    config_cmds+="scripts/config --enable DRM && "
    config_cmds+="scripts/config --enable FB && "
    config_cmds+="scripts/config --enable FB_EFI && "
    config_cmds+="scripts/config --enable FRAMEBUFFER_CONSOLE && "

    # Finalize
    config_cmds+="make olddefconfig"

    chroot_exec "
        cd /sources/linux-${LFS_KERNEL_VERSION} && ${config_cmds}
    "

    einfo "Kernel config tweaked"
}
