#!/usr/bin/env bash
# finalsystem.sh — Chapter 8: Building the LFS final system
# Contains build functions for all ~80 packages in strict dependency order
source "${LIB_DIR}/protection.sh"

# Helper: build a package inside chroot
# Usage: _chroot_build "Package Name" "commands..."
_chroot_build() {
    local name="$1"
    shift
    einfo "=== Building: ${name} ==="

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would build: ${name}"
        return 0
    fi

    chroot_exec "$@"
    einfo "${name} complete"
}

# --- Chapter 8 packages in build order ---

build_man_pages() {
    _chroot_build "Man-pages" "
        cd /sources && tar xf man-pages-*.tar.xz && cd man-pages-*/ && \
        rm -v man3/crypt* && \
        make prefix=/usr install && \
        cd /sources && rm -rf man-pages-*/
    "
}

build_iana_etc() {
    _chroot_build "Iana-Etc" "
        cd /sources && tar xf iana-etc-*.tar.gz && cd iana-etc-*/ && \
        cp services protocols /etc && \
        cd /sources && rm -rf iana-etc-*/
    "
}

build_glibc_final() {
    _chroot_build "Glibc" "
        cd /sources && tar xf glibc-*.tar.xz && cd glibc-*/ && \
        patch -Np1 -i ../glibc-*-fhs-1.patch 2>/dev/null || true && \
        mkdir -pv build && cd build && \
        echo 'rootsbindir=/usr/sbin' > configparms && \
        ../configure --prefix=/usr \
                     --disable-werror \
                     --enable-kernel=4.19 \
                     --enable-stack-protector=strong \
                     --disable-nscd \
                     libc_cv_slibdir=/usr/lib && \
        make && \
        touch /etc/ld.so.conf && \
        sed '/test-hierarchical-cleanup/d' -i ../Makefile 2>/dev/null || true && \
        make install && \
        sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd && \
        mkdir -pv /usr/lib/locale && \
        localedef -i C -f UTF-8 C.UTF-8 && \
        localedef -i en_US -f UTF-8 en_US.UTF-8 && \
        cd /sources && rm -rf glibc-*/
    "

    # Configure nsswitch.conf
    chroot_exec "
        cat > /etc/nsswitch.conf << 'NSSEOF'
passwd: files
group: files
shadow: files
hosts: files dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
NSSEOF
    "

    # Configure ld.so.conf
    chroot_exec "
        cat > /etc/ld.so.conf << 'LDEOF'
/usr/local/lib
/opt/lib
LDEOF
    "
}

build_zlib() {
    _chroot_build "Zlib" "
        cd /sources && tar xf zlib-*.tar.gz && cd zlib-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        rm -fv /usr/lib/libz.a && \
        cd /sources && rm -rf zlib-*/
    "
}

build_bzip2() {
    _chroot_build "Bzip2" "
        cd /sources && tar xf bzip2-*.tar.gz && cd bzip2-*/ && \
        patch -Np1 -i ../bzip2-*-install_docs-1.patch 2>/dev/null || true && \
        sed -i 's@\(ln -s -f \)\$(PREFIX)/bin/@\1@' Makefile && \
        sed -i 's@(PREFIX)/man@(PREFIX)/share/man@g' Makefile && \
        make -f Makefile-libbz2_so && make clean && \
        make && make PREFIX=/usr install && \
        cp -av libbz2.so.* /usr/lib && \
        ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so && \
        cp -v bzip2-shared /usr/bin/bzip2 && \
        for i in bunzip2 bzcat; do ln -sfv bzip2 /usr/bin/\$i; done && \
        rm -fv /usr/lib/libbz2.a && \
        cd /sources && rm -rf bzip2-*/
    "
}

build_xz_final() {
    _chroot_build "Xz" "
        cd /sources && tar xf xz-*.tar.xz && cd xz-*/ && \
        ./configure --prefix=/usr \
                    --disable-static \
                    --docdir=/usr/share/doc/xz && \
        make && make install && \
        cd /sources && rm -rf xz-*/
    "
}

build_lz4() {
    _chroot_build "Lz4" "
        cd /sources && tar xf lz4-*.tar.gz && cd lz4-*/ && \
        make BUILD_STATIC=no PREFIX=/usr && \
        make BUILD_STATIC=no PREFIX=/usr install && \
        cd /sources && rm -rf lz4-*/
    "
}

build_zstd() {
    _chroot_build "Zstd" "
        cd /sources && tar xf zstd-*.tar.gz && cd zstd-*/ && \
        make prefix=/usr && \
        make prefix=/usr install && \
        rm -v /usr/lib/libzstd.a && \
        cd /sources && rm -rf zstd-*/
    "
}

build_file_final() {
    _chroot_build "File" "
        cd /sources && tar xf file-*.tar.gz && cd file-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf file-*/
    "
}

