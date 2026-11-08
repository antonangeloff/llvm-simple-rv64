//===- RV64InstructionSelector.cpp --------------------------------*- C++ -*-==//
/// \file
/// This file implements the targeting of the InstructionSelector class for RV64.
//===----------------------------------------------------------------------===//

#include "RV64BaseInfo.h"
#include "RV64InstrInfo.h"
#include "RV64RegisterBankInfo.h"
#include "RV64Subtarget.h"
#include "RV64TargetMachine.h"
#include "llvm/CodeGen/GlobalISel/GIMatchTableExecutorImpl.h"
#include "llvm/CodeGen/GlobalISel/InstructionSelector.h"
#include "llvm/CodeGen/GlobalISel/MachineIRBuilder.h"
#include "llvm/CodeGen/GlobalISel/Utils.h"
#include "llvm/CodeGen/GlobalISel/MIPatternMatch.h"
#include "llvm/CodeGen/MachineJumpTableInfo.h"

#define DEBUG_TYPE "RV64-gisel"

using namespace llvm;

namespace {

static bool selectCopy(MachineInstr &I, const TargetInstrInfo &TII,
                        MachineRegisterInfo &MRI, const TargetRegisterInfo &TRI,
                        const RV64RegisterBankInfo &RBI) {
  Register DstReg = I.getOperand(0).getReg();
  Register SrcReg = I.getOperand(1).getReg();

  if (DstReg.isVirtual() && !RBI.constrainGenericRegister(DstReg, RV::GeneralPurposeRegistersRegClass, MRI)) {
    return false;
  }

  if (SrcReg.isVirtual() && !RBI.constrainGenericRegister(SrcReg, RV::GeneralPurposeRegistersRegClass, MRI)) {
    return false;
  }

  I.setDesc(TII.get(TargetOpcode::COPY));
  return true;
}

static bool selectConstant(MachineInstr &I, const TargetInstrInfo &TII,
                            const TargetRegisterInfo &TRI,
                            const RV64RegisterBankInfo &RBI) {
  int64_t Imm = I.getOperand(1).getCImm()->getSExtValue();
  Register DstReg = I.getOperand(0).getReg();
  MachineRegisterInfo &MRI = I.getParent()->getParent()->getRegInfo();

  if (isInt<12>(Imm)) {
    // Constant materialization for integer literals which fit 12 bits
    MachineInstr *NewAddi =
        BuildMI(*I.getParent(), I, I.getDebugLoc(), TII.get(RV::ADDI), DstReg)
            .addReg(RV::X0)
            .addImm(Imm);
    constrainSelectedInstRegOperands(*NewAddi, TII, TRI, RBI);
  }
  else {
    // Constant materialization for wide integer literals - up to 64 bits
    SmallVector<int64_t, 4> lo12Chunks;
    int64_t immRemainder = Imm;

    while (!isInt<32>(immRemainder)) {
      lo12Chunks.push_back(SignExtend64<12>(immRemainder));
      immRemainder = static_cast<int64_t>(static_cast<uint64_t>(immRemainder) + 0x800) >> 12;
    }

    int64_t immLui = ((immRemainder + 0x800) >> 12) & 0xFFFFF;
    int64_t immAddi = SignExtend64<12>(immRemainder - (immLui << 12));
    std::vector<Register> intermediateRegs = { DstReg };

    if (immLui) {
      intermediateRegs.push_back(MRI.createVirtualRegister(&RV::GeneralPurposeRegistersRegClass));
      MachineInstr *NewLui =
          BuildMI(*I.getParent(), I, I.getDebugLoc(), TII.get(RV::LUI), intermediateRegs.back())
              .addImm(immLui);
      constrainSelectedInstRegOperands(*NewLui, TII, TRI, RBI);
    }

    if (immAddi || immLui == 0) {
      intermediateRegs.push_back(MRI.createVirtualRegister(&RV::GeneralPurposeRegistersRegClass));
      MachineInstr *NewAddi =
          BuildMI(*I.getParent(), I, I.getDebugLoc(), TII.get(RV::ADDIW), intermediateRegs.back())
              .addReg(intermediateRegs.rbegin()[1])
              .addImm(immAddi);
      constrainSelectedInstRegOperands(*NewAddi, TII, TRI, RBI);
    }

    for (int64_t lo12 : llvm::reverse(lo12Chunks)) {
      intermediateRegs.push_back(MRI.createVirtualRegister(&RV::GeneralPurposeRegistersRegClass));
      MachineInstr *NewSlli =
          BuildMI(*I.getParent(), I, I.getDebugLoc(),
                  TII.get(RV::SLLI), intermediateRegs.back())
              .addReg(intermediateRegs.rbegin()[1])
              .addImm(12);
      constrainSelectedInstRegOperands(*NewSlli, TII, TRI, RBI);

      if (lo12) {
        intermediateRegs.push_back(MRI.createVirtualRegister(&RV::GeneralPurposeRegistersRegClass));
        MachineInstr *NewAddi =
            BuildMI(*I.getParent(), I, I.getDebugLoc(),
                    TII.get(RV::ADDI), intermediateRegs.back())
                .addReg(intermediateRegs.rbegin()[1])
                .addImm(lo12);
        constrainSelectedInstRegOperands(*NewAddi, TII, TRI, RBI);
      }
    }

    RBI.constrainGenericRegister(DstReg, RV::GeneralPurposeRegistersRegClass, MRI);
    BuildMI(*I.getParent(), I, I.getDebugLoc(), TII.get(TargetOpcode::COPY), DstReg)
        .addReg(intermediateRegs.back());
  }

  I.eraseFromParent();
  return true;
}

static unsigned getBranchOpcodeForPredicate(CmpInst::Predicate Pred, bool &SwapOperands) {
  SwapOperands = false;
  switch (Pred) {
  case CmpInst::ICMP_EQ:  return RV::BEQ;
  case CmpInst::ICMP_NE:  return RV::BNE;
  case CmpInst::ICMP_SLT: return RV::BLT;
  case CmpInst::ICMP_SGE: return RV::BGE;
  case CmpInst::ICMP_ULT: return RV::BLTU;
  case CmpInst::ICMP_UGE: return RV::BGEU;
  case CmpInst::ICMP_SGT: SwapOperands = true; return RV::BLT;   // a > b  <=>  b < a
  case CmpInst::ICMP_SLE: SwapOperands = true; return RV::BGE;   // a <= b <=> b >= a
  case CmpInst::ICMP_UGT: SwapOperands = true; return RV::BLTU;
  case CmpInst::ICMP_ULE: SwapOperands = true; return RV::BGEU;
  default: llvm_unreachable("unexpected icmp predicate");
  }
}

static bool selectPhi(MachineInstr &I, const TargetInstrInfo &TII,
                          MachineRegisterInfo &MRI,
                          const TargetRegisterInfo &TRI,
                          const RegisterBankInfo &RBI) {
  auto constrainToClass = [&](Register Reg) {
    const RegClassOrRegBank &RCOrBank = MRI.getRegClassOrRegBank(Reg);
    if (!dyn_cast<const TargetRegisterClass *>(RCOrBank)) {
      const TargetRegisterClass *RC = &RV::GeneralPurposeRegistersRegClass;
      MRI.setRegClass(Reg, RC);
    }
  };

  constrainToClass(I.getOperand(0).getReg());

  for (unsigned Idx = 1; Idx < I.getNumOperands(); Idx += 2) {
    constrainToClass(I.getOperand(Idx).getReg());
  }

  // Change G_PHI's opcode to PHI
  I.setDesc(TII.get(TargetOpcode::PHI));
  return true;
}

static bool selectSZExt(MachineInstr &I, const TargetInstrInfo &TII,
                          MachineRegisterInfo &MRI,
                          const TargetRegisterInfo &TRI,
                          const RegisterBankInfo &RBI) {

  Register SrcReg = I.getOperand(1).getReg();
  Register DstReg = I.getOperand(0).getReg();
  int shiftAmt = TRI.getRegSizeInBits(RV::GeneralPurposeRegistersRegClass) -
                 MRI.getType(SrcReg).getSizeInBits();
  int gop = I.getOpcode();

  assert(shiftAmt > 0 && "zext expects dst bits > src bits");
  assert((gop == TargetOpcode::G_ZEXT || gop == TargetOpcode::G_SEXT) && "Invalid opcode");

  // TODO: possibly use `addiw` for sign extending 32 to 64 bit..

  Register IntermediateReg = MRI.createVirtualRegister(&RV::GeneralPurposeRegistersRegClass);
  MachineInstr *NewSlli =
      BuildMI(*I.getParent(), I, I.getDebugLoc(), TII.get(RV::SLLI), IntermediateReg)
          .addReg(SrcReg)
          .addImm(shiftAmt);
  constrainSelectedInstRegOperands(*NewSlli, TII, TRI, RBI);

  int ShiftRightOpcode = gop == TargetOpcode::G_ZEXT ? RV::SRLI : RV::SRAI;
  MachineInstr *NewSrli =
      BuildMI(*I.getParent(), I, I.getDebugLoc(), TII.get(ShiftRightOpcode), DstReg)
          .addReg(IntermediateReg)
          .addImm(shiftAmt);

  constrainSelectedInstRegOperands(*NewSrli, TII, TRI, RBI);
  I.eraseFromParent();
  return true;
}

static bool selectBrCond(MachineInstr &I, const TargetInstrInfo &TII,
                          MachineRegisterInfo &MRI, // todo: get from `I` instead of passing as arg
                          const TargetRegisterInfo &TRI,
                          const RegisterBankInfo &RBI) {

  using namespace llvm::MIPatternMatch;
  Register GMIRCondReg = I.getOperand(0).getReg();
  MachineBasicBlock *GMIRTargetMBB = I.getOperand(1).getMBB();

  Register LHS, RHS;
  CmpInst::Predicate Pred;
  unsigned Opc;
  bool Swap = false;

  if (mi_match(GMIRCondReg, MRI, m_GICmp(m_Pred(Pred), m_Reg(LHS), m_Reg(RHS)))) {
    // Comparison
    Opc = getBranchOpcodeForPredicate(Pred, Swap);
    if (Swap) {
      std::swap(LHS, RHS);
    }
  } else {
    // Non-zero test
    LHS = GMIRCondReg;
    RHS = RV::X0;
    Opc = RV::BNE;
  }

  MachineInstr *NewBr = BuildMI(*I.getParent(), I, I.getDebugLoc(), TII.get(Opc))
                            .addReg(LHS).addReg(RHS).addMBB(GMIRTargetMBB);
  I.eraseFromParent();
  constrainSelectedInstRegOperands(*NewBr, TII, TRI, RBI);
  return true;
}

static bool foldLoadStoreOperands(MachineInstrBuilder MIB, MachineRegisterInfo &MRI, MachineInstr *DefiningInstr) {
  if (DefiningInstr->getOpcode() == TargetOpcode::G_FRAME_INDEX) {
    // Preceding GMIR instruction is G_FRAME_INDEX - fold the frame-index placeholder directly into the load/store
    MIB.addFrameIndex(DefiningInstr->getOperand(1).getIndex()).addImm(0);
    return true;
  }

  if (DefiningInstr->getOpcode() == TargetOpcode::G_PTR_ADD) {
    // Preceeding G_PTR_ADD
    std::optional<ValueAndVReg> Cst = getIConstantVRegValWithLookThrough(DefiningInstr->getOperand(2).getReg(), MRI);

    if (!Cst.has_value()) {
      return false;
    }

    // If defining instruction of G_PTR_ADD's second operand (base register) is G_FRAME_INDEX - fold directly
    MachineInstr *PtrAddDefiningInstr = MRI.getVRegDef(DefiningInstr->getOperand(1).getReg());
    if (PtrAddDefiningInstr->getOpcode() == TargetOpcode::G_FRAME_INDEX) {
      MIB.addFrameIndex(PtrAddDefiningInstr->getOperand(1).getIndex()).addImm(Cst->Value.getSExtValue());
      return true;
    }

    // Otherwise fold the G_PTR_ADD's base register and offset into the load/store
    if (isInt<12>(Cst->Value.getSExtValue())) {
      MIB.addReg(DefiningInstr->getOperand(1).getReg()).addImm(Cst->Value.getSExtValue());
      return true;
    }
  }

  return false;
}

static bool selectLoad(MachineInstr &I, const TargetInstrInfo &TII,
                            const TargetRegisterInfo &TRI,
                            const RV64RegisterBankInfo &RBI) {
  Register AddrReg = I.getOperand(1).getReg();
  Register DstReg = I.getOperand(0).getReg();
  MachineRegisterInfo &MRI = I.getParent()->getParent()->getRegInfo();

  MachineInstr *AddrDef = MRI.getVRegDef(AddrReg);

  int opcode;

  switch (MRI.getType(DstReg).getSizeInBits()) {
    default:
      llvm_unreachable("unexpected bit size");
    case 8:
      opcode = RV::LB;
      break;
    case 16:
      opcode = RV::LH;
      break;
    case 32:
      opcode = RV::LW;
      break;
    case 64:
      opcode = RV::LD;
      break;
  }

  MachineInstrBuilder MIB =
      BuildMI(*I.getParent(), I, I.getDebugLoc(), TII.get(opcode), DstReg);

  if (!foldLoadStoreOperands(MIB, MRI, AddrDef)) {
    // Any other already-computed address (e.g. a materialized global
    // address) - just use the register directly with offset 0
    MIB.addReg(AddrReg).addImm(0);
  }

  MachineInstr *NewLd = MIB;
  constrainSelectedInstRegOperands(*NewLd, TII, TRI, RBI);
  I.eraseFromParent();
  return true;
}

static bool selectStore(MachineInstr &I, const TargetInstrInfo &TII,
                            const TargetRegisterInfo &TRI,
                            const RV64RegisterBankInfo &RBI) {
  Register AddrReg = I.getOperand(1).getReg();
  Register SrcReg = I.getOperand(0).getReg();
  MachineRegisterInfo &MRI = I.getParent()->getParent()->getRegInfo();

  MachineInstr *AddrDef = MRI.getVRegDef(AddrReg);

  int opcode;

  switch (MRI.getType(SrcReg).getSizeInBits()) {
    default:
      llvm_unreachable("unexpected bit size");
    case 8:
      opcode = RV::SB;
      break;
    case 16:
      opcode = RV::SH;
      break;
    case 32:
      opcode = RV::SW;
      break;
    case 64:
      opcode = RV::SD;
      break;
  }

  MachineInstrBuilder MIB =
      BuildMI(*I.getParent(), I, I.getDebugLoc(), TII.get(opcode));

  if (!foldLoadStoreOperands(MIB, MRI, AddrDef)) {
    // Any other already-computed address (e.g. a materialized global
    // address) - just use the register directly with offset 0
    MIB.addReg(AddrReg).addImm(0);
  }

  MIB.addReg(SrcReg);

  MachineInstr *NewSd = MIB;
  constrainSelectedInstRegOperands(*NewSd, TII, TRI, RBI);
  I.eraseFromParent();
  return true;
}

static bool selectFrameIndex(MachineInstr &I, const TargetInstrInfo &TII,
                            const TargetRegisterInfo &TRI,
                            const RV64RegisterBankInfo &RBI) {
  Register DstReg = I.getOperand(0).getReg();
  int FI = I.getOperand(1).getIndex();

  MachineInstr *NewAddi =
      BuildMI(*I.getParent(), I, I.getDebugLoc(), TII.get(RV::ADDI), DstReg)
          .addFrameIndex(FI)
          .addImm(0);

  constrainSelectedInstRegOperands(*NewAddi, TII, TRI, RBI);
  I.eraseFromParent();
  return true;
}


static bool selectPtrMask(MachineInstr &I, const TargetInstrInfo &TII,
                          const TargetRegisterInfo &TRI,
                          const RV64RegisterBankInfo &RBI) {
  Register DstReg = I.getOperand(0).getReg();
  Register PtrReg = I.getOperand(1).getReg();
  Register MaskReg = I.getOperand(2).getReg();

  MachineInstr *NewAnd =
      BuildMI(*I.getParent(), I, I.getDebugLoc(), TII.get(RV::AND), DstReg)
          .addReg(PtrReg)
          .addReg(MaskReg);

  constrainSelectedInstRegOperands(*NewAnd, TII, TRI, RBI);
  I.eraseFromParent();
  return true;
}

static bool selectGlobalValue(MachineInstr &I, const TargetInstrInfo &TII,
                               const TargetRegisterInfo &TRI,
                               const RV64RegisterBankInfo &RBI) {

  Register DstReg = I.getOperand(0).getReg();
  const GlobalValue *GV = I.getOperand(1).getGlobal();
  int64_t Offset = I.getOperand(1).getOffset();

  MachineBasicBlock &MBB = *I.getParent();
  MachineFunction &MF = *MBB.getParent();
  MachineRegisterInfo &MRI = MF.getRegInfo();
  DebugLoc DL = I.getDebugLoc();
  Register HiReg = MRI.createVirtualRegister(&RV::GeneralPurposeRegistersRegClass);

  if (MF.getTarget().isPositionIndependent()) {
    // PC-relative addressing
    MCSymbol *Label = MF.getContext().createTempSymbol();
    MachineInstr *Auipc =
        BuildMI(MBB, I, DL, TII.get(RV::AUIPC), HiReg)
            .addGlobalAddress(GV, Offset, RVII::TOF_PCREL_HI);
    Auipc->setPreInstrSymbol(MF, Label);

    MachineInstr *Addi =
        BuildMI(MBB, I, DL, TII.get(RV::ADDI), DstReg)
            .addReg(HiReg)
            .addSym(Label, RVII::TOF_PCREL_LO);

    constrainSelectedInstRegOperands(*Auipc, TII, TRI, RBI);
    constrainSelectedInstRegOperands(*Addi, TII, TRI, RBI);
  } else {
    // Absolute addressing
    MachineInstr *Lui =
        BuildMI(MBB, I, DL, TII.get(RV::LUI), HiReg)
            .addGlobalAddress(GV, Offset, RVII::TOF_HI);

    MachineInstr *Addi =
        BuildMI(MBB, I, DL, TII.get(RV::ADDI), DstReg)
            .addReg(HiReg)
            .addGlobalAddress(GV, Offset, RVII::TOF_LO);

    constrainSelectedInstRegOperands(*Lui, TII, TRI, RBI);
    constrainSelectedInstRegOperands(*Addi, TII, TRI, RBI);
  }

  I.eraseFromParent();
  return true;
}

static bool selectJumpTable(MachineInstr &I, const TargetInstrInfo &TII,
                             const TargetRegisterInfo &TRI,
                             const RV64RegisterBankInfo &RBI) {
  MachineBasicBlock &MBB = *I.getParent();
  MachineFunction &MF = *MBB.getParent();
  MachineRegisterInfo &MRI = MF.getRegInfo();
  DebugLoc DL = I.getDebugLoc();
  Register DstReg = I.getOperand(0).getReg();

  Register HiReg = MRI.createVirtualRegister(&RV::GeneralPurposeRegistersRegClass);
  MCSymbol *Label = MF.getContext().createTempSymbol();
  MachineInstr *Auipc =
      BuildMI(MBB, I, DL, TII.get(RV::AUIPC), HiReg)
          .addJumpTableIndex(static_cast<unsigned>(I.getOperand(1).getIndex()), RVII::TOF_PCREL_HI);
  Auipc->setPreInstrSymbol(MF, Label);

  MachineInstr *Addi =
      BuildMI(MBB, I, DL, TII.get(RV::ADDI), DstReg)
          .addReg(HiReg)
          .addSym(Label, RVII::TOF_PCREL_LO);

  constrainSelectedInstRegOperands(*Auipc, TII, TRI, RBI);
  constrainSelectedInstRegOperands(*Addi, TII, TRI, RBI);

  I.eraseFromParent();
  return true;
}

static bool selectBrJT(MachineInstr &I, const TargetInstrInfo &TII,
                        const TargetRegisterInfo &TRI,
                        const RV64RegisterBankInfo &RBI) {

  MachineBasicBlock &MBB = *I.getParent();
  MachineFunction &MF = *MBB.getParent();
  MachineRegisterInfo &MRI = MF.getRegInfo();
  DebugLoc DL = I.getDebugLoc();

  const MachineJumpTableInfo *MJTI = MF.getJumpTableInfo();
  MachineJumpTableInfo::JTEntryKind EK = MJTI->getEntryKind();
  uint64_t JumpTableEntrySize = MJTI->getEntrySize(MF.getDataLayout());

  Register ShiftedIdxReg = MRI.createVirtualRegister(&RV::GeneralPurposeRegistersRegClass);
  MachineInstr *Slli =
      BuildMI(MBB, I, DL, TII.get(RV::SLLI), ShiftedIdxReg)
          .addReg(I.getOperand(2).getReg())
          .addImm(Log2_32(JumpTableEntrySize));

  Register AddiDstReg = MRI.createVirtualRegister(&RV::GeneralPurposeRegistersRegClass);
  MachineInstr *Add =
      BuildMI(MBB, I, DL, TII.get(RV::ADD), AddiDstReg)
          .addReg(I.getOperand(0).getReg())
          .addReg(ShiftedIdxReg);

  assert((JumpTableEntrySize == 8 || JumpTableEntrySize == 4) && "Unexpected jump table entry size");
  int LoadOpcode = JumpTableEntrySize == 8 ? RV::LD : RV::LW;
  Register OffsetReg = MRI.createVirtualRegister(&RV::GeneralPurposeRegistersRegClass);
  MachineInstr *Lw =
      BuildMI(MBB, I, DL, TII.get(LoadOpcode), OffsetReg)
          .addReg(AddiDstReg)
          .addImm(0);

  constrainSelectedInstRegOperands(*Slli, TII, TRI, RBI);
  constrainSelectedInstRegOperands(*Add, TII, TRI, RBI);
  constrainSelectedInstRegOperands(*Lw, TII, TRI, RBI);

  if (EK == MachineJumpTableInfo::EK_LabelDifference32 || EK == MachineJumpTableInfo::EK_LabelDifference64) {
    // Case-to-table difference
    MachineInstr *Add2 =
        BuildMI(MBB, I, DL, TII.get(RV::ADD), OffsetReg)
            .addReg(OffsetReg)
            .addReg(I.getOperand(0).getReg());

    constrainSelectedInstRegOperands(*Add2, TII, TRI, RBI);
  } else if (EK != MachineJumpTableInfo::EK_BlockAddress) {
    llvm_unreachable("unhandled jump table entry kind");
    return false;
  }

  MachineInstr *Jalr =
    BuildMI(MBB, I, DL, TII.get(RV::PseudoBRIND))
        .addReg(OffsetReg);

  constrainSelectedInstRegOperands(*Jalr, TII, TRI, RBI);
  I.eraseFromParent();
  return true;
}

#define GET_GLOBALISEL_PREDICATE_BITSET
#include "RV64GenGlobalISel.inc"
#undef GET_GLOBALISEL_PREDICATE_BITSET

class RV64InstructionSelector : public InstructionSelector {
public:
  RV64InstructionSelector(const RV64TargetMachine &TM, const RV64Subtarget &STI,
                         const RV64RegisterBankInfo &RBI);

