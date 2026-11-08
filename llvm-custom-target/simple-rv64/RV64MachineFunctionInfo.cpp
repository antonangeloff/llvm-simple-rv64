//===-- RV64MachineFunctionInfo.cpp - RV64 private data ---------*- C++ -*-===//

#include "RV64MachineFunctionInfo.h"

// #include "RV64InstrInfo.h"
// #include "RV64Subtarget.h"

// #include "llvm/CodeGen/MachineInstrBuilder.h"
// #include "llvm/CodeGen/MachineRegisterInfo.h"
// #include "llvm/IR/Function.h"

using namespace llvm;

void RV64MachineFunctionInfo::anchor() {}

MachineFunctionInfo *RV64MachineFunctionInfo::clone(
    BumpPtrAllocator &Allocator, MachineFunction &DestMF,
    const DenseMap<MachineBasicBlock *, MachineBasicBlock *> &Src2DstMBB)
    const {
  return DestMF.cloneInfo<RV64MachineFunctionInfo>(*this);
}