build_readline() {
    _chroot_build "Readline" "
        cd /sources && tar xf readline-*.tar.gz && cd readline-*/ && \
        sed -i '/MV.*telescreen/d' Makefile.in && \
        sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf && \
        ./configure --prefix=/usr \
                    --disable-static \
                    --with-curses \
                    --docdir=/usr/share/doc/readline && \
        make SHLIB_LIBS=\"-lncursesw\" && \
        make SHLIB_LIBS=\"-lncursesw\" install && \
        cd /sources && rm -rf readline-*/
    "
}

build_m4_final() {
    _chroot_build "M4" "
        cd /sources && tar xf m4-*.tar.xz && cd m4-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf m4-*/
    "
}

build_bc() {
    _chroot_build "Bc" "
        cd /sources && tar xf bc-*.tar.xz && cd bc-*/ && \
        CC=gcc ./configure --prefix=/usr -G -O3 -r && \
        make && make install && \
        cd /sources && rm -rf bc-*/
    "
}

build_flex() {
    _chroot_build "Flex" "
        cd /sources && tar xf flex-*.tar.gz && cd flex-*/ && \
        ./configure --prefix=/usr \
                    --docdir=/usr/share/doc/flex \
                    --disable-static && \
        make && make install && \
        ln -sv flex /usr/bin/lex && \
        ln -sv flex.1 /usr/share/man/man1/lex.1 && \
        cd /sources && rm -rf flex-*/
    "
}

build_tcl() {
    _chroot_build "Tcl" "
        cd /sources && tar xf tcl*-src.tar.gz && cd tcl*/ && \
        SRCDIR=\$(pwd) && \
        cd unix && \
        ./configure --prefix=/usr \
                    --mandir=/usr/share/man \
                    --disable-rpath && \
        make && \
        sed -e 's|^\(TCL_SRC_DIR=\).*|\1/usr/include|' \
            -e '/TCL_B/s|=.*|=/usr/lib|' \
            -i tclConfig.sh && \
        make install && \
        chmod -v u+w /usr/lib/libtcl*.so && \
        make install-private-headers && \
        ln -sfv tclsh8.6 /usr/bin/tclsh && \
        cd /sources && rm -rf tcl*/
    "
}

build_expect() {
    _chroot_build "Expect" "
        cd /sources && tar xf expect*.tar.gz && cd expect*/ && \
        python3 -c 'import pty' 2>/dev/null || true && \
        ./configure --prefix=/usr \
                    --with-tcl=/usr/lib \
                    --enable-shared \
                    --disable-rpath \
                    --mandir=/usr/share/man \
                    --with-tclinclude=/usr/include && \
        make && make install && \
        ln -sfv expect*/libexpect*.so /usr/lib && \
        cd /sources && rm -rf expect*/
    "
}

build_dejagnu() {
    _chroot_build "DejaGNU" "
        cd /sources && tar xf dejagnu-*.tar.gz && cd dejagnu-*/ && \
        mkdir -pv build && cd build && \
        ../configure --prefix=/usr && \
        makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi 2>/dev/null || true && \
        make install && \
        cd /sources && rm -rf dejagnu-*/
    "
}

build_pkgconf() {
    _chroot_build "Pkgconf" "
        cd /sources && tar xf pkgconf-*.tar.xz && cd pkgconf-*/ && \
        ./configure --prefix=/usr \
                    --disable-static \
                    --docdir=/usr/share/doc/pkgconf && \
        make && make install && \
        ln -sv pkgconf /usr/bin/pkg-config && \
        ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1 && \
        cd /sources && rm -rf pkgconf-*/
    "
}

build_binutils_final() {
    _chroot_build "Binutils" "
        cd /sources && tar xf binutils-*.tar.xz && cd binutils-*/ && \
        mkdir -pv build && cd build && \
        ../configure --prefix=/usr \
                     --sysconfdir=/etc \
                     --enable-gold \
                     --enable-ld=default \
                     --enable-plugins \
                     --enable-shared \
                     --disable-werror \
                     --enable-64-bit-bfd \
                     --enable-new-dtags \
                     --with-system-zlib \
                     --enable-default-hash-style=gnu && \
        make tooldir=/usr && make tooldir=/usr install && \
        rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a && \
        cd /sources && rm -rf binutils-*/
    "
}

build_gmp() {
    _chroot_build "GMP" "
        cd /sources && tar xf gmp-*.tar.xz && cd gmp-*/ && \
        ./configure --prefix=/usr \
                    --enable-cxx \
                    --disable-static \
                    --docdir=/usr/share/doc/gmp && \
        make && make html && make install && make install-html && \
        cd /sources && rm -rf gmp-*/
    "
}

