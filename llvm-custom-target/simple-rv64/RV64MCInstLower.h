//===-- RV64MCInstLower.h - Lower MachineInstr to MCInst ---------*- C++ -*-===//

#ifndef LLVM_LIB_TARGET_RV64_RV64MCINSTLOWER_H
#define LLVM_LIB_TARGET_RV64_RV64MCINSTLOWER_H

#include "llvm/Support/Compiler.h"

namespace llvm {
class RV64AsmPrinter;
class MCContext;
class MCInst;
class MCOperand;
class MCSymbol;
class MachineInstr;
class MachineOperand;

// RV64MCInstLower - This class is used to lower an MachineInstr into an MCInst.
class LLVM_LIBRARY_VISIBILITY RV64MCInstLower {
  MCContext &Ctx;

  RV64AsmPrinter &Printer;

public:
  RV64MCInstLower(MCContext &ctx, RV64AsmPrinter &printer)
      : Ctx(ctx), Printer(printer) {}
  void Lower(const MachineInstr *MI, MCInst &OutMI) const;

  MCOperand LowerSymbolOperand(const MachineOperand &MO, MCSymbol *Sym) const;

  MCSymbol *GetGlobalAddressSymbol(const MachineOperand &MO) const;
  MCSymbol *GetExternalSymbolSymbol(const MachineOperand &MO) const;
};
}

#endif
