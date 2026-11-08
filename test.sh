#!/bin/bash

set -e -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLVM_PROJECT_DIR="${LLVM_PROJECT_DIR:-${REPO_ROOT}/llvm-project}"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"

SYMLINK_TEST_TARGET_LINK="${LLVM_PROJECT_DIR}/llvm/test/CodeGen/RV64"
EXECUTION_TEST_DIR="${REPO_ROOT}/llvm-custom-target-test/Execution/RV64"
EXECUTION_EXT_SUBMODULE="llvm-custom-target-test/Execution-Ext/c-testsuite"
EXECUTION_EXT_TEST_DIR="${REPO_ROOT}/${EXECUTION_EXT_SUBMODULE}/tests/single-exec"
INVOKE_CLANG="${REPO_ROOT}/invoke-clang.sh"
QEMU="${QEMU:-qemu-riscv64}"

BUILD=1
RUN_LIT=1
RUN_EXECUTION_TESTS=1
RUN_EXECUTION_EXT_TESTS=1
ARGS=()
for arg in "$@"; do
    case "${arg}" in
        --skip-build) BUILD=0 ;;
        --skip-lit) RUN_LIT=0 ;;
        --skip-execution) RUN_EXECUTION_TESTS=0 ;;
        --skip-execution-ext) RUN_EXECUTION_EXT_TESTS=0 ;;
        *) ARGS+=("${arg}") ;;
    esac
done

if [ ! -L "${SYMLINK_TEST_TARGET_LINK}" ]; then
    echo "error: ${SYMLINK_TEST_TARGET_LINK} not found (run build.sh first)" 1>&2
    exit 1
fi

if [ ! -d "${BUILD_DIR}" ]; then
    echo "error: ${BUILD_DIR} not found (run build.sh first)" 1>&2
    exit 1
fi

if [ "${BUILD}" -eq 1 ]; then
    cmake --build "${BUILD_DIR}" --target FileCheck count not split-file llvm-config llvm-readobj
fi

if [ "${RUN_LIT}" -eq 1 ]; then
    "${BUILD_DIR}/bin/llvm-lit" --diagnostic-level=error "${SYMLINK_TEST_TARGET_LINK}" "${ARGS[@]}"
fi

if [ "${RUN_EXECUTION_TESTS}" -eq 1 ]; then
    if ! command -v "${QEMU}" >/dev/null 2>&1; then
        echo "error: ${QEMU} not found (install qemu-user, set QEMU, or pass --skip-execution)" 1>&2
        exit 1
    fi

    echo ""
    echo "=== Execution tests ==="
    TMP_DIR="$(mktemp -d)"
    PASSED=0
    FAILED=0
    SOURCES=("${EXECUTION_TEST_DIR}"/*.c)
    TOTAL="${#SOURCES[@]}"
    I=0
    START_TIME="${EPOCHREALTIME}"
    for src in "${SOURCES[@]}"; do
        I=$((I + 1))
        name="$(basename "${src}" .c)"
        exe="${TMP_DIR}/${name}"
        if "${INVOKE_CLANG}" -o "${exe}" "${src}" && "${QEMU}" "${exe}" >/dev/null 2>&1; then
            echo "PASS: Execution :: Execution/RV64/${name}.c (${I} of ${TOTAL})"
            PASSED=$((PASSED + 1))
        else
            echo "FAIL: Execution :: Execution/RV64/${name}.c (${I} of ${TOTAL})"
            FAILED=$((FAILED + 1))
        fi
    done
    END_TIME="${EPOCHREALTIME}"
    rm -rf "${TMP_DIR}"

    ELAPSED="$(awk "BEGIN {printf \"%.2f\", ${END_TIME} - ${START_TIME}}")"
    PASS_PCT="$(awk "BEGIN {printf \"%.2f\", (${PASSED} / ${TOTAL}) * 100}")"

    echo ""
    echo "Testing Time: ${ELAPSED}s"
    echo ""
    echo "Total Discovered Tests: ${TOTAL}"
    echo "  Passed: ${PASSED} (${PASS_PCT}%)"
    if [ "${FAILED}" -gt 0 ]; then
        FAIL_PCT="$(awk "BEGIN {printf \"%.2f\", (${FAILED} / ${TOTAL}) * 100}")"
        echo "  Failed: ${FAILED} (${FAIL_PCT}%)"
        exit 1
    fi
fi

if [ "${RUN_EXECUTION_EXT_TESTS}" -eq 1 ]; then
    if ! command -v "${QEMU}" >/dev/null 2>&1; then
        echo "error: ${QEMU} not found (install qemu-user, set QEMU, or pass --skip-execution-ext)" 1>&2
        exit 1
    fi

    if [ ! -d "${EXECUTION_EXT_TEST_DIR}" ]; then
        git -C "${REPO_ROOT}" submodule update --init -- "${EXECUTION_EXT_SUBMODULE}"
    fi

    echo ""
    echo "=== Execution-Ext tests (c-testsuite, filtered: portable, no needs-libc/needs-cpp/arch-specific) ==="
    TMP_DIR="$(mktemp -d)"
    PASSED=0
    FAILED=0
    SOURCES=()
    for tags in "${EXECUTION_EXT_TEST_DIR}"/*.c.tags; do
        src="${tags%.tags}"
        if grep -qx "portable" "${tags}" \
            && ! grep -qx "needs-libc" "${tags}" \
            && ! grep -qx "needs-cpp" "${tags}" \
            && ! grep -q "^arch-" "${tags}"; then
            SOURCES+=("${src}")
        fi
    done
    UPSTREAM_TOTAL=$(ls "${EXECUTION_EXT_TEST_DIR}"/*.c.tags | wc -l)
    TOTAL="${#SOURCES[@]}"
    SKIPPED=$((UPSTREAM_TOTAL - TOTAL))
    I=0
    START_TIME="${EPOCHREALTIME}"
    for src in "${SOURCES[@]}"; do
        I=$((I + 1))
        name="$(basename "${src}" .c)"
        exe="${TMP_DIR}/${name}"
        if "${INVOKE_CLANG}" -o "${exe}" "${src}" && "${QEMU}" "${exe}" >/dev/null 2>&1; then
            echo "PASS: Execution-Ext :: Execution-Ext/c-testsuite/${name}.c (${I} of ${TOTAL})"
            PASSED=$((PASSED + 1))
        else
            echo "FAIL: Execution-Ext :: Execution-Ext/c-testsuite/${name}.c (${I} of ${TOTAL})"
            FAILED=$((FAILED + 1))
        fi
    done
    END_TIME="${EPOCHREALTIME}"
    rm -rf "${TMP_DIR}"

    ELAPSED="$(awk "BEGIN {printf \"%.2f\", ${END_TIME} - ${START_TIME}}")"

    echo ""
    echo "Testing Time: ${ELAPSED}s"
    echo ""
    echo "Filtered out (tags): ${SKIPPED} of ${UPSTREAM_TOTAL} upstream tests"
    echo "Total Discovered Tests: ${TOTAL}"
    if [ "${TOTAL}" -gt 0 ]; then
        PASS_PCT="$(awk "BEGIN {printf \"%.2f\", (${PASSED} / ${TOTAL}) * 100}")"
        echo "  Passed: ${PASSED} (${PASS_PCT}%)"
        if [ "${FAILED}" -gt 0 ]; then
            FAIL_PCT="$(awk "BEGIN {printf \"%.2f\", (${FAILED} / ${TOTAL}) * 100}")"
            echo "  Failed: ${FAILED} (${FAIL_PCT}%)"
        fi
    fi
fi
