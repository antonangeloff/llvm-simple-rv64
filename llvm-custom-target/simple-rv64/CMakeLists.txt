add_llvm_component_group(RV64)

set(LLVM_TARGET_DEFINITIONS RV64.td)

tablegen(LLVM RV64GenAsmWriter.inc -gen-asm-writer)
tablegen(LLVM RV64GenCallingConv.inc -gen-callingconv)
tablegen(LLVM RV64GenInstrInfo.inc -gen-instr-info)
tablegen(LLVM RV64GenRegisterInfo.inc -gen-register-info)
tablegen(LLVM RV64GenSubtargetInfo.inc -gen-subtarget)
tablegen(LLVM RV64GenGlobalISel.inc -gen-global-isel)
tablegen(LLVM RV64GenRegisterBank.inc -gen-register-bank)
tablegen(LLVM RV64GenMCPseudoLowering.inc -gen-pseudo-lowering)
tablegen(LLVM RV64GenPreLegalizeGICombiner.inc -gen-global-isel-combiner -combiners="RV64PreLegalizerCombiner")

add_public_tablegen_target(RV64CommonTableGen)

add_llvm_target(RV64CodeGen
  GISel/RV64CallLowering.cpp
  GISel/RV64InstructionSelector.cpp
  GISel/RV64PreLegalizerCombiner.cpp
  GISel/RV64RegisterBankInfo.cpp
  GISel/RV64LegalizerInfo.cpp
  RV64AsmPrinter.cpp
  RV64CallingConv.cpp
  RV64FrameLowering.cpp
  RV64InstrInfo.cpp
  RV64ISelLowering.cpp
  RV64MachineFunctionInfo.cpp
  RV64MCInstLower.cpp
  RV64RegisterInfo.cpp
  RV64Subtarget.cpp
  RV64TargetMachine.cpp

  LINK_COMPONENTS
  Analysis
  AsmPrinter
  RV64Desc
  RV64Info
  CodeGen
  CodeGenTypes
  Core
  GlobalISel
  MC
  Support
  Target
  TargetParser
  TransformUtils

  ADD_TO_COMPONENT
  RV64
  )

add_subdirectory(MCTargetDesc)
add_subdirectory(TargetInfo)