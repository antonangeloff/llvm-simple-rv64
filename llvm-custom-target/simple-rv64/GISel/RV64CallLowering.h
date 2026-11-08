//===-- RV64CallLowering.h - Call lowering for GlobalISel --------*- C++ -*-===//
///
/// \file
/// This file describes how to lower LLVM calls to machine code calls.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RV64_GISEL_RV64CALLLOWERING_H
#define LLVM_LIB_TARGET_RV64_GISEL_RV64CALLLOWERING_H

#include "RV64ISelLowering.h"
#include "llvm/CodeGen/GlobalISel/CallLowering.h"
#include "llvm/IR/CallingConv.h"

namespace llvm {

class RV64TargetLowering;
class CCState;

class RV64CallLowering : public CallLowering {
public:
  RV64CallLowering(const RV64TargetLowering &TLI);
  bool lowerReturn(MachineIRBuilder &MIRBuilder, const Value *Val,
                   ArrayRef<Register> VRegs, FunctionLoweringInfo &FLI,
                   Register SwiftErrorVReg) const override;
  bool lowerFormalArguments(MachineIRBuilder &MIRBuilder, const Function &F,
                            ArrayRef<ArrayRef<Register>> VRegs,
                            FunctionLoweringInfo &FLI) const override;
  bool lowerCall(MachineIRBuilder &MIRBuilder,
                 CallLoweringInfo &Info) const override;
  bool canLowerReturn(MachineFunction &MF, CallingConv::ID CallConv,
                              SmallVectorImpl<BaseArgInfo> &Outs,
                              bool IsVarArg) const override;

private:
  void saveVarArgRegisters(MachineIRBuilder &MIRBuilder,
                           IncomingValueHandler &Handler,
                           IncomingValueAssigner &Assigner,
                           CCState &CCInfo) const;
};
} // namespace llvm

#endif
