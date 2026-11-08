//===-- RV64FrameLowering.h - Define frame lowering for RV64 -----*- C++ -*--===//
//
// This class implements RV64-specific bits of TargetFrameLowering class.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RV64_RV64FRAMELOWERING_H
#define LLVM_LIB_TARGET_RV64_RV64FRAMELOWERING_H

#include "llvm/CodeGen/TargetFrameLowering.h"

namespace llvm {
class RV64Subtarget;

class RV64FrameLowering : public TargetFrameLowering {
public:
  explicit RV64FrameLowering(const RV64Subtarget &sti)
      : TargetFrameLowering(TargetFrameLowering::StackGrowsDown, Align(16), 0, Align(16)) {}

  void emitPrologue(MachineFunction &MF, MachineBasicBlock &MBB) const override;
  void emitEpilogue(MachineFunction &MF, MachineBasicBlock &MBB) const override;

  // void determineCalleeSaves(MachineFunction &MF, BitVector &SavedRegs,
  //                           RegScavenger *RS) const override;

  void processFunctionBeforeFrameFinalized(MachineFunction &MF,
                                           RegScavenger *RS) const override;

  MachineBasicBlock::iterator
  eliminateCallFramePseudoInstr(MachineFunction &MF, MachineBasicBlock &MBB,
                                MachineBasicBlock::iterator MI) const override {
    return MBB.erase(MI);
  }

  StackOffset getFrameIndexReference(const MachineFunction &MF, int FI,
                                     Register &FrameReg) const override;

protected:
  bool hasFPImpl(const MachineFunction &MF) const override;
};
}
#endif
