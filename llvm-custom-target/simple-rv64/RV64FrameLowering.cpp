//===-- RV64FrameLowering.cpp - RV64 Frame Information ----------------------===//
//
// This file contains the RV64 implementation of TargetFrameLowering class.
//
//===----------------------------------------------------------------------===//

#include "RV64FrameLowering.h"
#include "RV64Subtarget.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/RegisterScavenging.h"

using namespace llvm;

bool RV64FrameLowering::hasFPImpl(const MachineFunction &MF) const {
  return false;
}

// Materializes Imm into ScratchReg via LUI+ADDIW. ScratchReg must be a fixed
// physical register: this runs after register allocation, so there is no RA
// pass left to assign a fresh virtual register to a physical one.
// TODO: same function implemented in RV64RegisterInfo.cpp; worth merging.
static void materializeOffset(MachineBasicBlock &MBB,
                             MachineBasicBlock::iterator InsertPt,
                             const DebugLoc &DL, const TargetInstrInfo *TII,
                             Register ScratchReg, int64_t Imm) {
  assert(!isInt<12>(Imm) && "use the immediate directly for small offsets");
  assert(isInt<32>(Imm) && "frames larger than 2GB are not yet supported");

  int64_t immLui = ((Imm + 0x800) >> 12) & 0xFFFFF;
  int64_t immAddi = SignExtend64<12>(Imm - (immLui << 12));

  BuildMI(MBB, InsertPt, DL, TII->get(RV::LUI), ScratchReg).addImm(immLui);
  BuildMI(MBB, InsertPt, DL, TII->get(RV::ADDIW), ScratchReg)
      .addReg(ScratchReg)
      .addImm(immAddi);
}

void RV64FrameLowering::emitPrologue(MachineFunction &MF,
                                    MachineBasicBlock &MBB) const {
  MachineFrameInfo &MFI = MF.getFrameInfo();
  const TargetInstrInfo *TII = MF.getSubtarget().getInstrInfo();
  DebugLoc DL;

  uint64_t FrameSize = MFI.getStackSize();
  if (FrameSize == 0) {
    return;
  }

  MachineBasicBlock::iterator MBBI = MBB.begin();

  if (isInt<12>(-(int64_t)FrameSize)) {
    BuildMI(MBB, MBBI, DL, TII->get(RV::ADDI), RV::X2)
        .addReg(RV::X2)
        .addImm(-(int64_t)FrameSize);
  } else {
    materializeOffset(MBB, MBBI, DL, TII, RV::X5, (int64_t)FrameSize);
    BuildMI(MBB, MBBI, DL, TII->get(RV::SUB), RV::X2)
        .addReg(RV::X2)
        .addReg(RV::X5);
  }

  if (MF.needsFrameMoves()) {
    unsigned CFIIndex = MF.addFrameInst(MCCFIInstruction::cfiDefCfaOffset(nullptr, FrameSize));
    BuildMI(MBB, MBBI, DL, TII->get(TargetOpcode::CFI_INSTRUCTION)).addCFIIndex(CFIIndex);
  }
}

void RV64FrameLowering::emitEpilogue(MachineFunction &MF,
                                    MachineBasicBlock &MBB) const {
  MachineFrameInfo &MFI = MF.getFrameInfo();
  const TargetInstrInfo *TII = MF.getSubtarget().getInstrInfo();
  DebugLoc DL;

  uint64_t FrameSize = MFI.getStackSize();
  if (FrameSize == 0) {
    return;
  }

  MachineBasicBlock::iterator MBBI = MBB.getFirstTerminator();

  if (isInt<12>((int64_t)FrameSize)) {
    BuildMI(MBB, MBBI, DL, TII->get(RV::ADDI), RV::X2)
        .addReg(RV::X2)
        .addImm((int64_t)FrameSize);
  } else {
    materializeOffset(MBB, MBBI, DL, TII, RV::X5, (int64_t)FrameSize);
    BuildMI(MBB, MBBI, DL, TII->get(RV::ADD), RV::X2)
        .addReg(RV::X2)
        .addReg(RV::X5);
  }

  if (MF.needsFrameMoves()) {
    unsigned CFIIndex = MF.addFrameInst(MCCFIInstruction::cfiDefCfaOffset(nullptr, 0));
    BuildMI(MBB, MBBI, DL, TII->get(TargetOpcode::CFI_INSTRUCTION)).addCFIIndex(CFIIndex);
  }
}

// Reserves an emergency spill slot for eliminateFrameIndex's register
// scavenging, but only when the stack size risks not fitting a 12-bit immediate.
void RV64FrameLowering::processFunctionBeforeFrameFinalized(
    MachineFunction &MF, RegScavenger *RS) const {
  if (isInt<11>((int64_t)MF.getFrameInfo().estimateStackSize(MF)))
    return;

  MachineFrameInfo &MFI = MF.getFrameInfo();
  const TargetRegisterInfo *RI = MF.getSubtarget().getRegisterInfo();
  const TargetRegisterClass &RC = RV::GeneralPurposeRegistersRegClass;

  int FI = MFI.CreateSpillStackObject(RI->getSpillSize(RC), RI->getSpillAlign(RC));
  RS->addScavengingFrameIndex(FI);
}

StackOffset RV64FrameLowering::getFrameIndexReference(const MachineFunction &MF,
                                                     int FI,
                                                     Register &FrameReg) const {
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  const TargetRegisterInfo *RI = MF.getSubtarget().getRegisterInfo();

  FrameReg = RI->getFrameRegister(MF);

  return StackOffset::getFixed(MFI.getObjectOffset(FI));
}