build_mpfr() {
    _chroot_build "MPFR" "
        cd /sources && tar xf mpfr-*.tar.xz && cd mpfr-*/ && \
        ./configure --prefix=/usr \
                    --disable-static \
                    --enable-thread-safe \
                    --docdir=/usr/share/doc/mpfr && \
        make && make html && make install && make install-html && \
        cd /sources && rm -rf mpfr-*/
    "
}

build_mpc() {
    _chroot_build "MPC" "
        cd /sources && tar xf mpc-*.tar.gz && cd mpc-*/ && \
        ./configure --prefix=/usr \
                    --disable-static \
                    --docdir=/usr/share/doc/mpc && \
        make && make html && make install && make install-html && \
        cd /sources && rm -rf mpc-*/
    "
}

build_attr() {
    _chroot_build "Attr" "
        cd /sources && tar xf attr-*.tar.gz && cd attr-*/ && \
        ./configure --prefix=/usr \
                    --disable-static \
                    --sysconfdir=/etc \
                    --docdir=/usr/share/doc/attr && \
        make && make install && \
        cd /sources && rm -rf attr-*/
    "
}

build_acl() {
    _chroot_build "Acl" "
        cd /sources && tar xf acl-*.tar.xz && cd acl-*/ && \
        ./configure --prefix=/usr \
                    --disable-static \
                    --docdir=/usr/share/doc/acl && \
        make && make install && \
        cd /sources && rm -rf acl-*/
    "
}

build_libcap() {
    _chroot_build "Libcap" "
        cd /sources && tar xf libcap-*.tar.xz && cd libcap-*/ && \
        sed -i '/install -m.*STA/d' libcap/Makefile && \
        make prefix=/usr lib=lib && \
        make prefix=/usr lib=lib install && \
        cd /sources && rm -rf libcap-*/
    "
}

build_libxcrypt() {
    _chroot_build "Libxcrypt" "
        cd /sources && tar xf libxcrypt-*.tar.xz && cd libxcrypt-*/ && \
        ./configure --prefix=/usr \
                    --enable-hashes=strong,glibc \
                    --enable-obsolete-api=no \
                    --disable-static \
                    --disable-failure-tokens && \
        make && make install && \
        cd /sources && rm -rf libxcrypt-*/
    "
}

build_shadow() {
    _chroot_build "Shadow" "
        cd /sources && tar xf shadow-*.tar.xz && cd shadow-*/ && \
        sed -i 's/groups\$(EXEEXT) //' src/Makefile.in && \
        find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \\; && \
        find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \\; && \
        find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \\; && \
        sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
            -e 's:/var/spool/mail:/var/mail:' \
            -e '/PATH=/{s@/sbin:@@;s@/bin:@@}' \
            -i etc/login.defs && \
        touch /usr/bin/passwd && \
        ./configure --sysconfdir=/etc \
                    --disable-static \
                    --with-{b,yes}crypt \
                    --without-libbsd \
                    --with-group-name-max-length=32 && \
        make && make exec_prefix=/usr install && \
        make -C man install-man && \
        pwconv && grpconv && \
        mkdir -p /etc/default && \
        useradd -D --gid 999 2>/dev/null || true && \
        cd /sources && rm -rf shadow-*/
    "
}

build_gcc_final() {
    _chroot_build "GCC" "
        cd /sources && tar xf gcc-*.tar.xz && cd gcc-*/ && \
        case \$(uname -m) in
            x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;;
        esac && \
        mkdir -pv build && cd build && \
        ../configure --prefix=/usr \
                     LD=ld \
                     --enable-languages=c,c++ \
                     --enable-default-pie \
                     --enable-default-ssp \
                     --enable-host-pie \
                     --disable-multilib \
                     --disable-bootstrap \
                     --disable-fixincludes \
                     --with-system-zlib && \
        make && make install && \
        chown -v -R root:root /usr/lib/gcc/\$(gcc -dumpmachine)/\$(gcc -dumpversion)/include{,-fixed} 2>/dev/null || true && \
        ln -svr /usr/bin/cpp /usr/lib && \
        ln -sv gcc.1 /usr/share/man/man1/cc.1 && \
        ln -sfv ../../libexec/gcc/\$(gcc -dumpmachine)/\$(gcc -dumpversion)/liblto_plugin.so \
                /usr/lib/bfd-plugins/ && \
        mkdir -pv /usr/share/gdb/auto-load/usr/lib && \
        mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib 2>/dev/null || true && \
        cd /sources && rm -rf gcc-*/
    "
}

