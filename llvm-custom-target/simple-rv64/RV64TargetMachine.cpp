//===-- RV64TargetMachine.cpp - Define TargetMachine for RV64 ---------------===//
//
// Implements the info about RV64 target spec.
//
//===----------------------------------------------------------------------===//

#include "RV64TargetMachine.h"
#include "RV64.h"
#include "RV64MachineFunctionInfo.h"
// #include "RV64TargetLoweringObjectFile.h" // todo: create once jump tables exist
#include "MCTargetDesc/RV64MCAsmInfo.h"
#include "TargetInfo/RV64TargetInfo.h"
#include "llvm/CodeGen/GlobalISel/IRTranslator.h"
#include "llvm/CodeGen/GlobalISel/InstructionSelect.h"
#include "llvm/CodeGen/GlobalISel/Legalizer.h"
#include "llvm/CodeGen/GlobalISel/RegBankSelect.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/TargetLoweringObjectFileImpl.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/IR/PassManager.h"
#include "llvm/InitializePasses.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Target/TargetOptions.h"
#include "llvm/Transforms/Scalar.h"
#include <optional>
using namespace llvm;

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializeRV64Target() {
  // Register the target.
  RegisterTargetMachine<RV64TargetMachine> Z(getTheRV64Target());

  PassRegistry &PR = *PassRegistry::getPassRegistry();
  initializeGlobalISel(PR);
  initializeRV64AsmPrinterPass(PR);
  initializeRV64PreLegalizerCombinerLegacyPass(PR);
  // initializeRV64CheckAndAdjustIRLegacyPass(PR);
  // initializeRV64MIPeepholeLegacyPass(PR);
  // initializeRV64MIExpandStackArgPseudosLegacyPass(PR);
  // initializeRV64MIPreEmitPeepholeLegacyPass(PR);
  // initializeRV64DAGToDAGISelLegacyPass(PR);
  // initializeRV64MISimplifyPatchableLegacyPass(PR);
  // initializeRV64MIPreEmitCheckingLegacyPass(PR);
}

static Reloc::Model getEffectiveRelocModel(std::optional<Reloc::Model> RM) {
  return RM.value_or(Reloc::PIC_);
}

RV64TargetMachine::RV64TargetMachine(const Target &T, const Triple &TT,
                                   StringRef CPU, StringRef FS,
                                   const TargetOptions &Options,
                                   std::optional<Reloc::Model> RM,
                                   std::optional<CodeModel::Model> CM,
                                   CodeGenOptLevel OL, bool JIT)
    : CodeGenTargetMachineImpl(T, TT.computeDataLayout(), TT, CPU, FS, Options,
                               getEffectiveRelocModel(RM),
                               getEffectiveCodeModel(CM, CodeModel::Small), OL),
      TLOF(std::make_unique<TargetLoweringObjectFileELF>()),
      Subtarget(CPU, CPU, FS, *this) {

  setGlobalISel(true);
  initAsmInfo();
}

namespace {
// RV64 Code Generator Pass Configuration Options.
class RV64PassConfig : public TargetPassConfig {
public:
  RV64PassConfig(RV64TargetMachine &TM, PassManagerBase &PM)
      : TargetPassConfig(TM, PM) {}

  RV64TargetMachine &getRV64TargetMachine() const {
    return getTM<RV64TargetMachine>();
  }

  void addIRPasses() override;
  bool addIRTranslator() override;
  bool addLegalizeMachineIR() override;
  bool addRegBankSelect() override;
  bool addGlobalInstructionSelect() override;
  void addPreLegalizeMachineIR() override;
};
}

TargetPassConfig *RV64TargetMachine::createPassConfig(PassManagerBase &PM) {
  return new RV64PassConfig(*this, PM);
}

void RV64PassConfig::addIRPasses() {
  addPass(createAtomicExpandLegacyPass());
  TargetPassConfig::addIRPasses();
}

bool RV64PassConfig::addIRTranslator() {
  addPass(new IRTranslatorLegacy());
  return false;
}

bool RV64PassConfig::addLegalizeMachineIR() {
  addPass(new LegalizerLegacy());
  return false;
}

bool RV64PassConfig::addRegBankSelect() {
  addPass(new RegBankSelectLegacy());
  return false;
}

bool RV64PassConfig::addGlobalInstructionSelect() {
  addPass(new InstructionSelectLegacy(getOptLevel()));
  return false;
}

void RV64PassConfig::addPreLegalizeMachineIR() {
  addPass(createRV64PreLegalizerCombiner());
}

MachineFunctionInfo *RV64TargetMachine::createMachineFunctionInfo(BumpPtrAllocator &Allocator, const Function &F,
                            const TargetSubtargetInfo *STI) const
{
  return RV64MachineFunctionInfo::create<RV64MachineFunctionInfo>(Allocator, F, STI);
}
