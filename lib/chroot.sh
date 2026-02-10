#!/usr/bin/env bash
# chroot.sh — Enter/exit chroot, bind mounts, cleanup, LFS user setup
source "${LIB_DIR}/protection.sh"

# --- LFS user management ---

# lfs_create_user — Create the lfs user for building cross-toolchain
lfs_create_user() {
    einfo "Creating lfs user..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would create lfs user"
        return 0
    fi

    groupadd lfs 2>/dev/null || true
    useradd -s /bin/bash -g lfs -m -k /dev/null lfs 2>/dev/null || true

    # Grant ownership of LFS directories
    chown -v lfs "${LFS}/sources"
    mkdir -pv "${LFS}/tools"
    chown -v lfs "${LFS}/tools"

    einfo "lfs user created"
}

# lfs_setup_env — Set up the lfs user's environment
lfs_setup_env() {
    cat > /home/lfs/.bash_profile << 'PROFEOF'
exec env -i HOME=/home/lfs TERM="$TERM" PS1='\u:\w\$ ' /bin/bash
PROFEOF

    cat > /home/lfs/.bashrc << RCEOF
set +h
umask 022
LFS=${LFS}
LC_ALL=POSIX
LFS_TGT=${LFS_TGT}
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:\$PATH; fi
PATH=\${LFS}/tools/bin:\$PATH
CONFIG_SITE=\${LFS}/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
MAKEFLAGS="-j$(nproc)"
export MAKEFLAGS
RCEOF

    chown lfs:lfs /home/lfs/.bash_profile /home/lfs/.bashrc

    einfo "lfs user environment configured"
}

# --- Limited directory structure ---

# create_lfs_dirs — Create essential directory layout in $LFS
create_lfs_dirs() {
    einfo "Creating LFS directory structure..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would create LFS directories"
        return 0
    fi

    mkdir -pv "${LFS}"/{etc,var} "${LFS}/usr/"{bin,lib,sbin}

    for dir in bin lib sbin; do
        ln -sfv "usr/${dir}" "${LFS}/${dir}"
    done

    case "$(uname -m)" in
        x86_64) mkdir -pv "${LFS}/lib64" ;;
    esac

    mkdir -pv "${LFS}/tools"

    einfo "LFS directory structure created"
}

# --- Virtual kernel filesystems ---

# chroot_prepare_vkfs — Mount virtual kernel filesystems
chroot_prepare_vkfs() {
    einfo "Mounting virtual kernel filesystems..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would mount virtual kernel filesystems"
        return 0
    fi

    # Create device nodes
    mkdir -pv "${LFS}"/{dev,proc,sys,run}

    # Bind mount /dev
    if ! mountpoint -q "${LFS}/dev" 2>/dev/null; then
        mount -v --bind /dev "${LFS}/dev"
    fi

    # Mount devpts
    if ! mountpoint -q "${LFS}/dev/pts" 2>/dev/null; then
        mount -vt devpts devpts -o gid=5,mode=0620 "${LFS}/dev/pts"
    fi

    # Mount proc
    if ! mountpoint -q "${LFS}/proc" 2>/dev/null; then
        mount -vt proc proc "${LFS}/proc"
    fi

    # Mount sysfs
    if ! mountpoint -q "${LFS}/sys" 2>/dev/null; then
        mount -vt sysfs sysfs "${LFS}/sys"
    fi

    # Mount tmpfs on run
    if ! mountpoint -q "${LFS}/run" 2>/dev/null; then
        mount -vt tmpfs tmpfs "${LFS}/run"
    fi

    # shm symlink or mount
    if [[ -h "${LFS}/dev/shm" ]]; then
        install -v -d -m 1777 "${LFS}/$(readlink "${LFS}/dev/shm")"
    else
        mount -vt tmpfs -o nosuid,nodev tmpfs "${LFS}/dev/shm"
    fi

    einfo "Virtual kernel filesystems mounted"
}

# chroot_teardown — Unmount virtual kernel filesystems
chroot_teardown() {
    einfo "Tearing down chroot environment..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would tear down chroot"
        return 0
    fi

    local -a chroot_mounts=(
        "${LFS}/run"
        "${LFS}/dev/shm"
        "${LFS}/dev/pts"
        "${LFS}/dev"
        "${LFS}/sys"
        "${LFS}/proc"
    )

    local mnt
    for mnt in "${chroot_mounts[@]}"; do
        if mountpoint -q "${mnt}" 2>/dev/null; then
            umount -l "${mnt}" 2>/dev/null || true
        fi
    done

    einfo "Chroot teardown complete"
}

# chroot_exec — Execute a command inside the LFS chroot
chroot_exec() {
    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would chroot exec: $*"
        return 0
    fi

    chroot "${LFS}" /usr/bin/env -i \
        HOME=/root \
        TERM="${TERM}" \
        PS1='(lfs chroot) \u:\w\$ ' \
        PATH=/usr/bin:/usr/sbin \
        MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}" \
        /bin/bash --login -c "$*"
}

# chroot_exec_script — Execute a script inside chroot
chroot_exec_script() {
    local script="$1"
    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would run chroot script: ${script}"
        return 0
    fi

    cp "${script}" "${LFS}/tmp/chroot-script.sh"
    chmod +x "${LFS}/tmp/chroot-script.sh"
    chroot_exec "/tmp/chroot-script.sh"
    rm -f "${LFS}/tmp/chroot-script.sh"
}

# create_essential_files — Create essential files in chroot (Chapter 7.6)
create_essential_files() {
    einfo "Creating essential files and symlinks..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would create essential files"
        return 0
    fi

    # Create essential symlinks
    ln -sfv /proc/self/mounts "${LFS}/etc/mtab"

    # Create /etc/hosts
    cat > "${LFS}/etc/hosts" << 'HOSTSEOF'
127.0.0.1  localhost
::1        localhost ip6-localhost ip6-loopback
HOSTSEOF

    # Create /etc/passwd
    cat > "${LFS}/etc/passwd" << 'PWEOF'
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
PWEOF

    # Create /etc/group
    cat > "${LFS}/etc/group" << 'GRPEOF'
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
GRPEOF

    # Create log files
    mkdir -pv "${LFS}/var/log"
    touch "${LFS}/var/log/"{btmp,lastlog,faillog,wtmp}
    chgrp -v 13 "${LFS}/var/log/lastlog"
    chmod -v 664  "${LFS}/var/log/lastlog"
    chmod -v 600  "${LFS}/var/log/btmp"

    einfo "Essential files created"
}

# copy_installer_to_chroot — Copy installer scripts for chroot phase
copy_installer_to_chroot() {
    einfo "Copying installer to chroot..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would copy installer to chroot"
        return 0
    fi

    local dest="${LFS}${CHROOT_INSTALLER_DIR}"
    mkdir -p "${dest}"
    cp -a "${SCRIPT_DIR}/"* "${dest}/"
    cp "${CONFIG_FILE}" "${dest}/$(basename "${CONFIG_FILE}")"
    chmod +x "${dest}/install.sh" "${dest}/configure.sh"

    einfo "Installer copied to ${CHROOT_INSTALLER_DIR}"
}
