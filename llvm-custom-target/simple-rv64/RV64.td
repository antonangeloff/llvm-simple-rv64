//===-- RV64.td - Describe the RV64 Target Machine ---------*- tablegen -*-===//
//
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Target-independent interfaces
//===----------------------------------------------------------------------===//

include "llvm/Target/Target.td"
// include "llvm/TableGen/SearchableTable.td"

//===----------------------------------------------------------------------===//
// Subtarget features
//===----------------------------------------------------------------------===//

def FeatureI : SubtargetFeature<"i", "HasI", "true", "Base Integer Instruction Set">;
def Feature64Bit : SubtargetFeature<"64bit", "Has64Bit", "true", "RV64 (XLEN=64) base ISA width">;

// Core features: M/A
def FeatureM : SubtargetFeature<"m", "HasM", "true", "Enable M (multiply/divide) extension">;
def FeatureA : SubtargetFeature<"a", "HasA", "true", "Enable A (atomics) extension">;

def FeatureZmmul : SubtargetFeature<"zmmul", "HasZmmul", "true", "Zmmul (integer multiplication) extension [not fully implemented]">;
// Not yet implemented: C/F/D
def FeatureC : SubtargetFeature<"c", "HasC", "true", "Enable C (compressed) extension [not implemented]">;
def FeatureF : SubtargetFeature<"f", "HasF", "true", "Enable F (single-precision float) extension [not implemented]">;
def FeatureD : SubtargetFeature<"d", "HasD", "true", "Enable D (double-precision float) extension [not implemented]">;

// Only the RV64 ISA is supported.
defvar XLEN = 64;

//===----------------------------------------------------------------------===//
// Register File, Calling Conv, Instruction Descriptions
//===----------------------------------------------------------------------===//

// include "RV64ASITags.td" // todo: delete
// include "RV64PrefetchTags.td" // todo: delete
include "RV64RegisterInfo.td"
include "RV64CallingConv.td"
// include "RV64Schedule.td" // todo: enable later
include "RV64InstrInfo.td"
include "GISel/RV64RegisterBanks.td"
include "GISel/RV64Combine.td"


defm : RemapAllTargetPseudoPointerOperands<GeneralPurposeRegisters>;

def RV64InstrInfo : InstrInfo;

def RV64AsmParser : AsmParser {
  let ShouldEmitMatchRegisterAltName = true;
  let AllowDuplicateRegisterNames = true;
}

def RV64AsmParserVariant : AsmParserVariant {
}

//===----------------------------------------------------------------------===//
// Supported RISC-V processors
//===----------------------------------------------------------------------===//

class Proc<string Name, list<SubtargetFeature> Features,
           list<SubtargetFeature> TuneFeatures = []>
 : Processor<Name, NoItineraries, Features, TuneFeatures>;

// Generic processor only
def : Proc<"generic-rv64", [FeatureI, Feature64Bit, FeatureM]>;

//===----------------------------------------------------------------------===//
// Declare the target which we are implementing
//===----------------------------------------------------------------------===//

def RV64AsmWriter : AsmWriter {
  string AsmWriterClassName  = "InstPrinter";
  int PassSubtarget = 1;
  int Variant = 0;
}

def RV64 : Target {
  // Pull in Instruction Info:
  let InstructionSet = RV64InstrInfo;
  let AssemblyParsers  = [RV64AsmParser];
  let AssemblyParserVariants = [RV64AsmParserVariant];
  let AssemblyWriters = [RV64AsmWriter];
  let AllowRegisterRenaming = 1;
}
