//===-- RV64CallLowering.cpp - Call lowering for GlobalISel ------*- C++ -*-===//
///
/// \file
/// This file implements the lowering of LLVM calls to machine code calls for
/// GlobalISel.
///
//===----------------------------------------------------------------------===//

#include "RV64CallLowering.h"
#include "RV64CallingConv.h"
#include "RV64MachineFunctionInfo.h"
#include "RV64Subtarget.h"
#include "llvm/CodeGen/FunctionLoweringInfo.h"
#include "llvm/CodeGen/GlobalISel/MachineIRBuilder.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"

#define DEBUG_TYPE "RV64-call-lowering"

using namespace llvm;

namespace {

/// Helper class for values coming in through an ABI boundary (used for handling
/// formal arguments and call return values).
struct RV64IncomingValueHandler : public CallLowering::IncomingValueHandler {
  RV64IncomingValueHandler(MachineIRBuilder &MIRBuilder, MachineRegisterInfo &MRI)
      : IncomingValueHandler(MIRBuilder, MRI) {}

  // Allocates a stack slot for an argument and materializes a VReg which holds its address
  Register getStackAddress(uint64_t Size, int64_t Offset,
                           MachinePointerInfo &MPO,
                           ISD::ArgFlagsTy Flags) override {
    MachineFrameInfo &MFI = MIRBuilder.getMF().getFrameInfo();

    // Byval is assumed to be writable memory, but other stack passed arguments are not.
    const bool IsImmutable = !Flags.isByVal();

    // Allocate a stack slot for the current argument
    int FI = MFI.CreateFixedObject(Size, Offset, IsImmutable);
    MPO = MachinePointerInfo::getFixedStack(MIRBuilder.getMF(), FI);

    // Build and insert a G_FRAME_INDEX instruction
    return MIRBuilder.buildFrameIndex(LLT::pointer(MPO.getAddrSpace(), 64), FI)
        .getReg(0);
  }

  // Assign a value to (an already allocated) stack slot
  void assignValueToAddress(Register ValVReg, Register Addr, LLT MemTy,
                            const MachinePointerInfo &MPO,
                            const CCValAssign &VA) override {
    if (VA.getLocInfo() == CCValAssign::SExt || VA.getLocInfo() == CCValAssign::ZExt) {
      // If the value is zero- or sign-extended, its size becomes 8 bytes, so
      // that's what we should load.
      MemTy = LLT::scalar(64);
      assert(MRI.getType(ValVReg).isScalar() && "Only scalars supported currently");

      MachineInstrBuilder LoadVReg = customBuildLoad(LLT::scalar(64), Addr, MemTy, MPO);
      MIRBuilder.buildTrunc(ValVReg, LoadVReg);
    } else {
      // If the value is not extended, a simple load will suffice.
      customBuildLoad(ValVReg, Addr, MemTy, MPO);
    }
  }

  // Build and insert a G_LOAD instruction
  MachineInstrBuilder customBuildLoad(const DstOp &Res, Register Addr, LLT MemTy,
                                const MachinePointerInfo &MPO) {
    MachineFunction &MF = MIRBuilder.getMF();

    auto MMO = MF.getMachineMemOperand(MPO, MachineMemOperand::MOLoad, MemTy,
                                       inferAlignFromPtrInfo(MF, MPO));
    return MIRBuilder.buildLoad(Res, Addr, *MMO);
  }

  // Build and insert a COPY instruction for an argument assigned, and mark def/use as needed
  void assignValueToReg(Register ValVReg, Register PhysReg,
                        const CCValAssign &VA,
                        ISD::ArgFlagsTy Flags = {}) override {
    assert(VA.isRegLoc() && "Value shouldn't be assigned to reg");
    assert(VA.getLocReg() == PhysReg && "Assigning to the wrong reg?");

    uint64_t ValSize = VA.getValVT().getFixedSizeInBits();
    uint64_t LocSize = VA.getLocVT().getFixedSizeInBits();

    assert(ValSize <= 64 && "Unsupported value size");
    assert(LocSize <= 64 && "Unsupported location size");

    markPhysRegUsed(PhysReg);
    if (ValSize == LocSize) {
      MIRBuilder.buildCopy(ValVReg, PhysReg);
    } else {
      assert(ValSize < LocSize && "Extensions not supported");

      // We cannot create a truncating copy, nor a trunc of a physical register.
      // Therefore, we need to copy the content of the physical register into a
      // virtual one and then truncate that.
      auto PhysRegToVReg = MIRBuilder.buildCopy(LLT::scalar(LocSize), PhysReg);
      MIRBuilder.buildTrunc(ValVReg, PhysRegToVReg);
    }
  }

