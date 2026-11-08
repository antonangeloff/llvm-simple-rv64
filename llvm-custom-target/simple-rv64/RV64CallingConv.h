//===-- RV64CallingConv.h - RV64 Custom CC Routines -----------*- C++ -*-===//

#ifndef LLVM_LIB_TARGET_RV64_RV64CALLINGCONV_H
#define LLVM_LIB_TARGET_RV64_RV64CALLINGCONV_H

#include "llvm/MC/MCRegister.h"

extern const llvm::MCRegister CC_RV64_LP64_ArgRegs[8];
extern const llvm::MCRegister RetCC_RV64_LP64_ArgRegs[2];

#endif
