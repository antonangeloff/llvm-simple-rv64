add_llvm_component_library(LLVMRV64Info
  RV64TargetInfo.cpp

  LINK_COMPONENTS
  MC
  Support

  ADD_TO_COMPONENT
  RV64
  )
