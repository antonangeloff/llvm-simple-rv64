add_llvm_component_library(LLVMRV64Desc
  RV64MCTargetDesc.cpp
  RV64InstPrinter.cpp
  RV64MCAsmInfo.cpp

  LINK_COMPONENTS
  MC
  RV64Info
  Support
  TargetParser

  ADD_TO_COMPONENT
  RV64
  )
