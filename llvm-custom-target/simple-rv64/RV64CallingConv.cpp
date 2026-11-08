//===-- RV64CallingConv.cpp - RV64 Custom CC Routines ---------*- C++ -*-===//

#include "RV64CallingConv.h"
#include "RV64.h"

using namespace llvm;

#define GET_CC_REGISTER_LISTS
#include "RV64GenCallingConv.inc"
