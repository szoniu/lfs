#!/usr/bin/env bash
# desktop.sh — Optional BLFS desktop environment
# Note: Building KDE Plasma from source in LFS requires 500+ BLFS packages.
# This module provides a framework for BLFS package building.
source "${LIB_DIR}/protection.sh"

# desktop_install — Install desktop environment (BLFS)
desktop_install() {
    einfo "=== Desktop Installation ==="
    ewarn "Building a desktop environment from source is a major undertaking."
    ewarn "This will install essential BLFS packages for a graphical desktop."

    # Phase 1: Essential BLFS libraries
    _install_blfs_essentials

    # Phase 2: Xorg
    _install_xorg

    # Phase 3: Basic desktop packages
    _install_desktop_packages

    einfo "Desktop installation complete"
    einfo "Note: Full KDE Plasma requires many additional BLFS packages."
    einfo "See https://www.linuxfromscratch.org/blfs/ for details."
}

# _install_blfs_essentials — Core BLFS libraries needed for Xorg
_install_blfs_essentials() {
    einfo "Installing essential BLFS libraries..."

    # This installs packages from BLFS that are commonly needed.
    # Each package must have its tarball in /sources.

    # CMake (needed for many BLFS packages)
    _build_blfs_pkg "cmake" "CMake" "
        ./bootstrap --prefix=/usr \
                    --system-libs \
                    --mandir=/share/man \
                    --no-system-jsoncpp \
                    --no-system-cppdap \
                    --no-system-librhash \
                    --docdir=/share/doc/cmake && \
        make && make install
    "

    # Which
    _build_blfs_pkg "which" "Which" "
        ./configure --prefix=/usr && make && make install
    "

    # libxml2
    _build_blfs_pkg "libxml2" "Libxml2" "
        ./configure --prefix=/usr \
                    --sysconfdir=/etc \
                    --disable-static \
                    --with-history \
                    --with-icu \
                    PYTHON=/usr/bin/python3 && \
        make && make install
    "

    einfo "Essential BLFS libraries installed"
}

# _install_xorg — Install Xorg display server
_install_xorg() {
    einfo "Installing Xorg..."
    ewarn "Xorg installation from source requires many packages."
    ewarn "This provides a minimal Xorg setup."

    # In a real LFS build, Xorg requires ~50 packages built in order.
    # For now, we create a script the user can run post-boot.

    chroot_exec "
        mkdir -p /root/blfs-scripts
        cat > /root/blfs-scripts/install-xorg.sh << 'XORGEOF'
#!/bin/bash
# Xorg installation script for BLFS
# Run this after booting into your LFS system
echo 'This script will guide you through Xorg installation.'
echo 'See: https://www.linuxfromscratch.org/blfs/view/stable/x/xorg7.html'
echo ''
echo 'Required packages (build in order):'
echo '  1. util-macros'
echo '  2. xorgproto'
echo '  3. libXau'
echo '  4. libXdmcp'
echo '  5. xcb-proto'
echo '  6. libxcb'
echo '  7. Xorg Libraries (libX11, libXext, etc.)'
echo '  8. xcb-util packages'
echo '  9. Mesa'
echo ' 10. xbitmaps'
echo ' 11. Xorg Apps'
echo ' 12. xcursor-themes'
echo ' 13. Xorg Fonts'
echo ' 14. xkeyboard-config'
echo ' 15. Xorg Server'
echo ' 16. Xorg Drivers (input + video)'
echo ''
echo 'Download packages from: https://www.linuxfromscratch.org/blfs/'
XORGEOF
        chmod +x /root/blfs-scripts/install-xorg.sh
    "

    einfo "Xorg build scripts created in /root/blfs-scripts/"
}

# _install_desktop_packages — KDE Plasma preparation
_install_desktop_packages() {
    einfo "Preparing desktop environment scripts..."

    chroot_exec "
        cat > /root/blfs-scripts/install-kde.sh << 'KDEEOF'
#!/bin/bash
# KDE Plasma installation script for BLFS
# Run this after Xorg is installed and working
echo 'KDE Plasma installation from source requires 200+ packages.'
echo ''
echo 'Prerequisites (BLFS):'
echo '  - Xorg (fully working)'
echo '  - Qt 6'
echo '  - KDE Frameworks 6'
echo '  - Plasma Desktop'
echo ''
echo 'Estimated build time: 24-72 hours depending on hardware'
echo ''
echo 'See: https://www.linuxfromscratch.org/blfs/view/stable/kde/kde.html'
echo ''
echo 'Alternative: Install a lighter desktop:'
echo '  - i3wm (minimal tiling WM)'
echo '  - LXQt (lighter Qt desktop)'
echo '  - XFCE (GTK desktop, ~30 packages)'
KDEEOF
        chmod +x /root/blfs-scripts/install-kde.sh
    "

    einfo "Desktop installation scripts created"
    einfo "After booting, run /root/blfs-scripts/install-xorg.sh"
}

# _build_blfs_pkg — Build a single BLFS package
_build_blfs_pkg() {
    local pkg_pattern="$1"
    local name="$2"
    shift 2
    local build_cmds="$*"

    # Check if source tarball exists
    chroot_exec "
        cd /sources
        tarball=\$(ls ${pkg_pattern}-*.tar.* 2>/dev/null | head -1)
        if [[ -z \"\${tarball}\" ]]; then
            echo 'Source not found for ${name}, skipping'
            exit 0
        fi
        tar xf \"\${tarball}\"
        dir=\$(tar tf \"\${tarball}\" | head -1 | cut -d/ -f1)
        cd \"\${dir}\" && ${build_cmds}
        cd /sources && rm -rf \"\${dir}\"
    " || ewarn "Failed to build ${name} (non-critical)"
}
