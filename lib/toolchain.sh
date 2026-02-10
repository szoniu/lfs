#!/usr/bin/env bash
# toolchain.sh — Chapter 5: Cross-compilation toolchain
# Builds the initial cross-toolchain: binutils pass1, gcc pass1,
# linux API headers, glibc, and libstdc++
source "${LIB_DIR}/protection.sh"

# build_as_lfs — Run a build command as the lfs user
build_as_lfs() {
    local desc="$1"
    shift
    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would build as lfs: $*"
        return 0
    fi
    try "${desc}" su - lfs -c "
        set -e
        export LFS=${LFS}
        export LFS_TGT=${LFS_TGT}
        export PATH=${LFS}/tools/bin:/usr/bin:/bin
        export CONFIG_SITE=${LFS}/usr/share/config.site
        export MAKEFLAGS=\"${MAKEFLAGS:--j$(nproc)}\"
        $*
    "
}

# --- Chapter 5.2: Binutils Pass 1 ---

build_binutils_pass1() {
    einfo "=== Binutils Pass 1 ==="
    local srcdir
    srcdir=$(extract_source "binutils")

    build_as_lfs "Binutils Pass 1" "
        cd '${srcdir}' && \
        mkdir -pv build && cd build && \
        ../configure --prefix=\${LFS}/tools \
                     --with-sysroot=\${LFS} \
                     --target=\${LFS_TGT} \
                     --disable-nls \
                     --enable-gprofng=no \
                     --disable-werror \
                     --enable-new-dtags \
                     --enable-default-hash-style=gnu && \
        make && make install
    "

    rm -rf "${srcdir}"
    einfo "Binutils Pass 1 complete"
}

# --- Chapter 5.3: GCC Pass 1 ---

build_gcc_pass1() {
    einfo "=== GCC Pass 1 ==="
    local srcdir
    srcdir=$(extract_source "gcc")

    # Extract GCC prerequisites into the source tree
    local mpfr_dir gmp_dir mpc_dir
    mpfr_dir=$(extract_source "mpfr")
    gmp_dir=$(extract_source "gmp")
    mpc_dir=$(extract_source "mpc")

    mv "${mpfr_dir}" "${srcdir}/mpfr"
    mv "${gmp_dir}" "${srcdir}/gmp"
    mv "${mpc_dir}" "${srcdir}/mpc"

    build_as_lfs "GCC Pass 1" "
        cd '${srcdir}' && \
        case \$(uname -m) in
            x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;;
        esac && \
        mkdir -pv build && cd build && \
        ../configure --target=\${LFS_TGT} \
                     --prefix=\${LFS}/tools \
                     --with-glibc-version=2.40 \
                     --with-sysroot=\${LFS} \
                     --with-newlib \
                     --without-headers \
                     --enable-default-pie \
                     --enable-default-ssp \
                     --disable-nls \
                     --disable-shared \
                     --disable-multilib \
                     --disable-threads \
                     --disable-libatomic \
                     --disable-libgomp \
                     --disable-libquadmath \
                     --disable-libssp \
                     --disable-libvtv \
                     --disable-libstdcxx \
                     --enable-languages=c,c++ && \
        make && make install && \
        cd .. && \
        cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
            \$(dirname \$(\${LFS_TGT}-gcc -print-libgcc-file-name))/include/limits.h
    "

    rm -rf "${srcdir}"
    einfo "GCC Pass 1 complete"
}

# --- Chapter 5.4: Linux API Headers ---

build_linux_headers() {
    einfo "=== Linux API Headers ==="
    local srcdir
    srcdir=$(extract_source "linux")

    build_as_lfs "Linux API Headers" "
        cd '${srcdir}' && \
        make mrproper && \
        make headers && \
        find usr/include -type f ! -name '*.h' -delete && \
        cp -rv usr/include \${LFS}/usr
    "

    rm -rf "${srcdir}"
    einfo "Linux API Headers complete"
}

# --- Chapter 5.5: Glibc ---

build_glibc() {
    einfo "=== Glibc ==="
    local srcdir
    srcdir=$(extract_source "glibc")

    build_as_lfs "Glibc" "
        cd '${srcdir}' && \
        case \$(uname -m) in
            i?86) ln -sfv ld-linux.so.2 \${LFS}/lib/ld-lsb.so.3 ;;
            x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 \${LFS}/lib64
                    ln -sfv ../lib/ld-linux-x86-64.so.2 \${LFS}/lib64/ld-lsb-x86-64.so.3 ;;
        esac && \
        mkdir -pv build && cd build && \
        echo 'rootsbindir=/usr/sbin' > configparms && \
        ../configure --prefix=/usr \
                     --host=\${LFS_TGT} \
                     --build=\$(../scripts/config.guess) \
                     --enable-kernel=4.19 \
                     --with-headers=\${LFS}/usr/include \
                     --disable-nscd \
                     libc_cv_slibdir=/usr/lib && \
        make && make DESTDIR=\${LFS} install && \
        sed '/RTLDLIST=/s@/usr@@g' -i \${LFS}/usr/bin/ldd
    "

    # Sanity check
    einfo "Running glibc sanity check..."
    build_as_lfs "Glibc sanity check" "
        echo 'int main(){}' | \${LFS_TGT}-gcc -xc - -o /tmp/lfs-test
        readelf -l /tmp/lfs-test | grep ld-linux
        rm -fv /tmp/lfs-test
    "

    rm -rf "${srcdir}"
    einfo "Glibc complete"
}

# --- Chapter 5.6: Libstdc++ Pass 1 ---

build_libstdcxx_pass1() {
    einfo "=== Libstdc++ Pass 1 ==="
    local srcdir
    srcdir=$(extract_source "gcc")

    build_as_lfs "Libstdc++ Pass 1" "
        cd '${srcdir}' && \
        mkdir -pv build && cd build && \
        ../libstdc++-v3/configure --host=\${LFS_TGT} \
                                  --build=\$(../config.guess) \
                                  --prefix=/usr \
                                  --disable-multilib \
                                  --disable-nls \
                                  --disable-libstdcxx-pch \
                                  --with-gxx-include-dir=/tools/\${LFS_TGT}/include/c++/\$(../gcc/BASE-VER 2>/dev/null || cat ../gcc/BASE-VER) && \
        make && make DESTDIR=\${LFS} install && \
        rm -v \${LFS}/usr/lib/lib{stdc++{,exp,fs},supc++}.la
    "

    rm -rf "${srcdir}"
    einfo "Libstdc++ Pass 1 complete"
}

# --- Master function ---

# build_cross_toolchain — Build entire Chapter 5 cross-toolchain
build_cross_toolchain() {
    einfo "========================================="
    einfo "Building cross-compilation toolchain"
    einfo "Target: ${LFS_TGT}"
    einfo "========================================="

    build_binutils_pass1
    build_gcc_pass1
    build_linux_headers
    build_glibc
    build_libstdcxx_pass1

    einfo "Cross-toolchain build complete!"
}
