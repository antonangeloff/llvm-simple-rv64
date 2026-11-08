//===-- RV64MCAsmInfo.cpp - RV64 asm properties --------------------------===//

#include "RV64MCAsmInfo.h"
#include "RV64BaseInfo.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

static StringRef getRVSpecifierName(uint16_t Spec) {
  switch (Spec) {
  case RVII::TOF_HI:
    return "%hi";
  case RVII::TOF_LO:
    return "%lo";
  case RVII::TOF_PCREL_HI:
    return "%pcrel_hi";
  case RVII::TOF_PCREL_LO:
    return "%pcrel_lo";
  default:
    llvm_unreachable("unknown RV64 specifier");
  }
}

void RV64MCAsmInfo::printSpecifierExpr(raw_ostream &OS,
                                      const MCSpecifierExpr &Expr) const {
  OS << getRVSpecifierName(Expr.getSpecifier()) << '(';
  printExpr(OS, *Expr.getSubExpr());
  OS << ')';
}
