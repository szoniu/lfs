#!/usr/bin/env bash
# temptools.sh — Chapter 6: Cross-compiling temporary tools
#                Chapter 7: Additional temporary tools in chroot
source "${LIB_DIR}/protection.sh"

# Helper: build a cross-compiled package as lfs user
_cross_build() {
    local pkg="$1" desc="$2"
    shift 2
    local srcdir
    srcdir=$(extract_source "${pkg}")

    build_as_lfs "${desc}" "
        cd '${srcdir}' && $*
    "
    rm -rf "${srcdir}"
    einfo "${desc} complete"
}

# ========== Chapter 6: Cross-compiling temporary tools ==========

build_m4() {
    _cross_build "m4" "M4" "
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} \
                    --build=\$(build-aux/config.guess) && \
        make && make DESTDIR=\${LFS} install
    "
}

build_ncurses() {
    _cross_build "ncurses" "Ncurses" "
        sed -i s/mawk// configure && \
        mkdir -pv build && pushd build && \
        ../configure && make -C include && make -C progs tic && popd && \
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} \
                    --build=\$(./config.guess) \
                    --mandir=/usr/share/man \
                    --with-manpage-format=normal \
                    --with-shared \
                    --without-normal \
                    --with-cxx-shared \
                    --without-debug \
                    --without-ada \
                    --disable-stripping && \
        make && make DESTDIR=\${LFS} TIC_PATH=\$(pwd)/build/progs/tic install && \
        ln -sv libncursesw.so \${LFS}/usr/lib/libncurses.so && \
        sed -e 's/^#if.*XOPEN.*$/#if 1/' -i \${LFS}/usr/include/curses.h
    "
}

build_bash_temp() {
    _cross_build "bash" "Bash (temp)" "
        ./configure --prefix=/usr \
                    --build=\$(sh support/config.guess) \
                    --host=\${LFS_TGT} \
                    --without-bash-malloc \
                    bash_cv_strtold_broken=no && \
        make && make DESTDIR=\${LFS} install && \
        ln -sfv bash \${LFS}/bin/sh
    "
}

build_coreutils_temp() {
    _cross_build "coreutils" "Coreutils (temp)" "
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} \
                    --build=\$(build-aux/config.guess) \
                    --enable-install-program=hostname \
                    --enable-no-install-program=kill,uptime \
                    gl_cv_macro_MB_CUR_MAX_good=y && \
        make && make DESTDIR=\${LFS} install && \
        mv -v \${LFS}/usr/bin/chroot \${LFS}/usr/sbin && \
        mkdir -pv \${LFS}/usr/share/man/man8 && \
        mv -v \${LFS}/usr/share/man/man1/chroot.1 \${LFS}/usr/share/man/man8/chroot.8 && \
        sed -i 's/\"1\"/\"8\"/' \${LFS}/usr/share/man/man8/chroot.8
    "
}

build_diffutils_temp() {
    _cross_build "diffutils" "Diffutils (temp)" "
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} \
                    --build=\$(./build-aux/config.guess) && \
        make && make DESTDIR=\${LFS} install
    "
}

build_file_temp() {
    _cross_build "file" "File (temp)" "
        mkdir -pv build && pushd build && \
        ../configure --disable-bzlib --disable-libseccomp \
                     --disable-xzlib --disable-zlib && \
        make && popd && \
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} \
                    --build=\$(./config.guess) && \
        make FILE_COMPILE=\$(pwd)/build/src/file && \
        make DESTDIR=\${LFS} install && \
        rm -v \${LFS}/usr/lib/libmagic.la
    "
}

build_findutils_temp() {
    _cross_build "findutils" "Findutils (temp)" "
        ./configure --prefix=/usr \
                    --localstatedir=/var/lib/locate \
                    --host=\${LFS_TGT} \
                    --build=\$(build-aux/config.guess) && \
        make && make DESTDIR=\${LFS} install
    "
}

build_gawk_temp() {
    _cross_build "gawk" "Gawk (temp)" "
        sed -i 's/extras//' Makefile.in && \
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} \
                    --build=\$(build-aux/config.guess) && \
        make && make DESTDIR=\${LFS} install
    "
}

build_grep_temp() {
    _cross_build "grep" "Grep (temp)" "
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} \
                    --build=\$(./build-aux/config.guess) && \
        make && make DESTDIR=\${LFS} install
    "
}

