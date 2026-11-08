//===- RV64LegalizerInfo.h ----------------------------------------*- C++ -*-==//
/// \file
/// This file implements the targeting of the Machinelegalizer class for RV64
//===----------------------------------------------------------------------===//

#include "RV64LegalizerInfo.h"
#include "RV64MachineFunctionInfo.h"
#include "RV64Subtarget.h"
#include "llvm/CodeGen/GlobalISel/LegalizerHelper.h"
#include "llvm/CodeGen/GlobalISel/MachineIRBuilder.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/RuntimeLibcalls.h"

#define DEBUG_TYPE "RV64-legalinfo"

using namespace llvm;
using namespace LegalizeActions;

RV64LegalizerInfo::RV64LegalizerInfo(const RV64Subtarget &ST) {
  using namespace TargetOpcode;

  const LLT S64 = LLT::scalar(64);
  const LLT S32 = LLT::scalar(32);
  const LLT S16 = LLT::scalar(16);
  const LLT S8 = LLT::scalar(8);
  const LLT S1 = LLT::scalar(1);
  const LLT P0 = LLT::pointer(0, 64);

  getActionDefinitionsBuilder(G_CONSTANT)
        .legalFor({S32, S64, P0})
        .clampScalar(0, S32, S64)
        // .legalFor({S64})
        // .clampScalar(0, S64, S64)
        .widenScalarToNextPow2(0);

  getActionDefinitionsBuilder(G_PTRTOINT)
        .legalFor({{S64, P0}, {S32, P0}});

  getActionDefinitionsBuilder(G_INTTOPTR)
        .legalFor({{P0, S64}});

  getActionDefinitionsBuilder(G_TRUNC)
        .legalIf([](const LegalityQuery &Query) {
          return Query.Types[0].getSizeInBits() < Query.Types[1].getSizeInBits();
        });

  getActionDefinitionsBuilder({G_ZEXT, G_SEXT, G_ANYEXT})
        .legalIf([](const LegalityQuery &Query) {
          return Query.Types[0].getSizeInBits() > Query.Types[1].getSizeInBits();
        });

  getActionDefinitionsBuilder({G_LOAD, G_STORE})
        .legalForTypesWithMemDesc({{S64, P0, S64, 8},
                                    {S32, P0, S32, 8},
                                    {S16, P0, S16, 8},
                                    {S8, P0, S8, 8},
                                    {S1, P0, S1, 8},
                                    {P0, P0, P0, 8}})
        .widenScalarToNextPow2(0, /*MinSize=*/8);

  getActionDefinitionsBuilder({G_FRAME_INDEX, G_GLOBAL_VALUE, G_JUMP_TABLE})
        .legalFor({P0});

  getActionDefinitionsBuilder(G_BRJT)
        .legalFor({{P0, S64}});

  getActionDefinitionsBuilder(G_BR)
        .alwaysLegal();

  getActionDefinitionsBuilder(G_ICMP)
        .legalFor({{S32, S32}, {S32, S64}, {S32, P0}})
        .clampScalar(0, S32, S32)
        .clampScalar(1, S32, S64)
        .widenScalarToNextPow2(1);

  getActionDefinitionsBuilder({G_SCMP, G_UCMP})
        .lower();

  getActionDefinitionsBuilder(G_BRCOND)
        .legalFor({S32})
        .clampScalar(0, S32, S32);

  getActionDefinitionsBuilder({G_ADD, G_SUB, G_AND, G_OR, G_XOR, G_SHL, G_LSHR, G_ASHR})
        .legalFor({S32, S64})
        .clampScalar(0, S32, S64)
        .widenScalarToNextPow2(0);

  getActionDefinitionsBuilder(G_PHI)
        .legalFor({S32, S64, P0});

  getActionDefinitionsBuilder({G_PTR_ADD})
        .legalFor({P0, S64});

  getActionDefinitionsBuilder({G_PTRMASK})
        .legalFor({P0, S64});

  getActionDefinitionsBuilder({G_SELECT})
        .lower();

  getActionDefinitionsBuilder({G_CTLZ, G_CTLZ_ZERO_POISON, G_CTPOP})
        .lower();

  getActionDefinitionsBuilder({G_MEMCPY, G_MEMSET})
        .libcall();

  getActionDefinitionsBuilder(G_VASTART)
        .customFor({P0});

  getActionDefinitionsBuilder(G_VAARG)
        .clampScalar(0, S64, S64)
        .lowerForCartesianProduct({S64, P0}, {P0});

  const bool softFloat = !ST.hasF() && !ST.hasD();
  if (softFloat) {
      getActionDefinitionsBuilder({G_FADD, G_FSUB, G_FMUL, G_FDIV})
            .libcallFor({S32, S64});

      getActionDefinitionsBuilder(G_FNEG)
            .lowerFor({S32, S64});

      getActionDefinitionsBuilder(G_FCONSTANT)
            .customFor({S32, S64});

      getActionDefinitionsBuilder(G_FCMP)
            .customForCartesianProduct({S32}, {S32, S64})
            .clampScalar(0, S32, S32);

      getActionDefinitionsBuilder(G_FPEXT)
            .libcallFor({{S64, S32}});

      getActionDefinitionsBuilder(G_FPTRUNC)
            .libcallFor({{S32, S64}});

      getActionDefinitionsBuilder({G_FPTOSI, G_FPTOUI})
            .libcallForCartesianProduct({S32}, {S32, S64});

      getActionDefinitionsBuilder({G_SITOFP, G_UITOFP})
            .libcallForCartesianProduct({S32, S64}, {S32});
  } else {
    llvm_unreachable("Hardware F/D extension support not yet implemented");
  }

  if (ST.hasM()) {
      getActionDefinitionsBuilder({G_MUL, G_SDIV, G_SREM, G_UDIV, G_UREM})
            .legalFor({S32, S64})
            .clampScalar(0, S32, S64)
            .widenScalarToNextPow2(0);
  } else {
      // Emulate in software
      getActionDefinitionsBuilder({G_MUL, G_SDIV, G_SREM, G_UDIV, G_UREM})
            .libcall();
  }

}