  // Handling of custom CC rules - none yet
  unsigned assignCustomValue(RV64CallLowering::ArgInfo &Arg,
                             ArrayRef<CCValAssign> VAs,
                             std::function<void()> *Thunk) override {
    return 0;
  }

  virtual void markPhysRegUsed(unsigned PhysReg) = 0;
};

struct FormalArgHandler : public RV64IncomingValueHandler {
  FormalArgHandler(MachineIRBuilder &MIRBuilder, MachineRegisterInfo &MRI)
      : RV64IncomingValueHandler(MIRBuilder, MRI) {}

  void markPhysRegUsed(unsigned PhysReg) override {
    MIRBuilder.getMRI()->addLiveIn(PhysReg);
    MIRBuilder.getMBB().addLiveIn(PhysReg);
  }
};

struct CallReturnArgHandler : public RV64IncomingValueHandler {
  CallReturnArgHandler(MachineIRBuilder &MIRBuilder, MachineRegisterInfo &MRI,
                    MachineInstrBuilder &MIB)
      : RV64IncomingValueHandler(MIRBuilder, MRI), MIB(MIB) {}

private:
  void assignValueToReg(Register ValVReg, Register PhysReg,
                        const CCValAssign &VA,
                        ISD::ArgFlagsTy Flags = {}) override {
    MIB.addDef(PhysReg, RegState::Implicit);
    MIRBuilder.buildCopy(ValVReg, PhysReg);
  }

  void markPhysRegUsed(unsigned PhysReg) override {
    llvm_unreachable("CallReturnArgHandler overrides assignValueToReg directly");
  }

  MachineInstrBuilder &MIB;
};

struct OutgoingArgHandler : public CallLowering::OutgoingValueHandler {
  OutgoingArgHandler(MachineIRBuilder &MIRBuilder, MachineRegisterInfo &MRI,
                         MachineInstrBuilder MIB)
      : OutgoingValueHandler(MIRBuilder, MRI), MIB(MIB),
        DL(MIRBuilder.getMF().getDataLayout()),
        STI(MIRBuilder.getMF().getSubtarget<RV64Subtarget>()) {}

  void assignValueToReg(Register ValVReg, Register PhysReg,
                        const CCValAssign &VA,
                        ISD::ArgFlagsTy Flags = {}) override {
    MIB.addUse(PhysReg, RegState::Implicit);
    Register ExtReg = extendRegister(ValVReg, VA);
    MIRBuilder.buildCopy(PhysReg, ExtReg);
  }

  void assignValueToAddress(Register ValVReg, Register Addr, LLT MemTy,
                            const MachinePointerInfo &MPO,
                            const CCValAssign &VA) override {
    MachineFunction &MF = MIRBuilder.getMF();
    Register ExtReg = extendRegister(ValVReg, VA);
    auto *MMO = MF.getMachineMemOperand(MPO, MachineMemOperand::MOStore, MemTy,
                                        Align(MemTy.getSizeInBytes()));
    MIRBuilder.buildStore(ExtReg, Addr, *MMO);
  }

  Register getStackAddress(uint64_t Size, int64_t Offset,
                           MachinePointerInfo &MPO,
                           ISD::ArgFlagsTy Flags) override {
    LLT p0 = LLT::pointer(0, DL.getPointerSizeInBits(0));
    LLT SType = LLT::scalar(DL.getPointerSizeInBits(0));
    Register StackReg = RV::X2;
    auto SPReg = MIRBuilder.buildCopy(p0, StackReg).getReg(0);
    auto OffsetReg = MIRBuilder.buildConstant(SType, Offset);
    auto AddrReg = MIRBuilder.buildPtrAdd(p0, SPReg, OffsetReg);
    MPO = MachinePointerInfo::getStack(MIRBuilder.getMF(), Offset);
    return AddrReg.getReg(0);
  }

  MachineInstrBuilder MIB;
  const DataLayout &DL;
  const RV64Subtarget &STI;
};

} // end anonymous namespace

RV64CallLowering::RV64CallLowering(const RV64TargetLowering &TLI)
    : CallLowering(&TLI) {}

