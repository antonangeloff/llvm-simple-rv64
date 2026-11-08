//===-- RV64MachineFunctionInfo.h - RV64 private data -----------*- C++ -*-===//
///
/// \file
/// This file declares the RV64 specific subclass of MachineFunctionInfo.
///
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_RV64_RV64MACHINEFUNCTIONINFO_H
#define LLVM_LIB_TARGET_RV64_RV64MACHINEFUNCTIONINFO_H

#include "llvm/CodeGen/CallingConvLower.h"
#include "llvm/CodeGen/MachineFunction.h"
// #include "llvm/CodeGenTypes/MachineValueType.h"

namespace llvm {

class RV64MachineFunctionInfo : public MachineFunctionInfo {
  int VarArgsFrameIndex = 0;
  int VarArgsSaveSize = 0;

public:
  explicit RV64MachineFunctionInfo(const Function &F,
                                   const TargetSubtargetInfo *STI) {}

  MachineFunctionInfo *
  clone(BumpPtrAllocator &Allocator, MachineFunction &DestMF,
        const DenseMap<MachineBasicBlock *, MachineBasicBlock *> &Src2DstMBB)
      const override;

  int getVarArgsFrameIndex() const { return VarArgsFrameIndex; }
  void setVarArgsFrameIndex(int Index) { VarArgsFrameIndex = Index; }

  int getVarArgsSaveSize() const { return VarArgsSaveSize; }
  void setVarArgsSaveSize(int Size) { VarArgsSaveSize = Size; }

private:
  virtual void anchor();
};

} // end of namespace llvm

#endif // LLVM_LIB_TARGET_RV64_RV64MACHINEFUNCTIONINFO_H