bool RV64LegalizerInfo::legalizeCustom(LegalizerHelper &Helper,
                                       MachineInstr &MI,
                                       LostDebugLocObserver &LocObserver) const {
  switch (MI.getOpcode()) {
  default:
    return false;
  case TargetOpcode::G_VASTART:
    return legalizeVAStart(MI, Helper.MIRBuilder);
  case TargetOpcode::G_FCONSTANT:
    return legalizeSoftFConstant(MI, Helper.MIRBuilder);
  case TargetOpcode::G_FCMP:
    return legalizeSoftFCmp(MI, Helper, LocObserver);
  }
}

bool RV64LegalizerInfo::legalizeVAStart(MachineInstr &MI,
                                        MachineIRBuilder &MIRBuilder) const {
  MachineFunction &MF = *MI.getParent()->getParent();
  RV64MachineFunctionInfo *FuncInfo = MF.getInfo<RV64MachineFunctionInfo>();
  LLT AddrTy = MIRBuilder.getMRI()->getType(MI.getOperand(0).getReg());
  MachineInstrBuilder FINAddr = MIRBuilder.buildFrameIndex(AddrTy, FuncInfo->getVarArgsFrameIndex());

  MIRBuilder.buildStore(FINAddr, MI.getOperand(0).getReg(), *MI.memoperands()[0]);
  MI.eraseFromParent();
  return true;
}

bool RV64LegalizerInfo::legalizeSoftFConstant(MachineInstr &MI,
                                          MachineIRBuilder &MIRBuilder) const {
  LLVMContext &Ctx = MIRBuilder.getMF().getFunction().getContext();
  APInt AsInteger = MI.getOperand(1).getFPImm()->getValueAPF().bitcastToAPInt();
  MIRBuilder.buildConstant(MI.getOperand(0), *ConstantInt::get(Ctx, AsInteger));
  MI.eraseFromParent();
  return true;
}