bool RV64CallLowering::lowerReturn(MachineIRBuilder &MIRBuilder,
                                  const Value *Val, ArrayRef<Register> VRegs,
                                  FunctionLoweringInfo &FLI,
                                  Register SwiftErrorVReg) const {

  MachineFunction &MF = MIRBuilder.getMF();
  MachineRegisterInfo &MRI = MF.getRegInfo();
  const Function &F = MF.getFunction();
  const DataLayout &DL = F.getDataLayout();
  const RV64TargetLowering &TLI = *getTLI<RV64TargetLowering>();
  CCAssignFn *AssignFn = TLI.CCAssignFnForReturn(F.getCallingConv(), F.isVarArg());

  MachineInstrBuilder MIB = MIRBuilder.buildInstrNoInsert(RV::PseudoRet);
  bool Success = true;

  if (!FLI.CanLowerReturn) {
    // Return type didn't fit in the return registers: write the real
    // value through the hidden sret pointer instead.
    insertSRetStores(MIRBuilder, Val->getType(), VRegs, FLI.DemoteRegister);
  } else if (!VRegs.empty()) {
    SmallVector<ArgInfo, 8> SplitArgs;
    ArgInfo OrigArg{ VRegs, Val->getType(), 0 };

    setArgFlags(OrigArg, AttributeList::ReturnIndex, DL, F);
    splitToValueTypes(OrigArg, SplitArgs, DL, F.getCallingConv());

    OutgoingValueAssigner ArgAssigner(AssignFn);
    OutgoingArgHandler ArgHandler(MIRBuilder, MRI, MIB);
    Success = determineAndHandleAssignments(ArgHandler, ArgAssigner, SplitArgs,
                                            MIRBuilder, F.getCallingConv(), F.isVarArg());
  }

  MIRBuilder.insertInstr(MIB);
  return Success;
}

static bool isSupportedType(const DataLayout &DL, const RV64TargetLowering &TLI, Type *T) {
  if (T->isArrayTy()) {
    // Check if underlying type is supported
    return isSupportedType(DL, TLI, T->getArrayElementType());
  }

  if (T->isStructTy()) {
    // Check if each individual struct field is supported
    auto StructT = cast<StructType>(T);
    for (unsigned i = 0, e = StructT->getNumElements(); i != e; ++i) {
      if (!isSupportedType(DL, TLI, StructT->getElementType(i))) {
        return false;
      }
    }
    return true;
  }

  EVT VT = TLI.getValueType(DL, T, true);
  if (!VT.isSimple() || VT.isVector() || !(VT.isInteger() || VT.isFloatingPoint())) {
    return false;
  }

  unsigned VTSize = VT.getSimpleVT().getSizeInBits();
  return VTSize == 1 || VTSize == 8 || VTSize == 16 || VTSize == 32 || VTSize == 64;
}

bool RV64CallLowering::lowerFormalArguments(MachineIRBuilder &MIRBuilder,
                                           const Function &F,
                                           ArrayRef<ArrayRef<Register>> VRegs,
                                           FunctionLoweringInfo &FLI) const {
  // Quick exit if there aren't any args and nothing to demote
  if (F.arg_empty() && FLI.CanLowerReturn && !F.isVarArg()) {
    return true;
  }

  const RV64TargetLowering &TLI = *getTLI<RV64TargetLowering>();
  MachineFunction &MF = MIRBuilder.getMF();
  MachineRegisterInfo &MRI = MF.getRegInfo();
  MachineBasicBlock &MBB = MIRBuilder.getMBB();
  const DataLayout &DL = MF.getDataLayout();

  // Make sure all argument types are supported by the backend
  for (auto &Arg : F.args()) {
    if (!isSupportedType(DL, TLI, Arg.getType())) {
      return false;
    }
  }

  CCAssignFn *AssignFn = TLI.CCAssignFnForCall(F.getCallingConv(), F.isVarArg());
  IncomingValueAssigner ArgAssigner(AssignFn);
  FormalArgHandler ArgHandler(MIRBuilder, MRI);

  SmallVector<ArgInfo, 8> decomposedArgInfos;

  // Return type didn't fit in the return registers: prepend the hidden
  // sret pointer so it gets assigned a real argument register/slot just
  // like any other argument below.
  if (!FLI.CanLowerReturn) {
    insertSRetIncomingArgument(F, decomposedArgInfos, FLI.DemoteRegister, MRI, DL);
  }

  unsigned Idx = 0;

  for (auto &Arg : F.args()) {
    ArgInfo OrigArgInfo(VRegs[Idx], Arg.getType(), Idx);

    // Assign
    setArgFlags(OrigArgInfo, AttributeList::FirstArgIndex + Idx, DL, F);

    // Decompose complex data types to primitive ones
    splitToValueTypes(OrigArgInfo, decomposedArgInfos, DL, F.getCallingConv());

    Idx++;
  }

  // Seek the builder back to the beginning of the function
  if (!MBB.empty()) {
    MIRBuilder.setInstr(*MBB.begin());
  }

  SmallVector<CCValAssign, 16> ArgLocs;
  CCState CCInfo(F.getCallingConv(), F.isVarArg(), MF, ArgLocs, F.getContext());

  if (!determineAssignments(ArgAssigner, decomposedArgInfos, CCInfo)) {
    return false;
  }

  if (F.isVarArg()) {
    saveVarArgRegisters(MIRBuilder, ArgHandler, ArgAssigner, CCInfo);
  }

  if (!handleAssignments(ArgHandler, decomposedArgInfos, CCInfo, ArgLocs,
                         MIRBuilder)) {
    return false;
  }

  // Move back to the end of the basic block.
  MIRBuilder.setMBB(MBB);
  return true;
}