  bool select(MachineInstr &I) override;
  static const char *getName() { return DEBUG_TYPE; }

private:
  /// tblgen generated 'select' implementation that is used as the initial
  /// selector for the patterns that do not require complex C++.
  bool selectImpl(MachineInstr &I, CodeGenCoverage &CoverageInfo) const;

  const RV64InstrInfo &TII;
  const RV64RegisterInfo &TRI;
  const RV64RegisterBankInfo &RBI;

#define GET_GLOBALISEL_PREDICATES_DECL
#include "RV64GenGlobalISel.inc"
#undef GET_GLOBALISEL_PREDICATES_DECL

#define GET_GLOBALISEL_TEMPORARIES_DECL
#include "RV64GenGlobalISel.inc"
#undef GET_GLOBALISEL_TEMPORARIES_DECL
};

} // namespace

#define GET_GLOBALISEL_IMPL
#include "RV64GenGlobalISel.inc"
#undef GET_GLOBALISEL_IMPL

RV64InstructionSelector::RV64InstructionSelector(const RV64TargetMachine &TM,
                                               const RV64Subtarget &STI,
                                               const RV64RegisterBankInfo &RBI)
    : TII(*STI.getInstrInfo()), TRI(*STI.getRegisterInfo()), RBI(RBI),
#define GET_GLOBALISEL_PREDICATES_INIT
#include "RV64GenGlobalISel.inc"
#undef GET_GLOBALISEL_PREDICATES_INIT
#define GET_GLOBALISEL_TEMPORARIES_INIT
#include "RV64GenGlobalISel.inc"
#undef GET_GLOBALISEL_TEMPORARIES_INIT
{
}