bool RV64LegalizerInfo::legalizeSoftFCmp(MachineInstr &MI, LegalizerHelper &Helper,
                                     LostDebugLocObserver &LocObserver) const {
  MachineIRBuilder &MIRBuilder = Helper.MIRBuilder;
  MachineRegisterInfo &MRI = *MIRBuilder.getMRI();
  LLVMContext &Ctx = MIRBuilder.getMF().getFunction().getContext();

  Register Dst = MI.getOperand(0).getReg();
  auto Predicate = static_cast<CmpInst::Predicate>(MI.getOperand(1).getPredicate());
  Register LHS = MI.getOperand(2).getReg();
  Register RHS = MI.getOperand(3).getReg();
  unsigned OpSize = MRI.getType(LHS).getSizeInBits();

  assert(MRI.getType(LHS) == MRI.getType(RHS) && "Mismatched operands for G_FCMP");
  assert((OpSize == 32 || OpSize == 64) && "Unsupported float size for G_FCMP");

  Type *ArgTy = OpSize == 32 ? Type::getFloatTy(Ctx) : Type::getDoubleTy(Ctx);
  Type *RetTy = Type::getInt32Ty(Ctx);
  RTLIB::Libcall LC;
  CmpInst::Predicate CmpAgainstZero;

  switch (Predicate) {
  case CmpInst::FCMP_OEQ:
    LC = OpSize == 32 ? RTLIB::FCMP3_PRED_OEQ_F32 : RTLIB::FCMP3_PRED_OEQ_F64;
    CmpAgainstZero = CmpInst::ICMP_EQ;
    break;
  case CmpInst::FCMP_UNE:
    LC = OpSize == 32 ? RTLIB::FCMP3_PRED_UNE_F32 : RTLIB::FCMP3_PRED_UNE_F64;
    CmpAgainstZero = CmpInst::ICMP_NE;
    break;
  case CmpInst::FCMP_OLT:
    LC = OpSize == 32 ? RTLIB::FCMP3_PRED_OLT_F32 : RTLIB::FCMP3_PRED_OLT_F64;
    CmpAgainstZero = CmpInst::ICMP_SLT;
    break;
  case CmpInst::FCMP_OLE:
    LC = OpSize == 32 ? RTLIB::FCMP3_PRED_OLE_F32 : RTLIB::FCMP3_PRED_OLE_F64;
    CmpAgainstZero = CmpInst::ICMP_SLE;
    break;
  case CmpInst::FCMP_OGT:
    LC = OpSize == 32 ? RTLIB::FCMP3_PRED_OGT_F32 : RTLIB::FCMP3_PRED_OGT_F64;
    CmpAgainstZero = CmpInst::ICMP_SGT;
    break;
  case CmpInst::FCMP_OGE:
    LC = OpSize == 32 ? RTLIB::FCMP3_PRED_OGE_F32 : RTLIB::FCMP3_PRED_OGE_F64;
    CmpAgainstZero = CmpInst::ICMP_SGE;
    break;
  default:
    return false;
  }

  Register LibcallResult = MRI.createGenericVirtualRegister(LLT::scalar(32));
  if (Helper.createLibcall(LC, {LibcallResult, RetTy, 0},
                           {{LHS, ArgTy, 0}, {RHS, ArgTy, 0}}, LocObserver,
                           &MI) != LegalizerHelper::Legalized) {
    return false;
  }

  MachineInstrBuilder Zero = MIRBuilder.buildConstant(LLT::scalar(32), 0);
  MIRBuilder.buildICmp(CmpAgainstZero, Dst, LibcallResult, Zero);
  MI.eraseFromParent();
  return true;
}