static unsigned getFirstUnallocated(const CCState &CCInfo,
                                    ArrayRef<MCRegister> Regs) {
  for (unsigned I = 0; I < Regs.size(); ++I) {
    if (!CCInfo.isAllocated(Regs[I])) {
      return I;
    }
  }
  return Regs.size();
}

void RV64CallLowering::saveVarArgRegisters(MachineIRBuilder &MIRBuilder,
                                           IncomingValueHandler &Handler,
                                           IncomingValueAssigner &Assigner,
                                           CCState &CCInfo) const {
  MachineFunction &MF = MIRBuilder.getMF();
  MachineRegisterInfo &MRI = MF.getRegInfo();
  MachineFrameInfo &MFI = MF.getFrameInfo();
  RV64MachineFunctionInfo *RVFI = MF.getInfo<RV64MachineFunctionInfo>();

  const unsigned XLenInBytes = MF.getDataLayout().getPointerSize(0);
  const unsigned FirstUnallocatedIdx = getFirstUnallocated(CCInfo, CC_RV64_LP64_ArgRegs);
  const unsigned ArgRegCount = std::size(CC_RV64_LP64_ArgRegs);
  const int VarArgsSaveSize = XLenInBytes * (ArgRegCount - FirstUnallocatedIdx);
  int FI;

  if (VarArgsSaveSize == 0) {
    // Every integer argument register was claimed by a named parameter. Nothing to spill.
    FI = MFI.CreateFixedObject(XLenInBytes, CCInfo.getStackSize(), true);
  } else {
    // Spill the unclaimed registers into a save area immediately below entry sp
    FI = MFI.CreateFixedObject(VarArgsSaveSize, -VarArgsSaveSize, true);

    const LLT P0 = LLT::pointer(0, 64);
    const LLT S64 = LLT::scalar(64);

    MachineInstrBuilder FIN = MIRBuilder.buildFrameIndex(P0, FI);
    MachineInstrBuilder OffsetReg = MIRBuilder.buildConstant(S64, XLenInBytes);

    for (unsigned I = FirstUnallocatedIdx; I < ArgRegCount; ++I) {
      Register VReg = MRI.createGenericVirtualRegister(S64);
      Handler.assignValueToReg(
          VReg, CC_RV64_LP64_ArgRegs[I],
          CCValAssign::getReg(I, MVT::i64, CC_RV64_LP64_ArgRegs[I], MVT::i64, CCValAssign::Full));
      MachinePointerInfo MPO = MachinePointerInfo::getFixedStack(
          MF, FI, (I - FirstUnallocatedIdx) * XLenInBytes);
      MIRBuilder.buildStore(VReg, FIN, MPO, inferAlignFromPtrInfo(MF, MPO));
      FIN = MIRBuilder.buildPtrAdd(MRI.createGenericVirtualRegister(P0), FIN.getReg(0), OffsetReg);
    }
  }

  RVFI->setVarArgsFrameIndex(FI);
  RVFI->setVarArgsSaveSize(VarArgsSaveSize);
}

