//===-- RV64InstrInfo.cpp - RV64 Instruction Information ----------*- C++ -*-===//
//
// This file contains the RV64 implementation of the TargetInstrInfo class.
//
//===----------------------------------------------------------------------===//

#include "RV64InstrInfo.h"
#include "RV64.h"
#include "RV64Subtarget.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/IR/DebugLoc.h"
#include "llvm/Support/ErrorHandling.h"
#include <cassert>
#include <iterator>

#define GET_INSTRINFO_CTOR_DTOR
#include "RV64GenInstrInfo.inc"

using namespace llvm;

RV64InstrInfo::RV64InstrInfo(const RV64Subtarget &STI)
    : RV64GenInstrInfo(STI, RI, RV::ADJCALLSTACKDOWN, RV::ADJCALLSTACKUP) {}

void RV64InstrInfo::copyPhysReg(MachineBasicBlock &MBB,
                               MachineBasicBlock::iterator I,
                               const DebugLoc &DL, Register DestReg,
                               Register SrcReg, bool KillSrc,
                               bool RenamableDest, bool RenamableSrc) const {
  if (RV::GeneralPurposeRegistersRegClass.contains(DestReg, SrcReg)) {
    BuildMI(MBB, I, DL, get(RV::ADDI), DestReg)
        .addReg(SrcReg, getKillRegState(KillSrc) | getRenamableRegState(RenamableSrc))
        .addImm(0);
  }
  else {
    llvm_unreachable("Impossible reg-to-reg copy");
  }
}

void RV64InstrInfo::storeRegToStackSlot(MachineBasicBlock &MBB,
                                       MachineBasicBlock::iterator I,
                                       Register SrcReg, bool IsKill, int FI,
                                       const TargetRegisterClass *RC,
                                       Register VReg,
                                       MachineInstr::MIFlag Flags) const {
  DebugLoc DL;
  if (I != MBB.end())
    DL = I->getDebugLoc();

  assert(RC == &RV::GeneralPurposeRegistersRegClass && "Unexpected register class");
  BuildMI(MBB, I, DL, get(RV::SD))
      .addFrameIndex(FI)
      .addImm(0)
      .addReg(SrcReg, getKillRegState(IsKill));
}

void RV64InstrInfo::loadRegFromStackSlot(MachineBasicBlock &MBB,
                                        MachineBasicBlock::iterator I,
                                        Register DestReg, int FI,
                                        const TargetRegisterClass *RC,
                                        Register VReg, unsigned SubReg,
                                        MachineInstr::MIFlag Flags) const {
  DebugLoc DL;
  if (I != MBB.end())
    DL = I->getDebugLoc();

  assert(RC == &RV::GeneralPurposeRegistersRegClass && "Unexpected register class");
  BuildMI(MBB, I, DL, get(RV::LD), DestReg).addFrameIndex(FI).addImm(0);
}
