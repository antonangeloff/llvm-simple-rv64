//===-- RV64ISelLowering.cpp - RV64 DAG Lowering Implementation  ------------===//
//
// This file defines the interfaces that RV64 uses to lower LLVM code into a
// selection DAG.
//
//===----------------------------------------------------------------------===//

#include "RV64ISelLowering.h"
#include "RV64.h"
#include "RV64Subtarget.h"
#include "llvm/CodeGen/CallingConvLower.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/TargetLoweringObjectFileImpl.h"
#include "llvm/CodeGen/ValueTypes.h"
#include "llvm/IR/DIBuilder.h"
#include "llvm/IR/DiagnosticInfo.h"
#include "llvm/IR/DiagnosticPrinter.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/MathExtras.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

#define DEBUG_TYPE "RV64-lower"

RV64TargetLowering::RV64TargetLowering(const TargetMachine &TM,
                                     const RV64Subtarget &STI)
    : TargetLowering(TM, STI) {

  // Set up the register classes.
  addRegisterClass(MVT::i64, &RV::GeneralPurposeRegistersRegClass);

  // Compute derived properties from the register classes
  computeRegisterProperties(STI.getRegisterInfo());

  setStackPointerRegisterToSaveRestore(RV::X2);
  setBooleanContents(ZeroOrOneBooleanContent);
  setMaxAtomicSizeInBitsSupported(64);
  // setMinimumJumpTableEntries(RV64MinimumJumpTableEntries);

  // Function alignments
  setMinFunctionAlignment(Align(4));
  setPrefFunctionAlignment(Align(4));
  AllowsMisalignedMemAccess = false;
}

bool RV64TargetLowering::allowsMisalignedMemoryAccesses(EVT VT, unsigned, Align,
                                                       MachineMemOperand::Flags,
                                                       unsigned *Fast) const {
  // allows-misaligned-mem-access is disabled
  if (!AllowsMisalignedMemAccess)
    return false;

  // only allow misalignment for simple value types
  if (!VT.isSimple())
    return false;

  // always assume fast mode when misalignment is allowed
  if (Fast)
    *Fast = true;

  return true;
}

RV64TargetLowering::ConstraintType
RV64TargetLowering::getConstraintType(StringRef Constraint) const {
  // TODO: inline asm constraints not yet implemented.
  return TargetLowering::getConstraintType(Constraint);
}

std::pair<unsigned, const TargetRegisterClass *>
RV64TargetLowering::getRegForInlineAsmConstraint(const TargetRegisterInfo *TRI,
                                                StringRef Constraint,
                                                MVT VT) const {
  // TODO: inline asm constraints not yet implemented.
  return TargetLowering::getRegForInlineAsmConstraint(TRI, Constraint, VT);
}

// Calling Convention Implementation
#define GET_CALLING_CONV_IMPL
#include "RV64GenCallingConv.inc"

EVT RV64TargetLowering::getSetCCResultType(const DataLayout &, LLVMContext &,
                                          EVT VT) const {
  return MVT::i64;
}

MVT RV64TargetLowering::getScalarShiftAmountTy(const DataLayout &DL,
                                              EVT VT) const {
  return MVT::i64;
}

bool RV64TargetLowering::isLegalAddressingMode(const DataLayout &DL,
                                              const AddrMode &AM, Type *Ty,
                                              unsigned AS,
                                              Instruction *I) const {
  // No global is ever allowed as a base.
  if (AM.BaseGV)
    return false;

  switch (AM.Scale) {
  case 0: // "r+i" or just "i", depending on HasBaseReg.
    break;
  case 1:
    if (!AM.HasBaseReg) // allow "r+i".
      break;
    return false; // disallow "r+r" or "r+r+i".
  default:
    return false;
  }

  return true;
}

CCAssignFn *RV64TargetLowering::CCAssignFnForCall(CallingConv::ID CC,
                                                 bool isVarArg) const {
  return CCAssignFnForNode(CC, false, isVarArg);
}

CCAssignFn *RV64TargetLowering::CCAssignFnForReturn(CallingConv::ID CC,
                                                   bool isVarArg) const {
  return CCAssignFnForNode(CC, true, isVarArg);
}

// Selects the correct CCAssignFn for the given CallingConvention.
CCAssignFn *RV64TargetLowering::CCAssignFnForNode(CallingConv::ID CC,
                                                 bool Return,
                                                 bool isVarArg) const {
  return Return ? RetCC_RV64_LP64 : CC_RV64_LP64;
}