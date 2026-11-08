# Introduction

A simple RISC-V (RV64I, 64-bit) backend for LLVM, implemented via the GlobalISel
framework (no fallback to SelectionDAG). It's built as a personal learning project, rather than aiming to be a production-ready RISC-V backend.
However, the backend's minimalistic set of features have extensive codegen and execution test coverage, including execution tests derived from [c-testsuite](https://github.com/c-testsuite/c-testsuite).

With regards to codegen, the backend implements only the AsmPrinter interface (no MCCodeEmitter currently), so building a final executable requires using external RISC-V assembler, such as
`gas` (GNU assembler) or `llvm-mc` (LLVM's assembler based on the upstream RISC-V backend). The `invoke-clang.sh` script orchestrates the entire compilation process transparently (examples below).

## Status

The backend currently supports:

- Base integer ISA (`I`), as well as `M` (multiply/divide)
- Floating point operations are currently emulated in software (via LLVM's compiler-rt)
- Function calls following the RISC-V psABI's LP64 calling convention
- Loops, structs, jump tables
- Variable argument count for functions (varargs)
- Basic CFI directives required for stack unwinding
- Generally anything (or to large extent) required to compile ANSI C source code
- A minimalistic runtime library (i.e. newlib is not ported as of yet) linked to final executables

### What is not supported at this point

- The `C` (compressed), `F`/`D` (hardware floating point), and `V` (vector) ISA extensions (generally anything except I/M)
- Direct object emission (`-filetype=obj`)
- Inline assembly
- Thread-local storage (TLS)
- Exception handling
- Dynamic linking
- Disassembling

## Repository layout

| Path | Description |
|---|---|
| `llvm-custom-target/simple-rv64/` | The backend itself (`lib/Target/RV64` equivalent) |
| `llvm-custom-target-test/CodeGen/RV64/` | lit tests (`.ll` passed through FileCheck), symlinked into `llvm-project/llvm/test/CodeGen/RV64` |
| `llvm-custom-target-test/Execution/RV64/` | Small hand-written C programs, compiled through the real Clang frontend and executed under QEMU |
| `llvm-custom-target-test/Execution-Ext/c-testsuite/` | The `c-testsuite` project as a git submodule, used as a broader (non-blocking) execution test |
| `llvm-custom-target-test/runtime/` | `crt0`, syscall stubs, and a tiny hand-written libc subset |
| `llvm-project/` | Upstream LLVM, as a git submodule (build tree + reference) |
| `build.sh` | Configures and builds `llc`, `clang`, and `lld` against `llvm-project` |
| `test.sh` | Runs the lit test suite, execution tests, and the `c-testsuite` tests |
| `invoke-clang.sh` / `invoke-lld.sh` | Thin wrappers driving `clang -cc1` and `ld.lld` directly |

## Building

To build the backend simply run:

```sh
./build.sh
```

The `llvm-project` submodule is fetched automatically on first run if not
already checked out - it clones upstream LLVM, so it can take a while.

The build script symlinks `llvm-custom-target/simple-rv64` into
`llvm-project/llvm/lib/Target/RV64`, configures a build where only the `RV64`
experimental target is enabled, then builds `llc`, `clang` and `lld`. Any extra
arguments are forwarded to the underlying `cmake --build` call, e.g.:

```sh
./build.sh -j8
```

The target is registered under the triple `riscv64` with architecture string
`simple-rv64`, e.g.:

```sh
llc -mtriple=riscv64 -march=simple-rv64 -filetype=asm input.ll
```

## Compiling C programs

**`invoke-clang.sh`** behaves like a drop-in `clang` for this target - it accepts the same CLI arguments as clang.

Under the hood it calls `clang -cc1` directly (bypassing the
Driver) with `-triple riscv64-unknown-linux-gnu -target-abi lp64
-target-feature +m` hardcoded, always asking `cc1` for assembly output and
then:
- assembling to `.o` via `riscv64-linux-gnu-as` if the requested output is an
  object file or an executable;
- linking via `invoke-lld.sh` if the requested output has no `.o`/`.s`
  extension (treated as a final executable).

**`invoke-lld.sh`** is a thin `ld.lld -e _start` wrapper that always links in
the backend's minimalistic runtime (`llvm-custom-target-test/runtime/`: `crt0.o`,
`syscall.o`, `runtime.o`) plus the compiler-rt soft-float builtins (`comparesf2`, `comparedf2`, `floatsisf`). The script builds and
caches all of them under `build/runtime/` the first time it's invoked.

Examples:

```sh
./invoke-clang.sh hello.c -o hello          # emit + assemble + link an executable
./invoke-clang.sh -c hello.c -o hello.o     # emit + assemble to an object file
./invoke-clang.sh -S hello.c -o hello.s     # emit assembly only
```

## Testing

The tests can be run with:

```sh
./test.sh
```

This runs three test suites, in order:

- **`CodeGen/RV64`** lit suite - hand-written `.ll` tests validated with `FileCheck`
- **`Execution/RV64`** - hand-written C programs, compiled with `invoke-clang.sh` and run under `qemu-riscv64`
- **`Execution-Ext`** - the same execution testing approach, but with a broader subset of the `c-testsuite` project

`qemu-user` (`qemu-riscv64`) is required for the two execution-based suites. Flags `--skip-lit`, `--skip-execution`, `--skip-execution-ext` allow skipping any of the above suites.