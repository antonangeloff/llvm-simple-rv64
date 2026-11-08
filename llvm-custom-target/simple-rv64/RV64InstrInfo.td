//===-- RV64InstrInfo.td - Target Description for RV64 Target ---------------===//
//
// This file describes the RV64 instructions in TableGen format.
//
//===----------------------------------------------------------------------===//

include "RV64InstrFormats.td"

// Instruction Operands and Patterns

def RV64HasFeatureM : Predicate<"Subtarget->hasM()">;
def RV64NoFeatureM : Predicate<"!Subtarget->hasM()">;
def RV64HasAtomics : Predicate<"Subtarget->hasA()">;
def RV64NoAtomics : Predicate<"!Subtarget->hasA()">;

def BranchTargetOperand : Operand<OtherVT> {
  // let PrintMethod = "printBrTargetOperand";
  // let ParserMatchClass = ImmediateAsmOperand<"BrTarget">;
}
def CallTargetOperand : Operand<i64>;

// def U64IMMOperand   : Operand<i64> {
//   let PrintMethod = "printImm64Operand";
// }

// def S16IMMOperand : Operand<i16> {
//   let ParserMatchClass = SImm16AsmOperand;
// }

// def GprOrImmOperand : Operand<i64>;

def i64immSExt12 : ImmLeaf<i64, [{return isInt<12>(Imm); }]>;
def i32immSExt12 : ImmLeaf<i32, [{return isInt<12>(Imm); }]>;

def u20imm : Operand<i64> {
  let OperandType = "OPERAND_IMMEDIATE";
  let MCOperandPredicate = [{
    int64_t Imm;
    if (!MCOp.evaluateAsConstantImm(Imm)) {
      return false;
    }
    return isUInt<20>(Imm);
  }];
}

// Base arithmetic instruction definitions
multiclass ALU_RR_RI<bits<3> func3, bits<7> func7, string mnemonic, SDPatternOperator node> {
  def "" : InstRV64TypeR<0b0110011, func3, func7,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                   mnemonic#" $rd, $rs1, $rs2",
                   [(set GeneralPurposeRegisters:$rd,
                        (i64 (node (i64 GeneralPurposeRegisters:$rs1), (i64 GeneralPurposeRegisters:$rs2))))]>;

  def I : InstRV64TypeI<0b0010011, func3,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, i64imm:$imm),
                   mnemonic#"i $rd, $rs1, $imm",
                   [(set GeneralPurposeRegisters:$rd,
                        (i64 (node (i64 GeneralPurposeRegisters:$rs1), i64immSExt12:$imm)))]>;
}

multiclass ALU_RR_RI_BITWISE<bits<3> func3, bits<7> func7, string mnemonic, SDPatternOperator node>
  : ALU_RR_RI<func3, func7, mnemonic, node>
{
  // Pattern rules so i32-typed IR bitwise operations fallback to the general AND/OR/XOR/ANDI/ORI/XORI definition (which takes explicit i64)
  // TODO: no i32-with-immediate fallback Pat exists, so AND/OR/XOR with an i32 immediate operand gets an extra materialization instruction instead of folding; good to fix
  def : Pat<(i32 (node GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)), (!cast<Instruction>(NAME) GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)>;
}

multiclass ALU_RR_RI_SHIFT<bits<3> func3, bits<7> func7, bits<6> disc, string mnemonic, SDPatternOperator node> {
  def "" : InstRV64TypeR<0b0110011, func3, func7,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                   mnemonic#" $rd, $rs1, $rs2",
                   [(set GeneralPurposeRegisters:$rd,
                        (i64 (node (i64 GeneralPurposeRegisters:$rs1), (i64 GeneralPurposeRegisters:$rs2))))]>;

  def I : InstRV64TypeIShift<0b0010011, func3, disc,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, i64imm:$imm),
                   mnemonic#"i $rd, $rs1, $imm",
                   [(set GeneralPurposeRegisters:$rd,
                        (i64 (node (i64 GeneralPurposeRegisters:$rs1), i64immSExt12:$imm)))]>;

  def W : InstRV64TypeR<0b0111011, func3, func7,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                   mnemonic#"w $rd, $rs1, $rs2",
                   [(set GeneralPurposeRegisters:$rd,
                        (i32 (node (i32 GeneralPurposeRegisters:$rs1), (i32 GeneralPurposeRegisters:$rs2))))]>;

  def IW : InstRV64TypeIShift<0b0010011, func3, disc,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, i32imm:$imm),
                   mnemonic#"iw $rd, $rs1, $imm",
                   [(set GeneralPurposeRegisters:$rd,
                        (i32 (node (i32 GeneralPurposeRegisters:$rs1), i32immSExt12:$imm)))]>;
}