build_ncurses_final() {
    _chroot_build "Ncurses" "
        cd /sources && tar xf ncurses-*.tar.gz && cd ncurses-*/ && \
        ./configure --prefix=/usr \
                    --mandir=/usr/share/man \
                    --with-shared \
                    --without-debug \
                    --without-normal \
                    --with-cxx-shared \
                    --enable-pc-files \
                    --with-pkg-config-libdir=/usr/lib/pkgconfig && \
        make && make DESTDIR='' install && \
        for lib in ncurses form panel menu; do
            ln -sfv lib\${lib}w.so /usr/lib/lib\${lib}.so
            ln -sfv \${lib}w.pc /usr/lib/pkgconfig/\${lib}.pc
        done && \
        ln -sfv libncursesw.so /usr/lib/libcurses.so && \
        cp -v -R doc -T /usr/share/doc/ncurses 2>/dev/null || true && \
        cd /sources && rm -rf ncurses-*/
    "
}

build_sed_final() {
    _chroot_build "Sed" "
        cd /sources && tar xf sed-*.tar.xz && cd sed-*/ && \
        ./configure --prefix=/usr && \
        make && make html && make install && \
        cd /sources && rm -rf sed-*/
    "
}

build_psmisc() {
    _chroot_build "Psmisc" "
        cd /sources && tar xf psmisc-*.tar.xz && cd psmisc-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf psmisc-*/
    "
}

build_gettext_final() {
    _chroot_build "Gettext" "
        cd /sources && tar xf gettext-*.tar.xz && cd gettext-*/ && \
        ./configure --prefix=/usr \
                    --disable-static \
                    --docdir=/usr/share/doc/gettext && \
        make && make install && \
        chmod -v 0755 /usr/lib/preloadable_libintl.so && \
        cd /sources && rm -rf gettext-*/
    "
}

build_bison_final() {
    _chroot_build "Bison" "
        cd /sources && tar xf bison-*.tar.xz && cd bison-*/ && \
        ./configure --prefix=/usr --docdir=/usr/share/doc/bison && \
        make && make install && \
        cd /sources && rm -rf bison-*/
    "
}

build_grep_final() {
    _chroot_build "Grep" "
        cd /sources && tar xf grep-*.tar.xz && cd grep-*/ && \
        sed -i 's/echo/#echo/' src/egrep.sh 2>/dev/null || true && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf grep-*/
    "
}

build_bash_final() {
    _chroot_build "Bash" "
        cd /sources && tar xf bash-*.tar.gz && cd bash-*/ && \
        ./configure --prefix=/usr \
                    --without-bash-malloc \
                    --with-installed-readline \
                    bash_cv_strtold_broken=no \
                    --docdir=/usr/share/doc/bash && \
        make && make install && \
        cd /sources && rm -rf bash-*/
    "
}

build_libtool() {
    _chroot_build "Libtool" "
        cd /sources && tar xf libtool-*.tar.xz && cd libtool-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        rm -fv /usr/lib/libltdl.a && \
        cd /sources && rm -rf libtool-*/
    "
}

build_gdbm() {
    _chroot_build "GDBM" "
        cd /sources && tar xf gdbm-*.tar.gz && cd gdbm-*/ && \
        ./configure --prefix=/usr \
                    --disable-static \
                    --enable-libgdbm-compat && \
        make && make install && \
        cd /sources && rm -rf gdbm-*/
    "
}

build_gperf() {
    _chroot_build "Gperf" "
        cd /sources && tar xf gperf-*.tar.gz && cd gperf-*/ && \
        ./configure --prefix=/usr --docdir=/usr/share/doc/gperf && \
        make && make install && \
        cd /sources && rm -rf gperf-*/
    "
}

build_expat() {
    _chroot_build "Expat" "
        cd /sources && tar xf expat-*.tar.xz && cd expat-*/ && \
        ./configure --prefix=/usr \
                    --disable-static \
                    --docdir=/usr/share/doc/expat && \
        make && make install && \
        cd /sources && rm -rf expat-*/
    "
}

build_inetutils() {
    _chroot_build "Inetutils" "
        cd /sources && tar xf inetutils-*.tar.xz && cd inetutils-*/ && \
        sed -i 's/def HAVE_DECL_GETCWD/def GETCWD_CANT_MALLOC/' lib/canonicalize.c 2>/dev/null || true && \
        ./configure --prefix=/usr \
                    --bindir=/usr/bin \
                    --localstatedir=/var \
                    --disable-logger \
                    --disable-whois \
                    --disable-rcp \
                    --disable-rexec \
                    --disable-rlogin \
                    --disable-rsh \
                    --disable-servers && \
        make && make install && \
        mv -v /usr/{,s}bin/ifconfig && \
        cd /sources && rm -rf inetutils-*/
    "
}

build_less() {
    _chroot_build "Less" "
        cd /sources && tar xf less-*.tar.gz && cd less-*/ && \
        ./configure --prefix=/usr --sysconfdir=/etc && \
        make && make install && \
        cd /sources && rm -rf less-*/
    "
}

