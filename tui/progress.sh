#!/usr/bin/env bash
# tui/progress.sh — Installation progress screen with gauge
source "${LIB_DIR}/protection.sh"

readonly -a INSTALL_PHASES=(
    "preflight|Preflight checks|2"
    "disks|Disk operations|3"
    "sources|Source download and verification|10"
    "toolchain|Cross-toolchain (Chapter 5)|15"
    "temptools|Temporary tools (Chapter 6)|10"
    "chroot_prep|Chroot preparation (Chapter 7)|5"
    "chroot_tools|Chroot tools (Chapter 7)|5"
    "finalsystem|Final system (Chapter 8)|30"
    "system_config|System configuration (Chapter 9)|3"
    "kernel|Kernel compilation (Chapter 10)|10"
    "bootloader|Bootloader installation|2"
    "swap_setup|Swap configuration|1"
    "users|User configuration|1"
    "finalize|Finalization|3"
)

screen_progress() {
    local total_weight=0
    local entry
    for entry in "${INSTALL_PHASES[@]}"; do
        local weight
        IFS='|' read -r _ _ weight <<< "${entry}"
        (( total_weight += weight ))
    done

    local progress_pipe="/tmp/lfs-progress-$$"
    mkfifo "${progress_pipe}" 2>/dev/null || true

    dialog_gauge "Installing Linux From Scratch" \
        "Preparing installation..." 0 < "${progress_pipe}" &
    local gauge_pid=$!

    exec 3>"${progress_pipe}"

    local completed_weight=0
    for entry in "${INSTALL_PHASES[@]}"; do
        local phase_name phase_desc weight
        IFS='|' read -r phase_name phase_desc weight <<< "${entry}"

        local percent=$(( completed_weight * 100 / total_weight ))
        echo "XXX" >&3 2>/dev/null || true
        echo "${percent}" >&3 2>/dev/null || true
        echo "${phase_desc}..." >&3 2>/dev/null || true
        echo "XXX" >&3 2>/dev/null || true

        if checkpoint_reached "${phase_name}"; then
            einfo "Phase ${phase_name} already completed (checkpoint)"
        else
            _execute_phase "${phase_name}" "${phase_desc}"
        fi

        (( completed_weight += weight ))
    done

    echo "XXX" >&3 2>/dev/null || true
    echo "100" >&3 2>/dev/null || true
    echo "Installation complete!" >&3 2>/dev/null || true
    echo "XXX" >&3 2>/dev/null || true

    exec 3>&-
    wait "${gauge_pid}" 2>/dev/null || true
    rm -f "${progress_pipe}"

    dialog_msgbox "Complete" \
        "Linux From Scratch ${LFS_VERSION} installation has finished!\n\n\
The system is ready to boot."

    return "${TUI_NEXT}"
}

_execute_phase() {
    local phase_name="$1"
    local phase_desc="$2"

    einfo "=== Phase: ${phase_desc} ==="
    maybe_exec "before_${phase_name}"

    case "${phase_name}" in
        preflight)
            preflight_checks
            ;;
        disks)
            disk_execute_plan
            mount_filesystems
            ;;
        sources)
            sources_full_download
            ;;
        toolchain)
            create_lfs_dirs
            lfs_create_user
            lfs_setup_env
            build_cross_toolchain
            ;;
        temptools)
            build_temp_tools
            ;;
        chroot_prep)
            # Ownership change + virtual kernel filesystems
            try "Changing ownership to root" chown -R root:root "${LFS}"/{usr,lib,var,etc,bin,sbin,tools}
            case "$(uname -m)" in
                x86_64) try "Changing lib64 ownership" chown -R root:root "${LFS}/lib64" ;;
            esac
            create_essential_files
            chroot_prepare_vkfs
            ;;
        chroot_tools)
            build_chroot_tools
            ;;
        finalsystem)
            build_final_system
            ;;
        system_config)
            install_lfs_bootscripts
            system_set_timezone
            system_set_locale
            system_set_hostname
            system_set_keymap
            configure_network
            generate_fstab
            ;;
        kernel)
            kernel_install
            ;;
        bootloader)
            bootloader_install
            ;;
        swap_setup)
            swap_setup
            ;;
        users)
            system_create_users
            ;;
        finalize)
            system_finalize
            install_extra_packages
            ;;
    esac

    maybe_exec "after_${phase_name}"
    checkpoint_set "${phase_name}"
}
