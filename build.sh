#!/bin/bash

set -e -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLVM_PROJECT_DIR="${LLVM_PROJECT_DIR:-${REPO_ROOT}/llvm-project}"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"
BUILD_CLANG="${BUILD_CLANG:-1}"
BUILD_LLD="${BUILD_LLD:-1}"

SYMLINK_SOURCE_DIR="${REPO_ROOT}/llvm-custom-target/simple-rv64"
SYMLINK_TARGET_LINK="${LLVM_PROJECT_DIR}/llvm/lib/Target/RV64"

SYMLINK_TEST_SOURCE_DIR="${REPO_ROOT}/llvm-custom-target-test/CodeGen/RV64"
SYMLINK_TEST_TARGET_LINK="${LLVM_PROJECT_DIR}/llvm/test/CodeGen/RV64"

if [ ! -d "${SYMLINK_SOURCE_DIR}" ]; then
    echo "error: ${SYMLINK_SOURCE_DIR} not found" 1>&2
    exit 1
fi

if [ ! -d "${SYMLINK_TEST_SOURCE_DIR}" ]; then
    echo "error: ${SYMLINK_TEST_SOURCE_DIR} not found" 1>&2
    exit 1
fi

if [ ! -d "${LLVM_PROJECT_DIR}/llvm" ]; then
    if [ -d "${REPO_ROOT}/.git" ]; then
        echo "llvm-project submodule not found; fetching it now (this clones upstream LLVM, may take a while)..." 1>&2
        git -C "${REPO_ROOT}" submodule update --init -- llvm-project
    fi
fi

if [ ! -d "${LLVM_PROJECT_DIR}/llvm" ]; then
    echo "error: ${LLVM_PROJECT_DIR}/llvm not found (set LLVM_PROJECT_DIR)" 1>&2
    exit 1
fi

GENERATOR_ARGS=()
if command -v ninja >/dev/null 2>&1; then
    GENERATOR_ARGS=(-G Ninja)
fi

BUILD_TARGETS=(llc)
ENABLED_PROJECTS=()
if [ "${BUILD_CLANG}" = "1" ]; then
    ENABLED_PROJECTS+=(clang)
    BUILD_TARGETS+=(clang)
fi
if [ "${BUILD_LLD}" = "1" ]; then
    ENABLED_PROJECTS+=(lld)
    BUILD_TARGETS+=(lld)
fi
LLVM_ENABLE_PROJECTS_VALUE="$(IFS=';'; echo "${ENABLED_PROJECTS[*]}")"

set -x

ln -sfn "${SYMLINK_SOURCE_DIR}" "${SYMLINK_TARGET_LINK}"
ln -sfn "${SYMLINK_TEST_SOURCE_DIR}" "${SYMLINK_TEST_TARGET_LINK}"

cmake "${GENERATOR_ARGS[@]}" -S "${LLVM_PROJECT_DIR}/llvm" -B "${BUILD_DIR}" \
    -DLLVM_TARGETS_TO_BUILD="" \
    -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=RV64 \
    -DLLVM_ENABLE_PROJECTS="${LLVM_ENABLE_PROJECTS_VALUE}"

cmake --build "${BUILD_DIR}" --target "${BUILD_TARGETS[@]}" "$@"