defm ADD : ALU_RR_RI<0b000, 0b0000000, "add", add>;
def ADDW : InstRV64TypeR<0b0111011, 0b000, 0b0000000,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                   "addw $rd, $rs1, $rs2",
                   [(set GeneralPurposeRegisters:$rd,
                        (i32 (add (i32 GeneralPurposeRegisters:$rs1), (i32 GeneralPurposeRegisters:$rs2))))]>;

def ADDIW : InstRV64TypeI<0b0011011, 0b000,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, i32imm:$imm),
                   "addiw $rd, $rs1, $imm",
                   [(set GeneralPurposeRegisters:$rd,
                        (i32 (add (i32 GeneralPurposeRegisters:$rs1), i32immSExt12:$imm)))]>;

def SUB : InstRV64TypeR<0b0110011, 0b000, 0b0100000,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                   "sub $rd, $rs1, $rs2",
                   [(set GeneralPurposeRegisters:$rd,
                        (i64 (sub GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)))]>;

def SUBW : InstRV64TypeR<0b0111011, 0b000, 0b0100000,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                   "subw $rd, $rs1, $rs2",
                   [(set GeneralPurposeRegisters:$rd,
                        (i32 (sub GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)))]>;

defm AND : ALU_RR_RI_BITWISE<0b111, 0b0000000, "and", and>;
defm OR : ALU_RR_RI_BITWISE<0b110, 0b0000000, "or", or>;
defm XOR : ALU_RR_RI_BITWISE<0b100, 0b0000000, "xor", xor>;

defm SLL : ALU_RR_RI_SHIFT<0b001, 0b0000000, 0b000000, "sll", shl>;
defm SRL : ALU_RR_RI_SHIFT<0b101, 0b0000000, 0b000000, "srl", srl>;
defm SRA : ALU_RR_RI_SHIFT<0b101, 0b0100000, 0b010000, "sra", sra>;

// ICMP-related
multiclass ICMP<bits<3> func3, bits<7> func7, string mnemonic, string immMnemonic> {
  def "" : InstRV64TypeR<0b0110011, func3, func7,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                   mnemonic#" $rd, $rs1, $rs2",
                   []>;

  def I : InstRV64TypeI<0b0010011, func3,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, i64imm:$imm),
                   immMnemonic#" $rd, $rs1, $imm",
                   []>;
}

defm SLT : ICMP<0b010, 0b0000000, "slt", "slti">;
defm SLTU : ICMP<0b011, 0b0000000, "sltu", "sltiu">;

// Express the remaining ICMP predicates in terms of SLT/SLTU
multiclass ICMPPats<ValueType vt> {
  def : Pat<(i32 (setlt (vt GeneralPurposeRegisters:$rs1), (vt GeneralPurposeRegisters:$rs2))),
             (SLT GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)>;
  def : Pat<(i32 (setult (vt GeneralPurposeRegisters:$rs1), (vt GeneralPurposeRegisters:$rs2))),
             (SLTU GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)>;
  def : Pat<(i32 (setgt (vt GeneralPurposeRegisters:$rs1), (vt GeneralPurposeRegisters:$rs2))),
             (SLT GeneralPurposeRegisters:$rs2, GeneralPurposeRegisters:$rs1)>;
  def : Pat<(i32 (setugt (vt GeneralPurposeRegisters:$rs1), (vt GeneralPurposeRegisters:$rs2))),
             (SLTU GeneralPurposeRegisters:$rs2, GeneralPurposeRegisters:$rs1)>;
  def : Pat<(i32 (setge (vt GeneralPurposeRegisters:$rs1), (vt GeneralPurposeRegisters:$rs2))),
             (XORI (SLT GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2), 1)>;
  def : Pat<(i32 (setuge (vt GeneralPurposeRegisters:$rs1), (vt GeneralPurposeRegisters:$rs2))),
             (XORI (SLTU GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2), 1)>;
  def : Pat<(i32 (seteq (vt GeneralPurposeRegisters:$rs1), (vt GeneralPurposeRegisters:$rs2))),
             (SLTUI (XOR GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2), 1)>;
  def : Pat<(i32 (setne (vt GeneralPurposeRegisters:$rs1), (vt GeneralPurposeRegisters:$rs2))),
             (SLTU (i64 X0), (XOR GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2))>;
  def : Pat<(i32 (setle (vt GeneralPurposeRegisters:$rs1), (vt GeneralPurposeRegisters:$rs2))),
             (XORI (SLT GeneralPurposeRegisters:$rs2, GeneralPurposeRegisters:$rs1), 1)>;
  def : Pat<(i32 (setule (vt GeneralPurposeRegisters:$rs1), (vt GeneralPurposeRegisters:$rs2))),
             (XORI (SLTU GeneralPurposeRegisters:$rs2, GeneralPurposeRegisters:$rs1), 1)>;
}

