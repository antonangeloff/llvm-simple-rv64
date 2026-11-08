//===-- RV64RegisterBankInfo.h -----------------------------------*- C++ -*-===//
///
/// \file
/// This file declares the targeting of the RegisterBankInfo class for RV64.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RV64_GISEL_RV64REGISTERBANKINFO_H
#define LLVM_LIB_TARGET_RV64_GISEL_RV64REGISTERBANKINFO_H

#include "MCTargetDesc/RV64MCTargetDesc.h"
#include "llvm/CodeGen/RegisterBankInfo.h"
#include "llvm/CodeGen/TargetRegisterInfo.h"

#define GET_REGBANK_DECLARATIONS
#include "RV64GenRegisterBank.inc"

namespace llvm {
class TargetRegisterInfo;

class RV64GenRegisterBankInfo : public RegisterBankInfo {
protected:
#define GET_TARGET_REGBANK_CLASS
#include "RV64GenRegisterBank.inc"
};

class RV64RegisterBankInfo final : public RV64GenRegisterBankInfo {
public:
  RV64RegisterBankInfo(const TargetRegisterInfo &TRI);
  const InstructionMapping &getInstrMapping(const MachineInstr &MI) const override;
};
} // namespace llvm

#endif
