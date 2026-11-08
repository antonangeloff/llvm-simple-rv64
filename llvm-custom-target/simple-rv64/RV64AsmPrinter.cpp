//===-- RV64AsmPrinter.cpp - RV64 LLVM assembly writer ----------------------===//
//
// This file contains a printer that converts from our internal representation
// of machine-dependent LLVM code to the RV64 assembly language.
//
//===----------------------------------------------------------------------===//

#include "RV64AsmPrinter.h"
#include "RV64.h"
#include "RV64InstrInfo.h"
#include "RV64MCInstLower.h"
#include "MCTargetDesc/RV64InstPrinter.h"
#include "TargetInfo/RV64TargetInfo.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/AsmPrinterAnalysis.h"
#include "llvm/CodeGen/MachineConstantPool.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionAnalysisManager.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineJumpTableInfo.h"
#include "llvm/CodeGen/MachineModuleInfo.h"
#include "llvm/CodeGen/MachinePassManager.h"
#include "llvm/CodeGen/TargetLowering.h"
#include "llvm/IR/Analysis.h"
#include "llvm/IR/DiagnosticInfo.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/PassManager.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCSectionELF.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/MCSymbolELF.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetLoweringObjectFile.h"
using namespace llvm;

#define DEBUG_TYPE "asm-printer"

RV64AsmPrinter::RV64AsmPrinter(TargetMachine &TM,
                             std::unique_ptr<MCStreamer> Streamer)
    : AsmPrinter(TM, std::move(Streamer), ID) {}

RV64AsmPrinter::~RV64AsmPrinter() = default;

bool RV64AsmPrinter::doInitialization(Module &M) {
  // todo
  return AsmPrinter::doInitialization(M);
}

bool RV64AsmPrinter::doFinalization(Module &M) {
  // todo: check if we need any finalization
  return AsmPrinter::doFinalization(M);
}

void RV64AsmPrinter::printOperand(const MachineInstr *MI, int OpNum,
                                 raw_ostream &O) {
  const MachineOperand &MO = MI->getOperand(OpNum);

  switch (MO.getType()) {
  case MachineOperand::MO_Register:
    O << RV64InstPrinter::getRegisterName(MO.getReg());
    break;

  case MachineOperand::MO_Immediate:
    O << MO.getImm();
    break;

  case MachineOperand::MO_MachineBasicBlock:
    O << *MO.getMBB()->getSymbol();
    break;

  case MachineOperand::MO_GlobalAddress:
    O << *getSymbol(MO.getGlobal());
    break;

  case MachineOperand::MO_BlockAddress: {
    MCSymbol *BA = GetBlockAddressSymbol(MO.getBlockAddress());
    O << BA->getName();
    break;
  }

  case MachineOperand::MO_ExternalSymbol:
    O << *GetExternalSymbolSymbol(MO.getSymbolName());
    break;

  case MachineOperand::MO_JumpTableIndex:
  case MachineOperand::MO_ConstantPoolIndex:
  default:
    llvm_unreachable("<unknown operand type>");
  }
}

bool RV64AsmPrinter::PrintAsmOperand(const MachineInstr *MI, unsigned OpNo,
                                    const char *ExtraCode, raw_ostream &O) {
  if (ExtraCode && ExtraCode[0])
    return AsmPrinter::PrintAsmOperand(MI, OpNo, ExtraCode, O);

  printOperand(MI, OpNo, O);
  return false;
}

bool RV64AsmPrinter::PrintAsmMemoryOperand(const MachineInstr *MI,
                                          unsigned OpNum, const char *ExtraCode,
                                          raw_ostream &O) {
  assert(OpNum + 1 < MI->getNumOperands() && "Insufficient operands");
  const MachineOperand &BaseMO = MI->getOperand(OpNum);
  const MachineOperand &OffsetMO = MI->getOperand(OpNum + 1);
  assert(BaseMO.isReg() && "Unexpected base pointer for inline asm memory operand.");
  assert(OffsetMO.isImm() && "Unexpected offset for inline asm memory operand.");
  int Offset = OffsetMO.getImm();

  if (ExtraCode)
    return true; // Unknown modifier.

  if (Offset < 0)
    O << "(" << RV64InstPrinter::getRegisterName(BaseMO.getReg()) << " - " << -Offset << ")";
  else
    O << "(" << RV64InstPrinter::getRegisterName(BaseMO.getReg()) << " + " << Offset << ")";

  return false;
}