defm : ICMPPats<i64>;
defm : ICMPPats<i32>;
defm : ICMPPats<iPTR>;

def LUI : InstRV64TypeU<0b0110111,
                    (outs GeneralPurposeRegisters:$rd),
                    (ins u20imm:$imm),
                    "lui $rd, $imm",
                    []>;

def AUIPC : InstRV64TypeU<0b0010111,
                    (outs GeneralPurposeRegisters:$rd),
                    (ins u20imm:$imm),
                    "auipc $rd, $imm",
                    []>;

// Load / store
multiclass LOAD_STORE<bits<3> func3, string typechar, bit hasUnsigned = 1> {
  def "L" # NAME : InstRV64TypeI<0b0000011, func3,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, i64imm:$imm),
                   "l"#typechar#" $rd, $imm($rs1)",
                   []>;

  if hasUnsigned then def "L" # NAME # "U" : InstRV64TypeI<0b0000011, !add(func3, 0b100),
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, i64imm:$imm),
                   "l"#typechar#"u $rd, $imm($rs1)",
                   []>;

  def "S" # NAME : InstRV64TypeS<0b0100011, func3,
                   (outs),
                   (ins GeneralPurposeRegisters:$rs1, i64imm:$imm, GeneralPurposeRegisters:$rs2),
                   "s"#typechar#" $rs2, $imm($rs1)",
                   []>;
}

defm B : LOAD_STORE<0b000, "b", 0>;
defm H : LOAD_STORE<0b001, "h", 0>;
defm W : LOAD_STORE<0b010, "w", 0>;
defm D : LOAD_STORE<0b011, "d", 1>;

// Control flow
def JAL : InstRV64TypeJ<0b1101111,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins BranchTargetOperand:$imm),
                   "jal $rd, $imm",
                   []>;

def PseudoBR : PseudoInstRV64<(outs), (ins BranchTargetOperand:$offset), "j $offset", []>,
               PseudoInstExpansion<(JAL X0, BranchTargetOperand:$offset)> {
  let isBranch = 1;
  let isTerminator = 1;
  let isBarrier = 1;
}

def : Pat<(br bb:$offset), (PseudoBR bb:$offset)>;
def : Pat<(ptradd GeneralPurposeRegisters:$rs1, (i64 GeneralPurposeRegisters:$rs2)),
           (ADD GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)>;

def JALR : InstRV64TypeI<0b1100111, 0b000,
                   (outs GeneralPurposeRegisters:$rd),
                   (ins GeneralPurposeRegisters:$rs1, i64imm:$imm),
                   "jalr $rd, $imm($rs1)",
                   []>;

multiclass BRCOND<bits<3> func3, string mnemonic> {
  def "" : InstRV64TypeB<0b1100011, func3,
                    (outs),
                    (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2, BranchTargetOperand:$imm),
                    mnemonic#" $rs1, $rs2, $imm",
                    []> {
    let isBranch = 1;
    let isTerminator = 1;
  }
}

defm BEQ : BRCOND<0b000, "beq">;
defm BNE : BRCOND<0b001, "bne">;
defm BLT : BRCOND<0b100, "blt">;
defm BGE : BRCOND<0b101, "bge">;
defm BLTU : BRCOND<0b110, "bltu">;
defm BGEU : BRCOND<0b111, "bgeu">;

