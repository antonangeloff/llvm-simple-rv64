//===-- RV64MCAsmInfo.h - RV64 asm properties -------------------*- C++ -*--====//
//
// This file contains the declaration of the RV64MCAsmInfo class.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RV64_MCTARGETDESC_RV64MCASMINFO_H
#define LLVM_LIB_TARGET_RV64_MCTARGETDESC_RV64MCASMINFO_H

#include "llvm/MC/MCAsmInfoELF.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/TargetParser/Triple.h"

namespace llvm {

class RV64MCAsmInfo : public MCAsmInfoELF {
public:
  explicit RV64MCAsmInfo(const Triple &TT, const MCTargetOptions &Options)
      : MCAsmInfoELF(Options) {
    InternalSymbolPrefix = ".L";
    WeakRefDirective = "\t.weak\t";

    UsesELFSectionDirectiveForBSS = true;
    HasSingleParameterDotFile = true;
    HasDotTypeDotSizeDirective = true;
    HasIdentDirective = false;

    SupportsDebugInformation = true;
    ExceptionsType = ExceptionHandling::DwarfCFI;
    MinInstAlignment = 4;
    CodePointerSize = 8;
  }

  // Prints the %hi/%lo/%pcrel_hi/%pcrel_lo wrapper around a relocated global
  // address or local anchor-label operand (see RVII::TargetOperandFlag in
  // RV64BaseInfo.h).
  void printSpecifierExpr(raw_ostream &OS,
                          const MCSpecifierExpr &Expr) const override;
};
}

#endif
