//===-- RV64TargetInfo.cpp - RV64 Target Implementation ---------------------===//

#include "TargetInfo/RV64TargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"

using namespace llvm;

Target &llvm::getTheRV64Target() {
  static Target TheRV64Target;
  return TheRV64Target;
}

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void
LLVMInitializeRV64TargetInfo() {
  RegisterTarget<Triple::riscv64, /*HasJIT=*/false> X(
      getTheRV64Target(), "simple-rv64", "RV64 (little endian)", "RV64");
}