// Pseudo insn for function return
def PseudoRet : PseudoInstRV64<(outs), (ins), "ret", []>,
                PseudoInstExpansion<(JALR X0, X1, 0)> {
  let isReturn = 1;
  let isTerminator = 1;
  let isBarrier = 1;
}

def PseudoCall : PseudoInstRV64<(outs), (ins CallTargetOperand:$function), "call $function", []>,
               PseudoInstExpansion<(JAL X1, BranchTargetOperand:$function)> {
  let isCall = 1;
  let Defs = [X1];
}

def PseudoCallIndirect : PseudoInstRV64<(outs), (ins GeneralPurposeRegisters:$rs1), "call $rs1", []>,
               PseudoInstExpansion<(JALR X1, GeneralPurposeRegisters:$rs1, 0)> {
  let isCall = 1;
  let Defs = [X1];
}

def PseudoBRIND : PseudoInstRV64<(outs), (ins GeneralPurposeRegisters:$rs1), "jr $rs1", []>,
               PseudoInstExpansion<(JALR X0, GeneralPurposeRegisters:$rs1, 0)> {
  let isBranch = 1;
  let isTerminator = 1;
  let isBarrier = 1;
  let isIndirectBranch = 1;
}

// ADJCALLSTACKDOWN / ADJCALLSTACKUP pseudo insns
let Defs = [X2], Uses = [X2], isCodeGenOnly = 1 in {
def ADJCALLSTACKDOWN : PseudoInstRV64<(outs), (ins i64imm:$amt1, i64imm:$amt2),
                              "#ADJCALLSTACKDOWN $amt1 $amt2",
                              []>;
def ADJCALLSTACKUP : PseudoInstRV64<(outs), (ins i64imm:$amt1, i64imm:$amt2),
                              "#ADJCALLSTACKUP $amt1 $amt2",
                              []>;
}

// M-extension
let Predicates = [RV64HasFeatureM] in {
  multiclass ALU_M_SUW<bits<3> sfunc3, bits<3> ufunc3, string mnemonic, SDPatternOperator snode, SDPatternOperator unode> {
    def "" : InstRV64TypeR<0b0110011, sfunc3, 0b0000001,
                    (outs GeneralPurposeRegisters:$rd),
                    (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                    mnemonic#" $rd, $rs1, $rs2",
                    [(set GeneralPurposeRegisters:$rd,
                          (i64 (snode GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)))]>;

    def U : InstRV64TypeR<0b0110011, ufunc3, 0b0000001,
                    (outs GeneralPurposeRegisters:$rd),
                    (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                    mnemonic#"u $rd, $rs1, $rs2",
                    [(set GeneralPurposeRegisters:$rd,
                          (i64 (unode GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)))]>;

    def W : InstRV64TypeR<0b0111011, sfunc3, 0b0000001,
                    (outs GeneralPurposeRegisters:$rd),
                    (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                    mnemonic#"w $rd, $rs1, $rs2",
                    [(set GeneralPurposeRegisters:$rd,
                          (i32 (snode GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)))]>;

    def UW : InstRV64TypeR<0b0111011, ufunc3, 0b0000001,
                    (outs GeneralPurposeRegisters:$rd),
                    (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                    mnemonic#"uw $rd, $rs1, $rs2",
                    [(set GeneralPurposeRegisters:$rd,
                          (i32 (unode GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)))]>;
  }

  defm DIV : ALU_M_SUW<0b100, 0b101, "div", sdiv, udiv>;
  defm REM : ALU_M_SUW<0b110, 0b111, "rem", srem, urem>;

  def MUL : InstRV64TypeR<0b0110011, 0b000, 0b0000001,
                    (outs GeneralPurposeRegisters:$rd),
                    (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                    "mul $rd, $rs1, $rs2",
                    [(set GeneralPurposeRegisters:$rd,
                          (i64 (mul GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)))]>;

  def MULW : InstRV64TypeR<0b0111011, 0b000, 0b0000001,
                    (outs GeneralPurposeRegisters:$rd),
                    (ins GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2),
                    "mulw $rd, $rs1, $rs2",
                    [(set GeneralPurposeRegisters:$rd,
                          (i32 (mul GeneralPurposeRegisters:$rs1, GeneralPurposeRegisters:$rs2)))]>;
}