build_gzip_temp() {
    _cross_build "gzip" "Gzip (temp)" "
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} && \
        make && make DESTDIR=\${LFS} install
    "
}

build_make_temp() {
    _cross_build "make" "Make (temp)" "
        ./configure --prefix=/usr \
                    --without-guile \
                    --host=\${LFS_TGT} \
                    --build=\$(build-aux/config.guess) && \
        make && make DESTDIR=\${LFS} install
    "
}

build_patch_temp() {
    _cross_build "patch" "Patch (temp)" "
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} \
                    --build=\$(build-aux/config.guess) && \
        make && make DESTDIR=\${LFS} install
    "
}

build_sed_temp() {
    _cross_build "sed" "Sed (temp)" "
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} \
                    --build=\$(./build-aux/config.guess) && \
        make && make DESTDIR=\${LFS} install
    "
}

build_tar_temp() {
    _cross_build "tar" "Tar (temp)" "
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} \
                    --build=\$(build-aux/config.guess) && \
        make && make DESTDIR=\${LFS} install
    "
}

build_xz_temp() {
    _cross_build "xz" "Xz (temp)" "
        ./configure --prefix=/usr \
                    --host=\${LFS_TGT} \
                    --build=\$(build-aux/config.guess) \
                    --disable-static \
                    --docdir=/usr/share/doc/xz && \
        make && make DESTDIR=\${LFS} install && \
        rm -v \${LFS}/usr/lib/liblzma.la
    "
}

build_binutils_pass2() {
    einfo "=== Binutils Pass 2 ==="
    local srcdir
    srcdir=$(extract_source "binutils")

    build_as_lfs "Binutils Pass 2" "
        cd '${srcdir}' && \
        sed '6009s/\\\()\\)/\\1444444)/' -i ltmain.sh && \
        mkdir -pv build && cd build && \
        ../configure --prefix=/usr \
                     --build=\$(../config.guess) \
                     --host=\${LFS_TGT} \
                     --disable-nls \
                     --enable-shared \
                     --enable-gprofng=no \
                     --disable-werror \
                     --enable-64-bit-bfd \
                     --enable-new-dtags \
                     --enable-default-hash-style=gnu && \
        make && make DESTDIR=\${LFS} install && \
        rm -v \${LFS}/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
    "

    rm -rf "${srcdir}"
    einfo "Binutils Pass 2 complete"
}

build_gcc_pass2() {
    einfo "=== GCC Pass 2 ==="
    local srcdir
    srcdir=$(extract_source "gcc")

    local mpfr_dir gmp_dir mpc_dir
    mpfr_dir=$(extract_source "mpfr")
    gmp_dir=$(extract_source "gmp")
    mpc_dir=$(extract_source "mpc")
    mv "${mpfr_dir}" "${srcdir}/mpfr"
    mv "${gmp_dir}" "${srcdir}/gmp"
    mv "${mpc_dir}" "${srcdir}/mpc"

    build_as_lfs "GCC Pass 2" "
        cd '${srcdir}' && \
        case \$(uname -m) in
            x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;;
        esac && \
        sed '/thread_header =/s/@.*@/gthr-posix.h/' \
            -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in && \
        mkdir -pv build && cd build && \
        ../configure --build=\$(../config.guess) \
                     --host=\${LFS_TGT} \
                     --target=\${LFS_TGT} \
                     LDFLAGS_FOR_TARGET=-L\${PWD}/\${LFS_TGT}/libgcc \
                     --prefix=/usr \
                     --with-build-sysroot=\${LFS} \
                     --enable-default-pie \
                     --enable-default-ssp \
                     --disable-nls \
                     --disable-multilib \
                     --disable-libatomic \
                     --disable-libgomp \
                     --disable-libquadmath \
                     --disable-libsanitizer \
                     --disable-libssp \
                     --disable-libvtv \
                     --enable-languages=c,c++ && \
        make && make DESTDIR=\${LFS} install && \
        ln -sfv gcc \${LFS}/usr/bin/cc
    "

    rm -rf "${srcdir}"
    einfo "GCC Pass 2 complete"
}

# ========== Chapter 7: Additional temporary tools (in chroot) ==========