#include "RV64GenMCPseudoLowering.inc"

void RV64AsmPrinter::emitInstruction(const MachineInstr *MI) {
  RV64_MC::verifyInstructionPredicates(MI->getOpcode(), getSubtargetInfo().getFeatureBits());

  if (MCInst OutInst; lowerPseudoInstExpansion(MI, OutInst)) {
    EmitToStreamer(*OutStreamer, OutInst);
    return;
  }

  MCInst TmpInst;
  RV64MCInstLower MCInstLowering(OutContext, *this);
  MCInstLowering.Lower(MI, TmpInst);
  EmitToStreamer(*OutStreamer, TmpInst);
}

bool RV64AsmPrinter::lowerOperand(const MachineOperand &MO, MCOperand &MCO) const {
  switch (MO.getType()) {
  default:
    report_fatal_error("lowerOperand: unsupported operand type");
  case MachineOperand::MO_Register:
    if (MO.isImplicit()) {
      return false;
    }
    MCO = MCOperand::createReg(MO.getReg());
    return true;
  case MachineOperand::MO_Immediate:
    MCO = MCOperand::createImm(MO.getImm());
    return true;
  case MachineOperand::MO_MachineBasicBlock:
    MCO = MCOperand::createExpr(
        MCSymbolRefExpr::create(MO.getMBB()->getSymbol(), OutContext));
    return true;
  case MachineOperand::MO_GlobalAddress: {
    const MCExpr *Expr = MCSymbolRefExpr::create(getSymbol(MO.getGlobal()), OutContext);
    if (MO.getOffset()) {
      Expr = MCBinaryExpr::createAdd(Expr, MCConstantExpr::create(MO.getOffset(), OutContext), OutContext);
    }
    MCO = MCOperand::createExpr(Expr);
    return true;
  }
  case MachineOperand::MO_ExternalSymbol:
    MCO = MCOperand::createExpr(MCSymbolRefExpr::create(GetExternalSymbolSymbol(MO.getSymbolName()), OutContext));
    return true;
  }
}

char RV64AsmPrinter::ID = 0;

INITIALIZE_PASS(RV64AsmPrinter, "RV64-asm-printer", "RV64 Assembly Printer", false,
                false)

// Force static initialization.
extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void
LLVMInitializeRV64AsmPrinter() {
  RegisterAsmPrinter<RV64AsmPrinter> Z(getTheRV64Target());
}

PreservedAnalyses RV64AsmPrinterBeginPass::run(Module &M,
                                              ModuleAnalysisManager &MAM) {
  RV64AsmPrinter &AsmPrinter = static_cast<RV64AsmPrinter &>(
      MAM.getResult<AsmPrinterAnalysis>(M).getPrinter());
  setupModuleAsmPrinter(M, MAM, AsmPrinter);
  AsmPrinter.doInitialization(M);
  return PreservedAnalyses::all();
}

PreservedAnalyses RV64AsmPrinterPass::run(MachineFunction &MF,
                                         MachineFunctionAnalysisManager &MFAM) {
  RV64AsmPrinter &AsmPrinter = static_cast<RV64AsmPrinter &>(
      MFAM.getResult<ModuleAnalysisManagerMachineFunctionProxy>(MF)
          .getCachedResult<AsmPrinterAnalysis>(*MF.getFunction().getParent())
          ->getPrinter());
  setupMachineFunctionAsmPrinter(MFAM, MF, AsmPrinter);
  AsmPrinter.runOnMachineFunction(MF);
  return PreservedAnalyses::all();
}

PreservedAnalyses RV64AsmPrinterEndPass::run(Module &M,
                                            ModuleAnalysisManager &MAM) {
  RV64AsmPrinter &AsmPrinter = static_cast<RV64AsmPrinter &>(
      MAM.getResult<AsmPrinterAnalysis>(M).getPrinter());
  setupModuleAsmPrinter(M, MAM, AsmPrinter);
  AsmPrinter.doFinalization(M);
  return PreservedAnalyses::all();
}