//===-- RV64MCTargetDesc.cpp - RV64 Target Descriptions ---------------------===//
//
// This file provides RV64 specific target descriptions.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/RV64MCTargetDesc.h"
#include "MCTargetDesc/RV64InstPrinter.h"
#include "MCTargetDesc/RV64MCAsmInfo.h"
#include "TargetInfo/RV64TargetInfo.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"

#define GET_INSTRINFO_MC_DESC
#define ENABLE_INSTR_PREDICATE_VERIFIER
#include "RV64GenInstrInfo.inc"

#define GET_SUBTARGETINFO_MC_DESC
#include "RV64GenSubtargetInfo.inc"

#define GET_REGINFO_MC_DESC
#include "RV64GenRegisterInfo.inc"

using namespace llvm;

static MCInstrInfo *createRV64MCInstrInfo() {
  MCInstrInfo *X = new MCInstrInfo();
  InitRV64MCInstrInfo(X);
  return X;
}

static MCRegisterInfo *createRV64MCRegisterInfo(const Triple &TT) {
  MCRegisterInfo *X = new MCRegisterInfo();
  InitRV64MCRegisterInfo(X, RV::X1);
  return X;
}

static MCSubtargetInfo *createRV64MCSubtargetInfo(const Triple &TT,
                                                 StringRef CPU, StringRef FS) {
  return createRV64MCSubtargetInfoImpl(TT, CPU, /*TuneCPU*/ CPU, FS);
}

static MCStreamer *
createRV64MCStreamer(const Triple &T, MCContext &Ctx,
                    std::unique_ptr<MCAsmBackend> &&MAB,
                    std::unique_ptr<MCObjectWriter> &&OW,
                    std::unique_ptr<MCCodeEmitter> &&Emitter) {
  return createELFStreamer(Ctx, std::move(MAB), std::move(OW),
                           std::move(Emitter));
}

static MCInstPrinter *createRV64MCInstPrinter(const Triple &T,
                                             unsigned SyntaxVariant,
                                             const MCAsmInfo &MAI,
                                             const MCInstrInfo &MII,
                                             const MCRegisterInfo &MRI) {
  if (SyntaxVariant == 0)
    return new RV64InstPrinter(MAI, MII, MRI);
  return nullptr;
}

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void LLVMInitializeRV64TargetMC() {
  for (Target *T : {&getTheRV64Target()}) {
    // Register the MC asm info.
    RegisterMCAsmInfo<RV64MCAsmInfo> X(*T);

    // Register the MC instruction info.
    TargetRegistry::RegisterMCInstrInfo(*T, createRV64MCInstrInfo);

    // Register the MC register info.
    TargetRegistry::RegisterMCRegInfo(*T, createRV64MCRegisterInfo);

    // Register the MC subtarget info.
    TargetRegistry::RegisterMCSubtargetInfo(*T,
                                            createRV64MCSubtargetInfo);

    // Register the object streamer
    TargetRegistry::RegisterELFStreamer(*T, createRV64MCStreamer);

    // Register the MCInstPrinter.
    TargetRegistry::RegisterMCInstPrinter(*T, createRV64MCInstPrinter);

    // No MCCodeEmitter/MCAsmBackend registered.
  }
}
