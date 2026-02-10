#!/usr/bin/env bash
# config.sh — Save/load configuration using ${VAR@Q} quoting
source "${LIB_DIR}/protection.sh"

config_save() {
    local file="${1:-${CONFIG_FILE}}"
    local dir
    dir="$(dirname "${file}")"
    mkdir -p "${dir}"

    {
        echo "#!/usr/bin/env bash"
        echo "# LFS TUI Installer configuration"
        echo "# Generated: $(date -Iseconds)"
        echo "# Version: ${INSTALLER_VERSION}"
        echo ""

        local var
        for var in "${CONFIG_VARS[@]}"; do
            if [[ -n "${!var+x}" ]]; then
                echo "${var}=${!var@Q}"
            fi
        done
    } > "${file}"

    einfo "Configuration saved to ${file}"
}

config_load() {
    local file="${1:-${CONFIG_FILE}}"

    if [[ ! -f "${file}" ]]; then
        eerror "Configuration file not found: ${file}"
        return 1
    fi

    local line_num=0
    while IFS= read -r line; do
        (( line_num++ )) || true
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
        [[ "${line}" =~ ^#! ]] && continue

        local var_name
        var_name="${line%%=*}"
        var_name="${var_name%%[[:space:]]*}"

        local found=0
        local known_var
        for known_var in "${CONFIG_VARS[@]}"; do
            if [[ "${var_name}" == "${known_var}" ]]; then
                found=1
                break
            fi
        done

        if [[ ${found} -eq 0 ]]; then
            ewarn "Unknown variable at line ${line_num}: ${var_name} (skipping)"
            continue
        fi
    done < "${file}"

    # shellcheck disable=SC1090
    source "${file}"

    einfo "Configuration loaded from ${file}"
}

config_get() {
    local var="$1"
    echo "${!var:-}"
}

config_set() {
    local var="$1" value="$2"

    local found=0
    local known_var
    for known_var in "${CONFIG_VARS[@]}"; do
        if [[ "${var}" == "${known_var}" ]]; then
            found=1
            break
        fi
    done

    if [[ ${found} -eq 0 ]]; then
        ewarn "Setting unknown config variable: ${var}"
    fi

    printf -v "${var}" '%s' "${value}"
    export "${var}"
}

config_dump() {
    local var
    for var in "${CONFIG_VARS[@]}"; do
        if [[ -n "${!var+x}" ]]; then
            echo "${var}=${!var@Q}"
        fi
    done
}

config_diff() {
    local file1="$1" file2="$2"
    diff --unified=0 \
        <(sort "${file1}" | grep -v '^#' | grep -v '^$') \
        <(sort "${file2}" | grep -v '^#' | grep -v '^$') || true
}
