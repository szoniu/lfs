#!/usr/bin/env bash
# swap.sh — zram, optional swap file/partition (SysVinit compatible)
source "${LIB_DIR}/protection.sh"

swap_setup() {
    local swap_type="${SWAP_TYPE:-zram}"

    case "${swap_type}" in
        zram)
            swap_setup_zram
            ;;
        partition)
            einfo "Swap partition configured during disk setup"
            ;;
        file)
            swap_setup_file
            ;;
        none)
            einfo "No swap configured"
            ;;
    esac
}

# swap_setup_zram — Configure zram via bootscript
swap_setup_zram() {
    einfo "Setting up zram swap..."

    # Create a simple zram setup script for SysVinit
    cat > /etc/init.d/zram << 'ZRAMEOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          zram
# Required-Start:    $local_fs
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       zram compressed swap
### END INIT INFO

ZRAM_SIZE=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 2 ))

case "$1" in
    start)
        modprobe zram num_devices=1 2>/dev/null || true
        echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null || true
        echo "${ZRAM_SIZE}K" > /sys/block/zram0/disksize
        mkswap /dev/zram0
        swapon -p 100 /dev/zram0
        echo "zram swap started (${ZRAM_SIZE}K)"
        ;;
    stop)
        swapoff /dev/zram0 2>/dev/null
        echo 1 > /sys/block/zram0/reset 2>/dev/null
        echo "zram swap stopped"
        ;;
    restart)
        $0 stop
        $0 start
        ;;
    status)
        if swapon --show=NAME | grep -q zram0; then
            echo "zram swap is active"
        else
            echo "zram swap is not active"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
ZRAMEOF
    chmod +x /etc/init.d/zram

    # Enable at boot
    ln -sf ../init.d/zram /etc/rc.d/rc3.d/S10zram 2>/dev/null || true

    einfo "zram swap configured"
}

# swap_setup_file — Create and configure a swap file
swap_setup_file() {
    local size_mib="${SWAP_SIZE_MIB:-${SWAP_DEFAULT_SIZE_MIB}}"
    local swap_file="/swapfile"

    einfo "Creating ${size_mib} MiB swap file..."

    if [[ "${FILESYSTEM:-ext4}" == "btrfs" ]]; then
        try "Creating btrfs swap file" \
            btrfs filesystem mkswapfile --size "${size_mib}m" "${swap_file}"
    else
        try "Allocating swap file" \
            dd if=/dev/zero of="${swap_file}" bs=1M count="${size_mib}" status=progress
        chmod 0600 "${swap_file}"
        try "Formatting swap file" mkswap "${swap_file}"
    fi

    echo "${swap_file}    none    swap    sw    0 0" >> /etc/fstab

    einfo "Swap file created: ${swap_file} (${size_mib} MiB)"
}
