#!/bin/bash

set -e -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"
LLD="${BUILD_DIR}/bin/ld.lld"
CLANG="${BUILD_DIR}/bin/clang"
AS="${AS:-riscv64-linux-gnu-as}"

RUNTIME_SRC_DIR="${REPO_ROOT}/llvm-custom-target-test/runtime"
RUNTIME_OBJ_DIR="${BUILD_DIR}/runtime"
COMPILER_RT_BUILTINS_DIR="${REPO_ROOT}/llvm-project/compiler-rt/lib/builtins"

ABI="lp64"
ARGS=()
for arg in "$@"; do
    case "${arg}" in
        --abi=*) ABI="${arg#--abi=}" ;;
        *) ARGS+=("${arg}") ;;
    esac
done

if [ ! -x "${LLD}" ]; then
    echo "error: ${LLD} not found (run build.sh first)" 1>&2
    exit 1
fi

# Existence-only check: objects built under one ABI are reused as-is for a later --abi, not rebuilt.
if [ ! -f "${RUNTIME_OBJ_DIR}/crt0.o" ] || [ ! -f "${RUNTIME_OBJ_DIR}/syscall.o" ] || [ ! -f "${RUNTIME_OBJ_DIR}/runtime.o" ] \
    || [ ! -f "${RUNTIME_OBJ_DIR}/comparesf2.o" ] || [ ! -f "${RUNTIME_OBJ_DIR}/comparedf2.o" ] \
    || [ ! -f "${RUNTIME_OBJ_DIR}/floatsisf.o" ]; then
    if [ ! -x "${CLANG}" ]; then
        echo "error: ${CLANG} not found (run build.sh first)" 1>&2
        exit 1
    fi
    if ! command -v "${AS}" >/dev/null 2>&1; then
        echo "error: ${AS} not found (install binutils-riscv64-linux-gnu, or set AS)" 1>&2
        exit 1
    fi

    RESOURCE_DIR="$("${CLANG}" -print-resource-dir)"

    mkdir -p "${RUNTIME_OBJ_DIR}"
    "${AS}" -mabi="${ABI}" "${RUNTIME_SRC_DIR}/crt0.s" -o "${RUNTIME_OBJ_DIR}/crt0.o"
    "${AS}" -mabi="${ABI}" "${RUNTIME_SRC_DIR}/syscall.s" -o "${RUNTIME_OBJ_DIR}/syscall.o"
    "${CLANG}" -cc1 -triple riscv64-unknown-linux-gnu -target-abi "${ABI}" -target-feature +m \
        -internal-isystem "${RESOURCE_DIR}/include" \
        -S "${RUNTIME_SRC_DIR}/runtime.c" -o "${RUNTIME_OBJ_DIR}/runtime.s"
    "${AS}" -mabi="${ABI}" "${RUNTIME_OBJ_DIR}/runtime.s" -o "${RUNTIME_OBJ_DIR}/runtime.o"

    for name in comparesf2 comparedf2 floatsisf; do
        "${CLANG}" -cc1 -triple riscv64-unknown-linux-gnu -target-abi "${ABI}" -target-feature +m \
            -internal-isystem "${RESOURCE_DIR}/include" \
            -I "${COMPILER_RT_BUILTINS_DIR}" \
            -S "${COMPILER_RT_BUILTINS_DIR}/${name}.c" -o "${RUNTIME_OBJ_DIR}/${name}.s"
        "${AS}" -mabi="${ABI}" "${RUNTIME_OBJ_DIR}/${name}.s" -o "${RUNTIME_OBJ_DIR}/${name}.o"
    done
fi

"${LLD}" -e _start \
    "${RUNTIME_OBJ_DIR}/crt0.o" \
    "${RUNTIME_OBJ_DIR}/syscall.o" \
    "${RUNTIME_OBJ_DIR}/runtime.o" \
    "${RUNTIME_OBJ_DIR}/comparesf2.o" \
    "${RUNTIME_OBJ_DIR}/comparedf2.o" \
    "${RUNTIME_OBJ_DIR}/floatsisf.o" \
    "${ARGS[@]}"
