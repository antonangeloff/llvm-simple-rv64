//===-- RV64InstPrinter.cpp - Convert RV64 MCInst to asm syntax -------------===//
//
// This class prints an RV64 MCInst to a .s file.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/RV64InstPrinter.h"
#include "RV64.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/Support/ErrorHandling.h"
using namespace llvm;

#define DEBUG_TYPE "asm-printer"

// Include the auto-generated portion of the assembly writer.
#include "RV64GenAsmWriter.inc"

void RV64InstPrinter::printInst(const MCInst *MI, uint64_t Address,
                               StringRef Annot, const MCSubtargetInfo &STI,
                               raw_ostream &O) {
  printInstruction(MI, Address, STI, O);
  printAnnotation(O, Annot);
}

void RV64InstPrinter::printOperand(const MCInst *MI, unsigned OpNo,
                                  const MCSubtargetInfo &STI, raw_ostream &O) {
  const MCOperand &Op = MI->getOperand(OpNo);
  if (Op.isReg()) {
    O << getRegisterName(Op.getReg());
  } else if (Op.isImm()) {
    O << formatImm((int64_t)Op.getImm());
  } else {
    assert(Op.isExpr() && "Expected an expression");
    MAI.printExpr(O, *Op.getExpr());
  }
}