build_perl_final() {
    _chroot_build "Perl" "
        cd /sources && tar xf perl-*.tar.xz && cd perl-*/ && \
        export BUILD_ZLIB=False BUILD_BZIP2=0 && \
        sh Configure -des \
                     -D prefix=/usr \
                     -D vendorprefix=/usr \
                     -D privlib=/usr/lib/perl5/5.40/core_perl \
                     -D archlib=/usr/lib/perl5/5.40/core_perl \
                     -D sitelib=/usr/lib/perl5/5.40/site_perl \
                     -D sitearch=/usr/lib/perl5/5.40/site_perl \
                     -D vendorlib=/usr/lib/perl5/5.40/vendor_perl \
                     -D vendorarch=/usr/lib/perl5/5.40/vendor_perl \
                     -D man1dir=/usr/share/man/man1 \
                     -D man3dir=/usr/share/man/man3 \
                     -D pager='/usr/bin/less -isR' \
                     -D useshrplib \
                     -D usethreads && \
        make && make install && \
        unset BUILD_ZLIB BUILD_BZIP2 && \
        cd /sources && rm -rf perl-*/
    "
}

build_xml_parser() {
    _chroot_build "XML::Parser" "
        cd /sources && tar xf XML-Parser-*.tar.gz && cd XML-Parser-*/ && \
        perl Makefile.PL && \
        make && make install && \
        cd /sources && rm -rf XML-Parser-*/
    "
}

build_intltool() {
    _chroot_build "Intltool" "
        cd /sources && tar xf intltool-*.tar.gz && cd intltool-*/ && \
        sed -i 's:\\\${:\\\$\\{:' intltool-update.in 2>/dev/null || true && \
        ./configure --prefix=/usr && \
        make && make install && \
        install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool/I18N-HOWTO && \
        cd /sources && rm -rf intltool-*/
    "
}

build_autoconf() {
    _chroot_build "Autoconf" "
        cd /sources && tar xf autoconf-*.tar.xz && cd autoconf-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf autoconf-*/
    "
}

build_automake() {
    _chroot_build "Automake" "
        cd /sources && tar xf automake-*.tar.xz && cd automake-*/ && \
        ./configure --prefix=/usr --docdir=/usr/share/doc/automake && \
        make && make install && \
        cd /sources && rm -rf automake-*/
    "
}

build_openssl() {
    _chroot_build "OpenSSL" "
        cd /sources && tar xf openssl-*.tar.gz && cd openssl-*/ && \
        ./config --prefix=/usr \
                 --openssldir=/etc/ssl \
                 --libdir=lib \
                 shared \
                 zlib-dynamic && \
        make && \
        sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile && \
        make MANSUFFIX=ssl install && \
        cd /sources && rm -rf openssl-*/
    "
}

build_kmod() {
    _chroot_build "Kmod" "
        cd /sources && tar xf kmod-*.tar.xz && cd kmod-*/ && \
        ./configure --prefix=/usr \
                    --sysconfdir=/etc \
                    --with-openssl \
                    --with-xz \
                    --with-zstd \
                    --with-zlib \
                    --disable-manpages && \
        make && make install && \
        for target in depmod insmod modinfo modprobe rmmod; do
            ln -sfv ../bin/kmod /usr/sbin/\$target
        done && \
        ln -sfv kmod /usr/bin/lsmod && \
        cd /sources && rm -rf kmod-*/
    "
}

build_elfutils() {
    _chroot_build "Elfutils" "
        cd /sources && tar xf elfutils-*.tar.bz2 && cd elfutils-*/ && \
        ./configure --prefix=/usr \
                    --disable-debuginfod \
                    --enable-libdebuginfod=dummy && \
        make && make -C libelf install && \
        install -vm644 config/libelf.pc /usr/lib/pkgconfig && \
        rm -f /usr/lib/libelf.a && \
        cd /sources && rm -rf elfutils-*/
    "
}

build_libffi() {
    _chroot_build "Libffi" "
        cd /sources && tar xf libffi-*.tar.gz && cd libffi-*/ && \
        ./configure --prefix=/usr \
                    --disable-static \
                    --with-gcc-arch=native && \
        make && make install && \
        cd /sources && rm -rf libffi-*/
    "
}

build_python_final() {
    _chroot_build "Python" "
        cd /sources && tar xf Python-*.tar.xz && cd Python-*/ && \
        ./configure --prefix=/usr \
                    --enable-shared \
                    --with-system-expat \
                    --enable-optimizations && \
        make && make install && \
        cat > /etc/pip.conf << 'PIPEOF'
[global]
root-user-action = ignore
disable-pip-version-check = true
PIPEOF
        cd /sources && rm -rf Python-*/
    "
}

build_flit_core() {
    _chroot_build "Flit-core" "
        cd /sources && tar xf flit_core-*.tar.gz && cd flit_core-*/ && \
        pip3 install --no-index --no-build-isolation --find-links /sources --root=/ --prefix=/usr . && \
        cd /sources && rm -rf flit_core-*/
    "
}

