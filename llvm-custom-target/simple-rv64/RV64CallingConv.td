//===-- RV64CallingConv.td - Calling Conventions RV64 ----*- tablegen -*-===//
//
// This describes the calling conventions for the RV64 architectures.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// RV64 calling convention - LP64
//===----------------------------------------------------------------------===//

def CC_RV64_LP64 : CallingConv<[
  // Promote i8/i16/i32 args to i64
  CCIfType<[i8, i16, i32], CCPromoteToType<i64>>,

  // Reserve a stack slot for byval structs
  CCIfByVal<CCPassByVal<8, 8>>,

  // All arguments get passed in integer registers if there is space
  CCIfType<[i64], CCAssignToReg<[X10, X11, X12, X13, X14, X15, X16, X17]>>,

  // Could be assigned to the stack in 8-byte aligned units
  CCAssignToStack<8, 8>
]>;

def RetCC_RV64_LP64 : CallingConv<[
  // Promote i8/i16/i32 args to i64
  CCIfType<[i8, i16, i32], CCPromoteToType<i64>>,

  // Assign to register
  CCIfType<[i64], CCAssignToReg<[X10, X11]>>,
]>;

// Callee-saved registers
def CSR : CalleeSavedRegs<(add (sequence "X%u", 8, 9), (sequence "X%u", 18, 27), X1)>;
