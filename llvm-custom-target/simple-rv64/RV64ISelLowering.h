//===-- RV64ISelLowering.h - RV64 DAG Lowering Interface ----------*- C++ -*-===//

#ifndef LLVM_LIB_TARGET_RV64_RV64ISELLOWERING_H
#define LLVM_LIB_TARGET_RV64_RV64ISELLOWERING_H

#include "RV64.h"
#include "llvm/CodeGen/CallingConvLower.h"
#include "llvm/CodeGen/SelectionDAG.h"
#include "llvm/CodeGen/TargetLowering.h"


namespace llvm {
class RV64Subtarget;

class RV64TargetLowering : public TargetLowering {
public:
  explicit RV64TargetLowering(const TargetMachine &TM, const RV64Subtarget &STI);

  bool allowsMisalignedMemoryAccesses(EVT VT, unsigned, Align,
                                      MachineMemOperand::Flags,
                                      unsigned *) const override;

  RV64TargetLowering::ConstraintType getConstraintType(StringRef Constraint) const override;

  std::pair<unsigned, const TargetRegisterClass *>
  getRegForInlineAsmConstraint(const TargetRegisterInfo *TRI,
                               StringRef Constraint, MVT VT) const override;

  EVT getSetCCResultType(const DataLayout &DL, LLVMContext &Context,
                         EVT VT) const override;

  MVT getScalarShiftAmountTy(const DataLayout &, EVT) const override;

  CCAssignFn *CCAssignFnForCall(CallingConv::ID CC, bool isVarArg) const;

  CCAssignFn *CCAssignFnForReturn(CallingConv::ID CC, bool isVarArg) const;

  CCAssignFn *CCAssignFnForNode(CallingConv::ID CC, bool Return, bool isVarArg) const;

private:
  // Allows Misalignment
  bool AllowsMisalignedMemAccess;

  bool isIntDivCheap(EVT VT, AttributeList Attr) const override {
    return false;
  }

  bool shouldConvertConstantLoadToIntImm(const APInt &Imm,
                                         Type *Ty) const override {
    return true;
  }

  bool isLegalAddressingMode(const DataLayout &DL, const AddrMode &AM,
                             Type *Ty, unsigned AS,
                             Instruction *I = nullptr) const override;

};
}

#endif
