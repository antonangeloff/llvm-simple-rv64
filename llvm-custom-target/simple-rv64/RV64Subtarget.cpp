//===-- RV64Subtarget.cpp - RV64 Subtarget Information ------------------===//
//
// This file implements the RV64 specific subclass of TargetSubtargetInfo.
//
//===----------------------------------------------------------------------===//

#include "RV64Subtarget.h"
#include "RV64.h"
#include "RV64TargetMachine.h"
#include "GISel/RV64CallLowering.h"
#include "GISel/RV64LegalizerInfo.h"
#include "GISel/RV64RegisterBankInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/MathExtras.h"

using namespace llvm;

#define DEBUG_TYPE "RV64-subtarget"

#define GET_SUBTARGETINFO_TARGET_DESC
#define GET_SUBTARGETINFO_CTOR
#include "RV64GenSubtargetInfo.inc"

void RV64Subtarget::anchor() { }

RV64Subtarget &RV64Subtarget::initializeSubtargetDependencies(
    StringRef CPU, StringRef TuneCPU, StringRef FS) {

  if (CPU.empty()) {
    CPU = "generic-rv64";
  }

  if (TuneCPU.empty())
    TuneCPU = CPU;

  // Parse features string.
  ParseSubtargetFeatures(CPU, TuneCPU, FS);

  // TODO: parse and apply F/D extensions
  return *this;
}

RV64Subtarget::RV64Subtarget(const StringRef &CPU, const StringRef &TuneCPU,
                               const StringRef &FS, const TargetMachine &TM)
    : RV64GenSubtargetInfo(TM.getTargetTriple(), CPU, TuneCPU, FS),
      InstrInfo(initializeSubtargetDependencies(CPU, TuneCPU, FS)),
      TLInfo(TM, *this), FrameLowering(*this) {

  CallLoweringInfo.reset(new RV64CallLowering(*getTargetLowering()));
  Legalizer.reset(new RV64LegalizerInfo(*this));
  auto *RBI = new RV64RegisterBankInfo(*getRegisterInfo());
  RegBankInfo.reset(RBI);

  InstSelector.reset(createRV64InstructionSelector(
      *static_cast<const RV64TargetMachine *>(&TM), *this, *RBI));

}

RV64Subtarget::~RV64Subtarget() = default;

bool RV64Subtarget::enableMachineScheduler() const {
  return true;
}


const CallLowering *RV64Subtarget::getCallLowering() const {
  return CallLoweringInfo.get();
}

InstructionSelector *RV64Subtarget::getInstructionSelector() const {
  return InstSelector.get();
}

const LegalizerInfo *RV64Subtarget::getLegalizerInfo() const {
  return Legalizer.get();
}

const RegisterBankInfo *RV64Subtarget::getRegBankInfo() const {
  return RegBankInfo.get();
}