bool RV64InstructionSelector::select(MachineInstr &I) {
  if (!isPreISelGenericOpcode(I.getOpcode())) {
    // Special handling for COPY as it's not a pre-ISel opcode, but its operands
    // should still be constrained to a specific register class.
    if (I.isCopy()) {
      MachineFunction &MF = *I.getParent()->getParent();
      MachineRegisterInfo &MRI = MF.getRegInfo();
      return selectCopy(I, TII, MRI, TRI, RBI);
    }
    return true;
  }

  if (I.getOpcode() == TargetOpcode::G_JUMP_TABLE) {
    return selectJumpTable(I, TII, TRI, RBI);
  }

  if (I.getOpcode() == TargetOpcode::G_BRJT) {
    return selectBrJT(I, TII, TRI, RBI);
  }

  if (I.getOpcode() == TargetOpcode::G_CONSTANT) {
    return selectConstant(I, TII, TRI, RBI);
  }

  if (I.getOpcode() == TargetOpcode::G_LOAD) {
    return selectLoad(I, TII, TRI, RBI);
  }

  if (I.getOpcode() == TargetOpcode::G_STORE) {
    return selectStore(I, TII, TRI, RBI);
  }

  if (I.getOpcode() == TargetOpcode::G_FRAME_INDEX) {
    return selectFrameIndex(I, TII, TRI, RBI);
  }

  if (I.getOpcode() == TargetOpcode::G_GLOBAL_VALUE) {
    return selectGlobalValue(I, TII, TRI, RBI);
  }

  if (I.getOpcode() == TargetOpcode::G_TRUNC || I.getOpcode() == TargetOpcode::G_ANYEXT ||
      I.getOpcode() == TargetOpcode::G_PTRTOINT || I.getOpcode() == TargetOpcode::G_INTTOPTR) {
    MachineFunction &MF = *I.getParent()->getParent();
    MachineRegisterInfo &MRI = MF.getRegInfo();
    return selectCopy(I, TII, MRI, TRI, RBI);
  }

  if (I.getOpcode() == TargetOpcode::G_ZEXT || I.getOpcode() == TargetOpcode::G_SEXT) {
    return selectSZExt(I, TII, I.getParent()->getParent()->getRegInfo(), TRI, RBI);
  }

  if (I.getOpcode() == TargetOpcode::G_BRCOND) {
    return selectBrCond(I, TII, I.getParent()->getParent()->getRegInfo(), TRI, RBI);
  }

  if (I.getOpcode() == TargetOpcode::G_PHI) {
    return selectPhi(I, TII, I.getParent()->getParent()->getRegInfo(), TRI, RBI);
  }

  if (I.getOpcode() == TargetOpcode::G_PTRMASK) {
    return selectPtrMask(I, TII, TRI, RBI);
  }

  // Default instruction selection via LLVM's builtin selection logic (based on selection rules built from tablegen)
  if (selectImpl(I, *CoverageInfo)) {
    return true;
  }

  return false;
}

namespace llvm {
InstructionSelector *
createRV64InstructionSelector(const RV64TargetMachine &TM,
                             const RV64Subtarget &Subtarget,
                             const RV64RegisterBankInfo &RBI) {
  return new RV64InstructionSelector(TM, Subtarget, RBI);
}
} // namespace llvm