build_wheel() {
    _chroot_build "Wheel" "
        cd /sources && tar xf wheel-*.tar.gz && cd wheel-*/ && \
        pip3 install --no-index --no-build-isolation --find-links /sources --root=/ --prefix=/usr . && \
        cd /sources && rm -rf wheel-*/
    "
}

build_setuptools() {
    _chroot_build "Setuptools" "
        cd /sources && tar xf setuptools-*.tar.gz && cd setuptools-*/ && \
        pip3 install --no-index --no-build-isolation --find-links /sources --root=/ --prefix=/usr . && \
        cd /sources && rm -rf setuptools-*/
    "
}

build_ninja() {
    _chroot_build "Ninja" "
        cd /sources && tar xf ninja-*.tar.gz && cd ninja-*/ && \
        python3 configure.py --bootstrap && \
        install -vm755 ninja /usr/bin/ && \
        cd /sources && rm -rf ninja-*/
    "
}

build_meson() {
    _chroot_build "Meson" "
        cd /sources && tar xf meson-*.tar.gz && cd meson-*/ && \
        pip3 install --no-index --no-build-isolation --find-links /sources --root=/ --prefix=/usr . && \
        cd /sources && rm -rf meson-*/
    "
}

build_coreutils_final() {
    _chroot_build "Coreutils" "
        cd /sources && tar xf coreutils-*.tar.xz && cd coreutils-*/ && \
        patch -Np1 -i ../coreutils-*-i18n-2.patch 2>/dev/null || true && \
        ./configure --prefix=/usr \
                    --enable-no-install-program=kill,uptime && \
        make && make install && \
        mv -v /usr/bin/chroot /usr/sbin && \
        mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8 && \
        sed -i 's/\"1\"/\"8\"/' /usr/share/man/man8/chroot.8 && \
        cd /sources && rm -rf coreutils-*/
    "
}

build_check() {
    _chroot_build "Check" "
        cd /sources && tar xf check-*.tar.gz && cd check-*/ && \
        ./configure --prefix=/usr --disable-static && \
        make && make docdir=/usr/share/doc/check install && \
        cd /sources && rm -rf check-*/
    "
}

build_diffutils_final() {
    _chroot_build "Diffutils" "
        cd /sources && tar xf diffutils-*.tar.xz && cd diffutils-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf diffutils-*/
    "
}

build_gawk_final() {
    _chroot_build "Gawk" "
        cd /sources && tar xf gawk-*.tar.xz && cd gawk-*/ && \
        sed -i 's/extras//' Makefile.in && \
        ./configure --prefix=/usr && \
        make && \
        rm -f /usr/bin/gawk-* && \
        make install && \
        cd /sources && rm -rf gawk-*/
    "
}

build_findutils_final() {
    _chroot_build "Findutils" "
        cd /sources && tar xf findutils-*.tar.xz && cd findutils-*/ && \
        ./configure --prefix=/usr --localstatedir=/var/lib/locate && \
        make && make install && \
        cd /sources && rm -rf findutils-*/
    "
}

build_groff() {
    _chroot_build "Groff" "
        cd /sources && tar xf groff-*.tar.gz && cd groff-*/ && \
        PAGE=A4 ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf groff-*/
    "
}

build_grub() {
    _chroot_build "GRUB" "
        cd /sources && tar xf grub-*.tar.xz && cd grub-*/ && \
        unset {C,CPP,CXX,LD}FLAGS && \
        ./configure --prefix=/usr \
                    --sysconfdir=/etc \
                    --disable-efiemu \
                    --disable-werror && \
        make && make install && \
        mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions 2>/dev/null || true && \
        cd /sources && rm -rf grub-*/
    "
}

build_gzip_final() {
    _chroot_build "Gzip" "
        cd /sources && tar xf gzip-*.tar.xz && cd gzip-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf gzip-*/
    "
}

build_iproute2() {
    _chroot_build "IPRoute2" "
        cd /sources && tar xf iproute2-*.tar.xz && cd iproute2-*/ && \
        sed -i /ARPD/d Makefile && \
        rm -fv man/man8/arpd.8 && \
        make NETNS_RUN_DIR=/run/netns && \
        make SBINDIR=/usr/sbin install && \
        cd /sources && rm -rf iproute2-*/
    "
}

build_kbd() {
    _chroot_build "Kbd" "
        cd /sources && tar xf kbd-*.tar.xz && cd kbd-*/ && \
        patch -Np1 -i ../kbd-*-backspace-1.patch 2>/dev/null || true && \
        sed -i '/RESIZECONS_PROGS=/s/444//' configure && \
        sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in && \
        ./configure --prefix=/usr --disable-vlock && \
        make && make install && \
        cd /sources && rm -rf kbd-*/
    "
}

