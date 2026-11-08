//===-- RV64RegisterBanks.td - Describe the RV64 Banks -------*- tablegen -*-===//
///
/// \file
/// Define the RV64 register banks used for GlobalISel.
///
//===----------------------------------------------------------------------===//

/// General Purpose Registers
def GPRRegBank : RegisterBank<"GPRB", [GeneralPurposeRegisters]>;