# These are built inside the chroot after virtual kernel filesystems are mounted

build_gettext_temp() {
    einfo "=== Gettext (temp, chroot) ==="
    chroot_exec "
        cd /sources && \
        tar xf gettext-*.tar.xz && cd gettext-*/ && \
        ./configure --disable-shared && \
        make && \
        cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin && \
        cd /sources && rm -rf gettext-*/
    "
}

build_bison_temp() {
    einfo "=== Bison (temp, chroot) ==="
    chroot_exec "
        cd /sources && \
        tar xf bison-*.tar.xz && cd bison-*/ && \
        ./configure --prefix=/usr --docdir=/usr/share/doc/bison && \
        make && make install && \
        cd /sources && rm -rf bison-*/
    "
}

build_perl_temp() {
    einfo "=== Perl (temp, chroot) ==="
    chroot_exec "
        cd /sources && \
        tar xf perl-*.tar.xz && cd perl-*/ && \
        sh Configure -des \
                     -D prefix=/usr \
                     -D vendorprefix=/usr \
                     -D useshrplib \
                     -D privlib=/usr/lib/perl5/5.40/core_perl \
                     -D archlib=/usr/lib/perl5/5.40/core_perl \
                     -D sitelib=/usr/lib/perl5/5.40/site_perl \
                     -D sitearch=/usr/lib/perl5/5.40/site_perl \
                     -D vendorlib=/usr/lib/perl5/5.40/vendor_perl \
                     -D vendorarch=/usr/lib/perl5/5.40/vendor_perl && \
        make && make install && \
        cd /sources && rm -rf perl-*/
    "
}

build_python_temp() {
    einfo "=== Python (temp, chroot) ==="
    chroot_exec "
        cd /sources && \
        tar xf Python-*.tar.xz && cd Python-*/ && \
        ./configure --prefix=/usr \
                    --enable-shared \
                    --without-ensurepip && \
        make && make install && \
        cd /sources && rm -rf Python-*/
    "
}

build_texinfo_temp() {
    einfo "=== Texinfo (temp, chroot) ==="
    chroot_exec "
        cd /sources && \
        tar xf texinfo-*.tar.xz && cd texinfo-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf texinfo-*/
    "
}

build_util_linux_temp() {
    einfo "=== Util-linux (temp, chroot) ==="
    chroot_exec "
        cd /sources && \
        tar xf util-linux-*.tar.xz && cd util-linux-*/ && \
        mkdir -pv /var/lib/hwclock && \
        ./configure --libdir=/usr/lib \
                    --runstatedir=/run \
                    --disable-chfn-chsh \
                    --disable-login \
                    --disable-nologin \
                    --disable-su \
                    --disable-setpriv \
                    --disable-runuser \
                    --disable-pylibmount \
                    --disable-static \
                    --disable-liblastlog2 \
                    --without-python \
                    ADJTIME_PATH=/var/lib/hwclock/adjtime \
                    --docdir=/usr/share/doc/util-linux && \
        make && make install && \
        cd /sources && rm -rf util-linux-*/
    "
}

# ========== Master functions ==========

# build_temp_tools — Chapter 6: all cross-compiled temp tools
build_temp_tools() {
    einfo "========================================="
    einfo "Building cross-compiled temporary tools"
    einfo "========================================="

    build_m4
    build_ncurses
    build_bash_temp
    build_coreutils_temp
    build_diffutils_temp
    build_file_temp
    build_findutils_temp
    build_gawk_temp
    build_grep_temp
    build_gzip_temp
    build_make_temp
    build_patch_temp
    build_sed_temp
    build_tar_temp
    build_xz_temp
    build_binutils_pass2
    build_gcc_pass2

    einfo "All cross-compiled temporary tools complete!"
}

# build_chroot_tools — Chapter 7: additional tools built inside chroot
build_chroot_tools() {
    einfo "========================================="
    einfo "Building additional tools in chroot"
    einfo "========================================="

    build_gettext_temp
    build_bison_temp
    build_perl_temp
    build_python_temp
    build_texinfo_temp
    build_util_linux_temp

    # Clean up
    chroot_exec "rm -rf /usr/share/{info,man,doc}/*"
    chroot_exec "find /usr/{lib,libexec} -name '*.la' -delete"

    einfo "Chroot temporary tools complete!"
}
