#!/bin/bash

set -e -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"
CLANG="${BUILD_DIR}/bin/clang"
AS="${AS:-riscv64-linux-gnu-as}"
ABI="lp64"

if [ ! -x "${CLANG}" ]; then
    echo "error: ${CLANG} not found (run build.sh first)" 1>&2
    exit 1
fi

OUT=""
PREV=""
for arg in "$@"; do
    if [ "${PREV}" = "-o" ]; then
        OUT="${arg}"
    fi
    PREV="${arg}"
done

CLANG_ARGS=("$@")
OBJ_OUT=""
ASM_OUT=""
EXE_OUT=""

if [[ "${OUT}" == *.o ]]; then
    OBJ_OUT="${OUT}"
    ASM_OUT="${OUT%.o}.s"
elif [[ "${OUT}" == *.s ]]; then
    OBJ_OUT="${OUT%.s}.o"
    ASM_OUT="${OUT}"
elif [ -n "${OUT}" ]; then
    EXE_OUT="${OUT}"
    OBJ_OUT="${OUT}.o"
    ASM_OUT="${OUT}.s"
fi

if [ -n "${ASM_OUT}" ]; then
    if [ "${OUT}" != "${ASM_OUT}" ]; then
        REWRITTEN=()
        PREV=""
        for arg in "${CLANG_ARGS[@]}"; do
            if [ "${PREV}" = "-o" ]; then
                REWRITTEN+=("${ASM_OUT}")
            else
                REWRITTEN+=("${arg}")
            fi
            PREV="${arg}"
        done
        CLANG_ARGS=("${REWRITTEN[@]}")
    fi
    CLANG_ARGS=(-S "${CLANG_ARGS[@]}")
fi

RESOURCE_DIR="$("${CLANG}" -print-resource-dir)"

"${CLANG}" -cc1 -triple riscv64-unknown-linux-gnu -target-abi "${ABI}" -target-feature +m \
    -internal-isystem "${RESOURCE_DIR}/include" "${CLANG_ARGS[@]}"

if [ -n "${OBJ_OUT}" ]; then
    if ! command -v "${AS}" >/dev/null 2>&1; then
        echo "error: ${AS} not found (install binutils-riscv64-linux-gnu, or set AS)" 1>&2
        exit 1
    fi
    "${AS}" -mabi="${ABI}" "${ASM_OUT}" -o "${OBJ_OUT}"
fi

if [ -n "${EXE_OUT}" ]; then
    "${REPO_ROOT}/invoke-lld.sh" --abi="${ABI}" "${OBJ_OUT}" -o "${EXE_OUT}"
fi
