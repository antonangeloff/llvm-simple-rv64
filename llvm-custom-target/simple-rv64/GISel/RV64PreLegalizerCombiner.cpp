//===-- RV64PreLegalizerCombiner.cpp - combine legalization ----*- C++ -*-===//
//
// This pass does combining of machine instructions at the generic MI level,
// before the legalizer.
//
//===----------------------------------------------------------------------===//

#include "RV64.h"
#include "RV64Subtarget.h"
#include "llvm/CodeGen/GlobalISel/CombinerHelper.h"
#include "llvm/CodeGen/GlobalISel/CSEInfo.h"
#include "llvm/CodeGen/GlobalISel/Combiner.h"
#include "llvm/CodeGen/GlobalISel/CombinerInfo.h"
#include "llvm/CodeGen/GlobalISel/GIMatchTableExecutorImpl.h"
#include "llvm/CodeGen/GlobalISel/GISelChangeObserver.h"
#include "llvm/CodeGen/GlobalISel/GISelValueTracking.h"
#include "llvm/CodeGen/GlobalISel/MIPatternMatch.h"
#include "llvm/CodeGen/MachineDominators.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/TargetPassConfig.h"

#define GET_GICOMBINER_DEPS
#include "RV64GenPreLegalizeGICombiner.inc"
#undef GET_GICOMBINER_DEPS

#define DEBUG_TYPE "RV64-prelegalizer-combiner"

using namespace llvm;
using namespace MIPatternMatch;

namespace {

#define GET_GICOMBINER_TYPES
#include "RV64GenPreLegalizeGICombiner.inc"
#undef GET_GICOMBINER_TYPES

class RV64PreLegalizerCombinerImpl : public Combiner {
protected:
  const CombinerHelper Helper;
  const RV64PreLegalizerCombinerImplRuleConfig &RuleConfig;

public:
  RV64PreLegalizerCombinerImpl(
      MachineFunction &MF, CombinerInfo &CInfo, GISelValueTracking &VT,
      GISelCSEInfo *CSEInfo,
      const RV64PreLegalizerCombinerImplRuleConfig &RuleConfig,
      const RV64Subtarget &STI, MachineDominatorTree *MDT,
      const LegalizerInfo *LI);

  static const char *getName() { return "RV64PreLegalizerCombiner"; }

  bool tryCombineAll(MachineInstr &I) const override;

private:
#define GET_GICOMBINER_CLASS_MEMBERS
#include "RV64GenPreLegalizeGICombiner.inc"
#undef GET_GICOMBINER_CLASS_MEMBERS
};

#define GET_GICOMBINER_IMPL
#include "RV64GenPreLegalizeGICombiner.inc"
#undef GET_GICOMBINER_IMPL

RV64PreLegalizerCombinerImpl::RV64PreLegalizerCombinerImpl(
    MachineFunction &MF, CombinerInfo &CInfo, GISelValueTracking &VT,
    GISelCSEInfo *CSEInfo,
    const RV64PreLegalizerCombinerImplRuleConfig &RuleConfig,
    const RV64Subtarget &STI, MachineDominatorTree *MDT,
    const LegalizerInfo *LI)
    : Combiner(MF, CInfo, &VT, CSEInfo),
      Helper(Observer, B, /*IsPreLegalize*/ true, &VT, MDT, LI),
      RuleConfig(RuleConfig),
#define GET_GICOMBINER_CONSTRUCTOR_INITS
#include "RV64GenPreLegalizeGICombiner.inc"
#undef GET_GICOMBINER_CONSTRUCTOR_INITS
{
}

// Pass boilerplate
// ================

class RV64PreLegalizerCombinerLegacy : public MachineFunctionPass {
public:
  static char ID;

  RV64PreLegalizerCombinerLegacy();

  StringRef getPassName() const override { return "RV64PreLegalizerCombiner"; }

  bool runOnMachineFunction(MachineFunction &MF) override;

  void getAnalysisUsage(AnalysisUsage &AU) const override;
};

} // end anonymous namespace

void RV64PreLegalizerCombinerLegacy::getAnalysisUsage(
    AnalysisUsage &AU) const {
  AU.setPreservesCFG();
  getSelectionDAGFallbackAnalysisUsage(AU);
  AU.addRequired<GISelValueTrackingAnalysisLegacy>();
  AU.addPreserved<GISelValueTrackingAnalysisLegacy>();
  AU.addRequired<MachineDominatorTreeWrapperPass>();
  MachineFunctionPass::getAnalysisUsage(AU);
}

RV64PreLegalizerCombinerLegacy::RV64PreLegalizerCombinerLegacy()
    : MachineFunctionPass(ID) {}

static bool
runPreLegalizerCombiner(MachineFunction &MF, bool ShouldSkip,
                        function_ref<GISelValueTracking *()> GetVT,
                        function_ref<MachineDominatorTree *()> GetMDT) {
  if (MF.getProperties().hasFailedISel())
    return false;

  RV64PreLegalizerCombinerImplRuleConfig RuleConfig;
  if (!RuleConfig.parseCommandLineOption())
    reportFatalUsageError("Invalid rule identifier");

  const RV64Subtarget &ST = MF.getSubtarget<RV64Subtarget>();
  const auto *LI = ST.getLegalizerInfo();

  const Function &F = MF.getFunction();
  bool EnableOpt =
      MF.getTarget().getOptLevel() != CodeGenOptLevel::None && !ShouldSkip;
  GISelValueTracking *VT = GetVT();
  MachineDominatorTree *MDT = GetMDT();
  CombinerInfo CInfo(/*AllowIllegalOps*/ true, /*ShouldLegalizeIllegal*/ false,
                     /*LegalizerInfo*/ nullptr, EnableOpt, F.hasOptSize(),
                     F.hasMinSize());
  // Disable fixed-point iteration to reduce compile-time
  CInfo.MaxIterations = 1;
  CInfo.ObserverLvl = CombinerInfo::ObserverLevel::SinglePass;
  // This is the first Combiner, so the input IR might contain dead
  // instructions.
  CInfo.EnableFullDCE = false;
  RV64PreLegalizerCombinerImpl Impl(MF, CInfo, *VT, /*CSEInfo*/ nullptr,
                                     RuleConfig, ST, MDT, LI);
  return Impl.combineMachineInstrs();
}

char RV64PreLegalizerCombinerLegacy::ID = 0;
INITIALIZE_PASS_BEGIN(RV64PreLegalizerCombinerLegacy, DEBUG_TYPE,
                      "Combine RV64 machine instrs before legalization", false,
                      false)
INITIALIZE_PASS_DEPENDENCY(GISelValueTrackingAnalysisLegacy)
INITIALIZE_PASS_END(RV64PreLegalizerCombinerLegacy, DEBUG_TYPE,
                    "Combine RV64 machine instrs before legalization", false,
                    false)

namespace llvm {
FunctionPass *createRV64PreLegalizerCombiner() {
  return new RV64PreLegalizerCombinerLegacy();
}
} // end namespace llvm

bool RV64PreLegalizerCombinerLegacy::runOnMachineFunction(
    MachineFunction &MF) {
  return runPreLegalizerCombiner(
      MF, skipFunction(MF.getFunction()),
      [&]() {
        return &getAnalysis<GISelValueTrackingAnalysisLegacy>().get(MF);
      },
      [&]() {
        return &getAnalysis<MachineDominatorTreeWrapperPass>().getDomTree();
      });
}