build_libpipeline() {
    _chroot_build "Libpipeline" "
        cd /sources && tar xf libpipeline-*.tar.gz && cd libpipeline-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf libpipeline-*/
    "
}

build_make_final() {
    _chroot_build "Make" "
        cd /sources && tar xf make-*.tar.gz && cd make-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf make-*/
    "
}

build_patch_final() {
    _chroot_build "Patch" "
        cd /sources && tar xf patch-*.tar.xz && cd patch-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf patch-*/
    "
}

build_tar_final() {
    _chroot_build "Tar" "
        cd /sources && tar xf tar-*.tar.xz && cd tar-*/ && \
        FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf tar-*/
    "
}

build_texinfo_final() {
    _chroot_build "Texinfo" "
        cd /sources && tar xf texinfo-*.tar.xz && cd texinfo-*/ && \
        ./configure --prefix=/usr && \
        make && make install && \
        cd /sources && rm -rf texinfo-*/
    "
}

build_vim() {
    _chroot_build "Vim" "
        cd /sources && tar xf vim-*.tar.gz && cd vim-*/ && \
        echo '#define SYS_VIMRC_FILE \"/etc/vimrc\"' >> src/feature.h && \
        ./configure --prefix=/usr && \
        make && make install && \
        ln -sv vim /usr/bin/vi && \
        for L in /usr/share/man/{,*/}man1/vim.1; do
            ln -sv vim.1 \$(dirname \$L)/vi.1 2>/dev/null || true
        done && \
        ln -sv ../vim/vim*/doc /usr/share/doc/vim 2>/dev/null || true && \
        cat > /etc/vimrc << 'VIMEOF'
source \$VIMRUNTIME/defaults.vim
let skip_defaults_vim = 1
set nocompatible
set backspace=2
set mouse=
VIMEOF
        cd /sources && rm -rf vim-*/
    "
}

build_markupsafe() {
    _chroot_build "MarkupSafe" "
        cd /sources && tar xf MarkupSafe-*.tar.gz && cd MarkupSafe-*/ && \
        pip3 install --no-index --no-build-isolation --find-links /sources --root=/ --prefix=/usr . && \
        cd /sources && rm -rf MarkupSafe-*/
    "
}

build_jinja2() {
    _chroot_build "Jinja2" "
        cd /sources && tar xf jinja2-*.tar.gz 2>/dev/null || tar xf Jinja2-*.tar.gz && \
        cd jinja2-*/ 2>/dev/null || cd Jinja2-*/ && \
        pip3 install --no-index --no-build-isolation --find-links /sources --root=/ --prefix=/usr . && \
        cd /sources && rm -rf jinja2-*/ Jinja2-*/
    "
}

build_udev() {
    _chroot_build "Udev (from systemd)" "
        cd /sources && tar xf systemd-*.tar.gz && cd systemd-*/ && \
        sed -i -e 's/want_hierarchical/GROUP://;s/want_tests//' Makefile.in 2>/dev/null || true && \
        mkdir -pv build && cd build && \
        meson setup .. \
              --prefix=/usr \
              --buildtype=release \
              -D mode=release \
              -D dev-kvm-mode=0660 \
              -D link-udev-shared=false \
              -D logind=false \
              -D vconsole=false && \
        ninja udevadm systemd-hwdb \
              \$(grep -o 'lib[a-z_]*\\.so[.0-9]*' ../src/libudev/libudev.sym | sed 's/^/lib\\//' | tr '\\n' ' ') \
              \$(grep -o 'lib[a-z_]*\\.so[.0-9]*' ../src/libsystemd/libsystemd.sym | sed 's/^/lib\\//' | tr '\\n' ' ') \
              modules.d rules.d 2>/dev/null || ninja && \
        install -vm755 udevadm /usr/bin/ 2>/dev/null || true && \
        install -vm755 systemd-hwdb /usr/bin/udev-hwdb 2>/dev/null || true && \
        cd /sources && rm -rf systemd-*/
    "
}

build_man_db() {
    _chroot_build "Man-DB" "
        cd /sources && tar xf man-db-*.tar.xz && cd man-db-*/ && \
        ./configure --prefix=/usr \
                    --docdir=/usr/share/doc/man-db \
                    --sysconfdir=/etc \
                    --disable-setuid \
                    --enable-cache-owner=bin \
                    --with-browser=/usr/bin/lynx \
                    --with-vgrind=/usr/bin/vgrind \
                    --with-grap=/usr/bin/grap \
                    --with-systemdtmpfilesdir= \
                    --with-systemdsystemunitdir= && \
        make && make install && \
        cd /sources && rm -rf man-db-*/
    "
}

