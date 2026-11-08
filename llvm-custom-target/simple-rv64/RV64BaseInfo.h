//===-- RV64BaseInfo.h - Top-level definitions for RV64 ------------*- C++ -*-===//
//
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RV64_RV64BASEINFO_H
#define LLVM_LIB_TARGET_RV64_RV64BASEINFO_H

namespace llvm {

namespace RVII {

enum TargetOperandFlag {
  TOF_None = 0,

  // Absolute addressing: hi20/lo12 of the symbol's own address.
  TOF_HI,
  TOF_LO,

  // PC-relative addressing
  TOF_PCREL_HI,
  TOF_PCREL_LO,
};

} // namespace RVII

} // namespace llvm

#endif
