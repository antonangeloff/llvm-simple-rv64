//===-- RV64AsmPrinter.h ----------------------------------------*- C++ -*--===//

#ifndef LLVM_LIB_TARGET_RV64_RV64ASMPRINTER_H
#define LLVM_LIB_TARGET_RV64_RV64ASMPRINTER_H

#include "RV64TargetMachine.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionAnalysisManager.h"
#include "llvm/IR/Analysis.h"
#include "llvm/IR/PassManager.h"

namespace llvm {

class RV64AsmPrinter : public AsmPrinter {
public:
  explicit RV64AsmPrinter(TargetMachine &TM,
                         std::unique_ptr<MCStreamer> Streamer);
  ~RV64AsmPrinter() override;

  StringRef getPassName() const override { return "RV64 Assembly Printer"; }
  bool doInitialization(Module &M) override;
  bool doFinalization(Module &M) override;
  void printOperand(const MachineInstr *MI, int OpNum, raw_ostream &O);
  bool PrintAsmOperand(const MachineInstr *MI, unsigned OpNo,
                       const char *ExtraCode, raw_ostream &O) override;
  bool PrintAsmMemoryOperand(const MachineInstr *MI, unsigned OpNum,
                             const char *ExtraCode, raw_ostream &O) override;

  void emitInstruction(const MachineInstr *MI) override;
  bool lowerPseudoInstExpansion(const MachineInstr *MI, MCInst &Inst);
  bool lowerOperand(const MachineOperand &MO, MCOperand &MCOp) const;

  static char ID;
};

class RV64AsmPrinterBeginPass
    : public RequiredPassInfoMixin<RV64AsmPrinterBeginPass> {
public:
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &MAM);
};

class RV64AsmPrinterPass : public RequiredPassInfoMixin<RV64AsmPrinterPass> {
public:
  PreservedAnalyses run(MachineFunction &MF,
                        MachineFunctionAnalysisManager &MFAM);
};

class RV64AsmPrinterEndPass
    : public RequiredPassInfoMixin<RV64AsmPrinterEndPass> {
public:
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &MAM);
};

} // namespace llvm

#endif /* LLVM_LIB_TARGET_RV64_RV64ASMPRINTER_H */
