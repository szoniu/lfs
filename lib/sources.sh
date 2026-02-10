#!/usr/bin/env bash
# sources.sh — Download, verify, and extract LFS source tarballs
source "${LIB_DIR}/protection.sh"

# sources_prepare — Create $LFS/sources directory with sticky bit
sources_prepare() {
    einfo "Preparing sources directory..."
    mkdir -pv "${LFS}/sources"
    chmod -v a+wt "${LFS}/sources"
}

# sources_download_list — Download wget-list and md5sums from LFS site
sources_download_list() {
    einfo "Downloading package lists..."

    try "Downloading wget-list" \
        wget --no-check-certificate -O "${LFS}/sources/wget-list" "${LFS_WGET_LIST}"
    try "Downloading md5sums" \
        wget --no-check-certificate -O "${LFS}/sources/md5sums" "${LFS_MD5SUMS}"
}

# sources_download_all — Download all source tarballs
sources_download_all() {
    einfo "Downloading all source tarballs..."

    local total
    total=$(wc -l < "${LFS}/sources/wget-list")
    local count=0
    local failed=0

    while IFS= read -r url; do
        [[ -z "${url}" ]] && continue
        [[ "${url}" =~ ^# ]] && continue
        (( count++ )) || true

        local filename
        filename=$(basename "${url}")

        if [[ -f "${LFS}/sources/${filename}" ]]; then
            einfo "[${count}/${total}] Already have: ${filename}"
            continue
        fi

        einfo "[${count}/${total}] Downloading: ${filename}"
        if ! wget --no-check-certificate -P "${LFS}/sources" "${url}" >> "${LOG_FILE}" 2>&1; then
            ewarn "Failed to download: ${filename}"
            (( failed++ )) || true
        fi
    done < "${LFS}/sources/wget-list"

    if [[ ${failed} -gt 0 ]]; then
        ewarn "${failed} downloads failed out of ${total}"
    fi
    einfo "Source download complete: ${count} packages"
}

# sources_verify — Verify MD5 checksums of all downloaded sources
sources_verify() {
    einfo "Verifying source checksums..."

    local prev_dir
    prev_dir=$(pwd)
    cd "${LFS}/sources" || die "Cannot cd to ${LFS}/sources"

    local ok=0
    local bad=0
    local missing=0

    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        local md5 filename
        read -r md5 filename <<< "${line}"
        filename="${filename#\*}"  # Remove leading * if present

        if [[ ! -f "${filename}" ]]; then
            ewarn "Missing: ${filename}"
            (( missing++ )) || true
            continue
        fi

        local actual_md5
        actual_md5=$(md5sum "${filename}" | awk '{print $1}')
        if [[ "${actual_md5}" == "${md5}" ]]; then
            (( ok++ )) || true
        else
            eerror "CHECKSUM MISMATCH: ${filename}"
            eerror "  Expected: ${md5}"
            eerror "  Got:      ${actual_md5}"
            (( bad++ )) || true
        fi
    done < "${LFS}/sources/md5sums"

    cd "${prev_dir}" || true

    einfo "Verification: ${ok} OK, ${bad} FAILED, ${missing} missing"

    if [[ ${bad} -gt 0 ]]; then
        eerror "Some checksums failed! Re-download affected files."
        return 1
    fi

    if [[ ${missing} -gt 0 ]]; then
        ewarn "Some files are missing. Re-run download."
        return 1
    fi

    einfo "All checksums verified successfully"
    return 0
}

# sources_full_download — Complete download + verify pipeline
sources_full_download() {
    sources_prepare
    sources_download_list
    sources_download_all
    sources_verify
}

# extract_source — Extract a source tarball and cd to it
# Usage: extract_source <package_name>
# Expects tarball in $LFS/sources
extract_source() {
    local pkg="$1"
    local tarball

    # Find the matching tarball
    tarball=$(find "${LFS}/sources" -maxdepth 1 -name "${pkg}-*.tar.*" -o -name "${pkg}-*.tgz" | head -1)

    if [[ -z "${tarball}" ]]; then
        die "Source tarball not found for: ${pkg}"
    fi

    local build_dir="${BUILD_AREA:-${LFS}/sources}"

    # Remove old build directory if it exists
    local dirname
    dirname=$(tar tf "${tarball}" 2>/dev/null | head -1 | cut -d/ -f1)
    if [[ -n "${dirname}" && -d "${build_dir}/${dirname}" ]]; then
        rm -rf "${build_dir:?}/${dirname:?}"
    fi

    tar -xf "${tarball}" -C "${build_dir}"

    echo "${build_dir}/${dirname}"
}
