//===-- RV64InstrInfo.h - RV64 Instruction Information ------------*- C++ -*-===//
//
// This file contains the RV64 implementation of the TargetInstrInfo class.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RV64_RV64INSTRINFO_H
#define LLVM_LIB_TARGET_RV64_RV64INSTRINFO_H

#include "RV64RegisterInfo.h"
#include "llvm/CodeGen/TargetInstrInfo.h"

#define GET_INSTRINFO_HEADER
#include "RV64GenInstrInfo.inc"

namespace llvm {
class RV64Subtarget;

class RV64InstrInfo : public RV64GenInstrInfo {
  const RV64RegisterInfo RI;

public:
  explicit RV64InstrInfo(const RV64Subtarget &STI);

  const RV64RegisterInfo &getRegisterInfo() const { return RI; }

  void copyPhysReg(MachineBasicBlock &MBB, MachineBasicBlock::iterator I,
                   const DebugLoc &DL, Register DestReg, Register SrcReg,
                   bool KillSrc, bool RenamableDest = false,
                   bool RenamableSrc = false) const override;

  void storeRegToStackSlot(
      MachineBasicBlock &MBB, MachineBasicBlock::iterator MBBI, Register SrcReg,
      bool isKill, int FrameIndex, const TargetRegisterClass *RC, Register VReg,
      MachineInstr::MIFlag Flags = MachineInstr::NoFlags) const override;

  void loadRegFromStackSlot(
      MachineBasicBlock &MBB, MachineBasicBlock::iterator MBBI,
      Register DestReg, int FrameIndex, const TargetRegisterClass *RC,
      Register VReg, unsigned SubReg = 0,
      MachineInstr::MIFlag Flags = MachineInstr::NoFlags) const override;

};
}

#endif