build_procps_ng() {
    _chroot_build "Procps-ng" "
        cd /sources && tar xf procps-ng-*.tar.xz && cd procps-ng-*/ && \
        ./configure --prefix=/usr \
                    --docdir=/usr/share/doc/procps-ng \
                    --disable-static \
                    --disable-kill && \
        make && make install && \
        cd /sources && rm -rf procps-ng-*/
    "
}

build_util_linux_final() {
    _chroot_build "Util-linux" "
        cd /sources && tar xf util-linux-*.tar.xz && cd util-linux-*/ && \
        sed -i '/test_mkfds/s/^/#/' tests/helpers/Makemodule.am 2>/dev/null || true && \
        ./configure --bindir=/usr/bin \
                    --libdir=/usr/lib \
                    --runstatedir=/run \
                    --sbindir=/usr/sbin \
                    --disable-chfn-chsh \
                    --disable-login \
                    --disable-nologin \
                    --disable-su \
                    --disable-setpriv \
                    --disable-runuser \
                    --disable-pylibmount \
                    --disable-liblastlog2 \
                    --disable-static \
                    --without-python \
                    --without-systemd \
                    --without-systemdsystemunitdir \
                    ADJTIME_PATH=/var/lib/hwclock/adjtime \
                    --docdir=/usr/share/doc/util-linux && \
        make && make install && \
        cd /sources && rm -rf util-linux-*/
    "
}

build_e2fsprogs() {
    _chroot_build "E2fsprogs" "
        cd /sources && tar xf e2fsprogs-*.tar.gz && cd e2fsprogs-*/ && \
        mkdir -pv build && cd build && \
        ../configure --prefix=/usr \
                     --sysconfdir=/etc \
                     --enable-elf-shlibs \
                     --disable-libblkid \
                     --disable-libuuid \
                     --disable-uuidd \
                     --disable-fsck && \
        make && make install && \
        rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a && \
        gunzip -v /usr/share/info/libext2fs.info.gz && \
        makeinfo -o doc/com_err.info ../lib/et/com_err.texinfo 2>/dev/null || true && \
        cd /sources && rm -rf e2fsprogs-*/
    "
}

build_sysklogd() {
    _chroot_build "Sysklogd" "
        cd /sources && tar xf sysklogd-*.tar.gz && cd sysklogd-*/ && \
        ./configure --prefix=/usr \
                    --sysconfdir=/etc \
                    --runstatedir=/run \
                    --without-logger && \
        make && make install && \
        cat > /etc/syslog.conf << 'SYSLOGEOF'
auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *
SYSLOGEOF
        cd /sources && rm -rf sysklogd-*/
    "
}

build_sysvinit() {
    _chroot_build "Sysvinit" "
        cd /sources && tar xf sysvinit-*.tar.xz && cd sysvinit-*/ && \
        patch -Np1 -i ../sysvinit-*-consolidated-1.patch 2>/dev/null || true && \
        make && make install && \
        cd /sources && rm -rf sysvinit-*/
    "
}

# ========== Master function ==========

build_final_system() {
    einfo "========================================="
    einfo "Building LFS final system (Chapter 8)"
    einfo "This will take several hours..."
    einfo "========================================="

    build_man_pages
    build_iana_etc
    build_glibc_final
    build_zlib
    build_bzip2
    build_xz_final
    build_lz4
    build_zstd
    build_file_final
    build_readline
    build_m4_final
    build_bc
    build_flex
    build_tcl
    build_expect
    build_dejagnu
    build_pkgconf
    build_binutils_final
    build_gmp
    build_mpfr
    build_mpc
    build_attr
    build_acl
    build_libcap
    build_libxcrypt
    build_shadow
    build_gcc_final
    build_ncurses_final
    build_sed_final
    build_psmisc
    build_gettext_final
    build_bison_final
    build_grep_final
    build_bash_final
    build_libtool
    build_gdbm
    build_gperf
    build_expat
    build_inetutils
    build_less
    build_perl_final
    build_xml_parser
    build_intltool
    build_autoconf
    build_automake
    build_openssl
    build_kmod
    build_elfutils
    build_libffi
    build_python_final
    build_flit_core
    build_wheel
    build_setuptools
    build_ninja
    build_meson
    build_coreutils_final
    build_check
    build_diffutils_final
    build_gawk_final
    build_findutils_final
    build_groff
    build_grub
    build_gzip_final
    build_iproute2
    build_kbd
    build_libpipeline
    build_make_final
    build_patch_final
    build_tar_final
    build_texinfo_final
    build_vim
    build_markupsafe
    build_jinja2
    build_udev
    build_man_db
    build_procps_ng
    build_util_linux_final
    build_e2fsprogs
    build_sysklogd
    build_sysvinit

    einfo "========================================="
    einfo "Final system build complete!"
    einfo "========================================="
}
