//===- RV64LegalizerInfo.h ----------------------------------------*- C++ -*-==//
/// \file
/// This file declares the targeting of the Machinelegalizer class for RV64
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RV64_GISEL_RV64MACHINELEGALIZER_H
#define LLVM_LIB_TARGET_RV64_GISEL_RV64MACHINELEGALIZER_H

#include "llvm/CodeGen/GlobalISel/LegalizerInfo.h"

namespace llvm {

class MachineIRBuilder;
class RV64Subtarget;

/// This class provides the information for the RV64 target legalizer for
/// GlobalISel.
class RV64LegalizerInfo : public LegalizerInfo {
public:
  RV64LegalizerInfo(const RV64Subtarget &ST);

  bool legalizeCustom(LegalizerHelper &Helper, MachineInstr &MI,
                      LostDebugLocObserver &LocObserver) const override;

private:
  bool legalizeVAStart(MachineInstr &MI, MachineIRBuilder &MIRBuilder) const;
  bool legalizeSoftFConstant(MachineInstr &MI, MachineIRBuilder &MIRBuilder) const;
  bool legalizeSoftFCmp(MachineInstr &MI, LegalizerHelper &Helper,
                    LostDebugLocObserver &LocObserver) const;
};
} // namespace llvm
#endif
