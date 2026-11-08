//===-- RV64MCTargetDesc.h - RV64 Target Descriptions -------------*- C++ -*-===//
//
// This file provides RV64 specific target descriptions.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RV64_MCTARGETDESC_RV64MCTARGETDESC_H
#define LLVM_LIB_TARGET_RV64_MCTARGETDESC_RV64MCTARGETDESC_H

#include "llvm/Config/config.h"
#include "llvm/MC/MCContext.h"
#include "llvm/Support/DataTypes.h"

#include <memory>

namespace llvm {
class MCAsmBackend;
class MCCodeEmitter;
class MCContext;
class MCInstrInfo;
class MCObjectTargetWriter;
class MCRegisterInfo;
class MCSubtargetInfo;
class MCTargetOptions;
class Target;

MCCodeEmitter *createRV64MCCodeEmitter(const MCInstrInfo &MCII, MCContext &Ctx);
MCAsmBackend *createRV64AsmBackend(const Target &T, const MCSubtargetInfo &STI,
                                  const MCRegisterInfo &MRI,
                                  const MCTargetOptions &Options);

std::unique_ptr<MCObjectTargetWriter> createRV64ELFObjectWriter(uint8_t OSABI);
} // namespace llvm

// Defines symbolic names for RV64 registers.  This defines a mapping from
// register name to register number.
//
#define GET_REGINFO_ENUM
#include "RV64GenRegisterInfo.inc"

// Defines symbolic names for the RV64 instructions.
//
#define GET_INSTRINFO_ENUM
#define GET_INSTRINFO_MC_HELPER_DECLS
#include "RV64GenInstrInfo.inc"

#define GET_SUBTARGETINFO_ENUM
#include "RV64GenSubtargetInfo.inc"

#endif
