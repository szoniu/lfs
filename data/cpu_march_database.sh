#!/usr/bin/env bash
# cpu_march_database.sh — Map CPU vendor:family:model to -march= flags
source "${LIB_DIR}/protection.sh"

declare -A CPU_MARCH_MAP

# AMD Zen family (family 23 = 0x17)
CPU_MARCH_MAP["AuthenticAMD:23:1:1"]="znver1"
CPU_MARCH_MAP["AuthenticAMD:23:8:8"]="znver1"
CPU_MARCH_MAP["AuthenticAMD:23:17:17"]="znver1"
CPU_MARCH_MAP["AuthenticAMD:23:24:24"]="znver1"
CPU_MARCH_MAP["AuthenticAMD:23:49:49"]="znver2"
CPU_MARCH_MAP["AuthenticAMD:23:71:71"]="znver2"
CPU_MARCH_MAP["AuthenticAMD:23:96:96"]="znver2"
CPU_MARCH_MAP["AuthenticAMD:23:104:104"]="znver2"
CPU_MARCH_MAP["AuthenticAMD:23:113:113"]="znver2"
CPU_MARCH_MAP["AuthenticAMD:23:144:144"]="znver2"

# AMD Zen 3/4/5 (family 25 = 0x19)
CPU_MARCH_MAP["AuthenticAMD:25:1:1"]="znver3"
CPU_MARCH_MAP["AuthenticAMD:25:8:8"]="znver3"
CPU_MARCH_MAP["AuthenticAMD:25:33:33"]="znver3"
CPU_MARCH_MAP["AuthenticAMD:25:44:44"]="znver3"
CPU_MARCH_MAP["AuthenticAMD:25:48:48"]="znver3"
CPU_MARCH_MAP["AuthenticAMD:25:50:50"]="znver3"
CPU_MARCH_MAP["AuthenticAMD:25:80:80"]="znver3"
CPU_MARCH_MAP["AuthenticAMD:25:97:97"]="znver4"
CPU_MARCH_MAP["AuthenticAMD:25:116:116"]="znver4"
CPU_MARCH_MAP["AuthenticAMD:25:117:117"]="znver4"

# AMD Zen 5 (family 26 = 0x1A)
CPU_MARCH_MAP["AuthenticAMD:26:32:32"]="znver5"
CPU_MARCH_MAP["AuthenticAMD:26:36:36"]="znver5"

# Intel Core (family 6)
CPU_MARCH_MAP["GenuineIntel:6:42:42"]="sandybridge"
CPU_MARCH_MAP["GenuineIntel:6:45:45"]="sandybridge"
CPU_MARCH_MAP["GenuineIntel:6:58:58"]="ivybridge"
CPU_MARCH_MAP["GenuineIntel:6:62:62"]="ivybridge"
CPU_MARCH_MAP["GenuineIntel:6:60:60"]="haswell"
CPU_MARCH_MAP["GenuineIntel:6:63:63"]="haswell"
CPU_MARCH_MAP["GenuineIntel:6:69:69"]="haswell"
CPU_MARCH_MAP["GenuineIntel:6:70:70"]="haswell"
CPU_MARCH_MAP["GenuineIntel:6:61:61"]="broadwell"
CPU_MARCH_MAP["GenuineIntel:6:71:71"]="broadwell"
CPU_MARCH_MAP["GenuineIntel:6:79:79"]="broadwell"
CPU_MARCH_MAP["GenuineIntel:6:86:86"]="broadwell"
CPU_MARCH_MAP["GenuineIntel:6:78:78"]="skylake"
CPU_MARCH_MAP["GenuineIntel:6:94:94"]="skylake"
CPU_MARCH_MAP["GenuineIntel:6:85:85"]="skylake-avx512"
CPU_MARCH_MAP["GenuineIntel:6:142:142"]="skylake"
CPU_MARCH_MAP["GenuineIntel:6:158:158"]="skylake"
CPU_MARCH_MAP["GenuineIntel:6:165:165"]="skylake"
CPU_MARCH_MAP["GenuineIntel:6:166:166"]="skylake"
CPU_MARCH_MAP["GenuineIntel:6:106:106"]="icelake-server"
CPU_MARCH_MAP["GenuineIntel:6:108:108"]="icelake-server"
CPU_MARCH_MAP["GenuineIntel:6:125:125"]="icelake-client"
CPU_MARCH_MAP["GenuineIntel:6:126:126"]="icelake-client"
CPU_MARCH_MAP["GenuineIntel:6:140:140"]="tigerlake"
CPU_MARCH_MAP["GenuineIntel:6:141:141"]="tigerlake"
CPU_MARCH_MAP["GenuineIntel:6:143:143"]="sapphirerapids"
CPU_MARCH_MAP["GenuineIntel:6:151:151"]="alderlake"
CPU_MARCH_MAP["GenuineIntel:6:154:154"]="alderlake"
CPU_MARCH_MAP["GenuineIntel:6:183:183"]="raptorlake"
CPU_MARCH_MAP["GenuineIntel:6:186:186"]="raptorlake"
CPU_MARCH_MAP["GenuineIntel:6:191:191"]="raptorlake"

lookup_cpu_march() {
    local vendor family model
    vendor=$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $NF}') || vendor="unknown"
    family=$(grep -m1 'cpu family' /proc/cpuinfo 2>/dev/null | awk '{print $NF}') || family="0"
    model=$(grep -m1 '^model[[:space:]]' /proc/cpuinfo 2>/dev/null | awk '{print $NF}') || model="0"

    local key="${vendor}:${family}:${model}:${model}"

    if [[ -n "${CPU_MARCH_MAP[${key}]+x}" ]]; then
        echo "${CPU_MARCH_MAP[${key}]}"
        return 0
    fi

    if [[ "${vendor}" == "AuthenticAMD" ]]; then
        case "${family}" in
            23) echo "znver1" ;;
            25) echo "znver3" ;;
            26) echo "znver5" ;;
            *)  echo "x86-64" ;;
        esac
    elif [[ "${vendor}" == "GenuineIntel" ]]; then
        if (( model >= 183 )); then
            echo "raptorlake"
        elif (( model >= 151 )); then
            echo "alderlake"
        elif (( model >= 140 )); then
            echo "tigerlake"
        elif (( model >= 125 )); then
            echo "icelake-client"
        elif (( model >= 78 )); then
            echo "skylake"
        elif (( model >= 61 )); then
            echo "broadwell"
        elif (( model >= 60 )); then
            echo "haswell"
        else
            echo "x86-64"
        fi
    else
        echo "x86-64"
    fi
}