bool RV64CallLowering::lowerCall(MachineIRBuilder &MIRBuilder,
                                CallLoweringInfo &Info) const {

  MachineFunction &MF = MIRBuilder.getMF();
  Function &F = MF.getFunction();
  MachineRegisterInfo &MRI = MF.getRegInfo();
  const DataLayout &DL = F.getDataLayout();
  const RV64TargetLowering &TLI = *getTLI<RV64TargetLowering>();
  const RV64Subtarget &STI = MF.getSubtarget<RV64Subtarget>();
  const TargetInstrInfo &TII = *STI.getInstrInfo();
  const RV64RegisterInfo *TRI = STI.getRegisterInfo();

  SmallVector<ArgInfo, 8> CalleeInArgs;
  SmallVector<ArgInfo, 8> CalleeReturnArgs;

  for (auto &OrigArg : Info.OrigArgs) {
    splitToValueTypes(OrigArg, CalleeInArgs, DL, Info.CallConv);
  }

  if (Info.CanLowerReturn && !Info.OrigRet.Ty->isVoidTy()) {
    splitToValueTypes(Info.OrigRet, CalleeReturnArgs, DL, Info.CallConv);
  }

  MachineInstrBuilder AdjStackDownInstruction = MIRBuilder.buildInstr(TII.getCallFrameSetupOpcode());
  unsigned CallOpcode = Info.Callee.isReg() ? RV::PseudoCallIndirect : RV::PseudoCall;

  MachineInstrBuilder CallInstruction = MIRBuilder.buildInstrNoInsert(CallOpcode)
                 .add(Info.Callee)
                 .addRegMask(TRI->getCallPreservedMask(MF, Info.CallConv));

  CCAssignFn *AssignFn = TLI.CCAssignFnForCall(Info.CallConv, Info.IsVarArg);
  OutgoingValueAssigner Assigner(AssignFn);
  OutgoingArgHandler Handler(MIRBuilder, MRI, CallInstruction);
  if (!determineAndHandleAssignments(Handler, Assigner, CalleeInArgs, MIRBuilder,
                                     Info.CallConv, Info.IsVarArg))
  {
    return false;
  }

  if (Info.Callee.isReg()) {
    constrainOperandRegClass(MF, *TRI, MRI, *STI.getInstrInfo(),
                             *STI.getRegBankInfo(), *CallInstruction, CallInstruction->getDesc(),
                             Info.Callee, 0);
  }

  MIRBuilder.insertInstr(CallInstruction);

  if (!Info.CanLowerReturn) {
    // Callee's return type didn't fit in the return registers: the real
    // value was written through our own stack slot (Info.DemoteRegister)
    // by the callee, via the hidden sret pointer we passed as an outgoing
    // argument above. Read it back directly rather than assigning return
    // registers.
    insertSRetLoads(MIRBuilder, Info.OrigRet.Ty, Info.OrigRet.Regs,
                    Info.DemoteRegister, Info.DemoteStackIndex);
  } else if (!Info.OrigRet.Ty->isVoidTy()) {
    CCAssignFn *RetAssignFn = TLI.CCAssignFnForReturn(Info.CallConv, Info.IsVarArg);
    OutgoingValueAssigner Assigner(RetAssignFn, RetAssignFn);
    CallReturnArgHandler Handler(MIRBuilder, MRI, CallInstruction);
    if (!determineAndHandleAssignments(Handler, Assigner, CalleeReturnArgs, MIRBuilder,
                                       Info.CallConv, Info.IsVarArg))
    {
      return false;
    }
  }

  AdjStackDownInstruction.addImm(Assigner.StackSize).addImm(0);
  MIRBuilder.buildInstr(TII.getCallFrameDestroyOpcode()).addImm(Assigner.StackSize).addImm(0);

  return true;

}

bool RV64CallLowering::canLowerReturn(MachineFunction &MF, CallingConv::ID CallConv,
                              SmallVectorImpl<BaseArgInfo> &Outs,
                              bool IsVarArg) const
{
  SmallVector<CCValAssign, 16> ArgLocs;
  const RV64TargetLowering &TLI = *getTLI<RV64TargetLowering>();
  CCState CCInfo(CallConv, IsVarArg, MF, ArgLocs, MF.getFunction().getContext());
  return checkReturn(CCInfo, Outs, TLI.CCAssignFnForReturn(CallConv, IsVarArg));
}