//===-- RV64.h - Top-level interface for RV64 representation ------*- C++ -*-===//  //todo: adjust

#ifndef LLVM_LIB_TARGET_RV64_RV64_H
#define LLVM_LIB_TARGET_RV64_RV64_H

#include "MCTargetDesc/RV64MCTargetDesc.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionAnalysisManager.h"
#include "llvm/IR/Analysis.h"
#include "llvm/IR/Instructions.h" // todo: delete
#include "llvm/IR/PassManager.h"
#include "llvm/Pass.h"
#include "llvm/Target/TargetMachine.h"

namespace llvm {
class RV64RegisterBankInfo;
class RV64Subtarget;
class RV64TargetMachine;
class InstructionSelector;
class PassRegistry;

InstructionSelector *createRV64InstructionSelector(const RV64TargetMachine &,
                                                  const RV64Subtarget &,
                                                  const RV64RegisterBankInfo &);

void initializeRV64AsmPrinterPass(PassRegistry &);
void initializeRV64PreLegalizerCombinerLegacyPass(PassRegistry &);
FunctionPass *createRV64PreLegalizerCombiner();

} // namespace llvm

#endif
