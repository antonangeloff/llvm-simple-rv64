//===- RV64RegisterBankInfo.cpp --------------------------------------------===//
/// \file
/// This file implements the targeting of the RegisterBankInfo class for RV64
//===----------------------------------------------------------------------===//

#include "RV64RegisterBankInfo.h"
#include "llvm/CodeGen/TargetSubtargetInfo.h"

#define DEBUG_TYPE "RV64-reg-bank-info"

#define GET_TARGET_REGBANK_IMPL
#include "RV64GenRegisterBank.inc"

using namespace llvm;

RV64RegisterBankInfo::RV64RegisterBankInfo(const TargetRegisterInfo &TRI)
    : RV64GenRegisterBankInfo() {}

const RegisterBankInfo::InstructionMapping &
RV64RegisterBankInfo::getInstrMapping(const MachineInstr &MI) const {
  const unsigned Opc = MI.getOpcode();

  // Try the default logic for non-generic instructions that are either
  // copies or already have some operands assigned register classes.
  if (!isPreISelGenericOpcode(Opc) || Opc == TargetOpcode::COPY) {
    const InstructionMapping &Mapping = getInstrMappingImpl(MI);
    if (Mapping.isValid())
      return Mapping;
  }

  const MachineFunction &MF = *MI.getParent()->getParent();
  const MachineRegisterInfo &MRI = MF.getRegInfo();
  const TargetRegisterInfo &TRI = *MF.getSubtarget().getRegisterInfo();

  unsigned NumOperands = MI.getNumOperands();
  SmallVector<const ValueMapping *, 4> OpdsMapping(NumOperands);

  for (unsigned Idx = 0; Idx < NumOperands; ++Idx) {
    const MachineOperand &MO = MI.getOperand(Idx);
    if (!MO.isReg() || !MO.getReg())
      continue;
    TypeSize Size = getSizeInBits(MO.getReg(), MRI, TRI);
    OpdsMapping[Idx] = &getValueMapping(0, Size.getKnownMinValue(), RV64::GPRRegBank);
  }

  return getInstructionMapping(DefaultMappingID, /*Cost=*/1,
                                getOperandsMapping(OpdsMapping), NumOperands);
}