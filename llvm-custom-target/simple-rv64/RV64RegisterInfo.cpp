//===-- RV64RegisterInfo.cpp - RV64 Register Information --------*- C++ -*-===//
//
// This file contains the RV64 implementation of the TargetRegisterInfo class.
//
//===----------------------------------------------------------------------===//

#include "RV64RegisterInfo.h"
#include "RV64Subtarget.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/RegisterScavenging.h"
#include "llvm/CodeGen/TargetFrameLowering.h"
#include "llvm/CodeGen/TargetInstrInfo.h"
#include "llvm/IR/DiagnosticInfo.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/ErrorHandling.h"

#define GET_REGINFO_TARGET_DESC
#include "RV64GenRegisterInfo.inc"
using namespace llvm;

RV64RegisterInfo::RV64RegisterInfo()
    : RV64GenRegisterInfo(RV::X1) {}

const MCPhysReg *
RV64RegisterInfo::getCalleeSavedRegs(const MachineFunction *MF) const {
  return CSR_SaveList;
}

const uint32_t *
RV64RegisterInfo::getCallPreservedMask(const MachineFunction &MF,
                                      CallingConv::ID CC) const {
  switch (CC) {
  default:
    return CSR_RegMask;
  }
}

BitVector RV64RegisterInfo::getReservedRegs(const MachineFunction &MF) const {
  BitVector Reserved(getNumRegs());

  markSuperRegs(Reserved, RV::X0);
  markSuperRegs(Reserved, RV::X2);
  markSuperRegs(Reserved, RV::X3);
  markSuperRegs(Reserved, RV::X4);

  if (getFrameLowering(MF)->hasFP(MF)) {
    markSuperRegs(Reserved, RV::X8);
  }

  return Reserved;
}

// Materializes Imm (which must not fit in a 12-bit immediate, and must fit in
// 32 bits) into ScratchReg via LUI+ADDIW. ScratchReg must be a fixed physical
// register: this runs after register allocation, so there is no RA pass left
// to assign a fresh virtual register to a physical one.
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

// Parse a single MachineInstr and replace stack slot placeholder operand with
// actual base register / immediate offset.
bool RV64RegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator II,
                                          int SPAdj, unsigned FIOperandNum,
                                          RegScavenger *RS) const {
  assert(SPAdj == 0 && "Unexpected");

  unsigned i = 0;
  MachineInstr &MI = *II;
  MachineBasicBlock &MBB = *MI.getParent();
  MachineFunction &MF = *MBB.getParent();

  // TODO: use FIOperandNum
  while (!MI.getOperand(i).isFI()) {
    ++i;
    assert(i < MI.getNumOperands() && "Instr doesn't have FrameIndex operand!");
  }

  Register FrameReg = getFrameRegister(MF);
  int FrameIndex = MI.getOperand(i).getIndex();
  int Offset = MF.getFrameInfo().getObjectOffset(FrameIndex) +
               MF.getFrameInfo().getStackSize() +
               MI.getOperand(i + 1).getImm();

  if (isInt<12>(Offset)) {
    MI.getOperand(i).ChangeToRegister(FrameReg, false);
    MI.getOperand(i + 1).ChangeToImmediate(Offset);
  } else {
    assert(RS && "Register scavenging must be on");

    for (MachineOperand &Op : MI.operands()) {
      if (Op.isReg() && Op.getReg().isPhysical() && &Op != &MI.getOperand(i)) {
        RS->setRegUsed(Op.getReg());
      }
    }

    Register ScratchReg = RS->FindUnusedReg(&RV::GeneralPurposeRegistersRegClass);

    if (!ScratchReg) {
      // No unused registers found
      ScratchReg = RS->scavengeRegisterBackwards(RV::GeneralPurposeRegistersRegClass, II, /*RestoreAfter=*/false, SPAdj);
      assert(ScratchReg && "Register scavenger failed");
    }

    const TargetInstrInfo *TII = MF.getSubtarget().getInstrInfo();
    materializeOffset(MBB, II, MI.getDebugLoc(), TII, ScratchReg, Offset);
    BuildMI(MBB, II, MI.getDebugLoc(), TII->get(RV::ADD), ScratchReg)
        .addReg(ScratchReg)
        .addReg(FrameReg);
    MI.getOperand(i).ChangeToRegister(ScratchReg, false);
    MI.getOperand(i + 1).ChangeToImmediate(0);
  }

  return false;
}

Register RV64RegisterInfo::getFrameRegister(const MachineFunction &MF) const {
  return getFrameLowering(MF)->hasFP(MF) ? RV::X8 : RV::X2;
}
