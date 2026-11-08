//===-- RV64InstrFormats.td - RV64 Instruction Formats -----*- tablegen -*-===//

// Base class for instructions
class InstRV64<dag outs, dag ins, string asmstr, list<dag> pattern>
  : Instruction {

  field bits<32> Inst;
  let Size = 4;
  let Namespace = "RV";
  let DecoderNamespace = "RV";

  // RV64OpClass RV64Class;
  // let Inst{58-56} = RV64Class.Value;

  dag OutOperandList = outs;
  dag InOperandList = ins;
  let AsmString = asmstr;
  let Pattern = pattern;
}

// Type-R instruction - register-to-register operations
class InstRV64TypeR<bits<7> opcode, bits<3> func3, bits<7> func7, dag outs, dag ins, string asmstr, list<dag> pattern>
  : InstRV64<outs, ins, asmstr, pattern> {
  
  bits<5> rd;
  bits<5> rs1;
  bits<5> rs2;

  let Inst{31-25} = func7;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = func3;
  let Inst{11-7} = rd;
  let Inst{6-0} = opcode;
}

// Type-I instruction - short immediates and loads
class InstRV64TypeI<bits<7> opcode, bits<3> func3, dag outs, dag ins, string asmstr, list<dag> pattern>
  : InstRV64<outs, ins, asmstr, pattern> {
  
  bits<5> rd;
  bits<5> rs1;
  bits<12> imm;

  let Inst{31-20} = imm;
  let Inst{19-15} = rs1;
  let Inst{14-12} = func3;
  let Inst{11-7} = rd;
  let Inst{6-0} = opcode;
}

// Type-S instruction - store operations
class InstRV64TypeS<bits<7> opcode, bits<3> func3, dag outs, dag ins, string asmstr, list<dag> pattern>
  : InstRV64<outs, ins, asmstr, pattern> {
  
  bits<5> rs1;
  bits<5> rs2;
  bits<12> imm;

  let Inst{31-25} = imm{11-5};
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = func3;
  let Inst{11-7} = imm{4-0};
  let Inst{6-0} = opcode;
}

// Type-B instruction - branches
class InstRV64TypeB<bits<7> opcode, bits<3> func3, dag outs, dag ins, string asmstr, list<dag> pattern>
  : InstRV64<outs, ins, asmstr, pattern> {
  
  bits<5> rs1;
  bits<5> rs2;
  bits<13> imm;

  let Inst{31} = imm{12};
  let Inst{30-25} = imm{10-5};
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = func3;
  let Inst{11-8} = imm{4-1};
  let Inst{7} = imm{11};
  let Inst{6-0} = opcode;
}

// Type-U instruction - upper immediate
class InstRV64TypeU<bits<7> opcode, dag outs, dag ins, string asmstr, list<dag> pattern>
  : InstRV64<outs, ins, asmstr, pattern> {
  
  bits<5> rd;
  bits<20> imm;

  let Inst{31-12} = imm;
  let Inst{11-7} = rd;
  let Inst{6-0} = opcode;
}

// Type-J instruction - unconditional jumps
class InstRV64TypeJ<bits<7> opcode, dag outs, dag ins, string asmstr, list<dag> pattern>
  : InstRV64<outs, ins, asmstr, pattern> {
  
  bits<5> rd;
  bits<21> imm;

  let Inst{31} = imm{20};
  let Inst{30-21} = imm{10-1};
  let Inst{20} = imm{11};
  let Inst{19-12} = imm{19-12};
  let Inst{11-7} = rd;
  let Inst{6-0} = opcode;
}

class InstRV64Atomic<bits<7> opcode, bits<3> func3, bits<1> aq, bits<1> rl, bits<5> func5, dag outs, dag ins, string asmstr, list<dag> pattern>
  : InstRV64<outs, ins, asmstr, pattern> {
  
  bits<5> rd;
  bits<5> rs1;
  bits<5> rs2;

  let Inst{31-27} = func5;
  let Inst{26} = aq;
  let Inst{25} = rl;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = func3;
  let Inst{11-7} = rd;
  let Inst{6-0} = opcode;
}

// todo: derive from InstRV64TypeI..
class InstRV64TypeIShift<bits<7> opcode, bits<3> func3, bits<6> disc, dag outs, dag ins, string asmstr, list<dag> pattern>
  : InstRV64<outs, ins, asmstr, pattern> {
  
  bits<5> rd;
  bits<5> rs1;
  bits<12> imm;
  bits<6> shamt;

  let imm{11-6} = disc;
  let imm{5-0} = shamt;

  let Inst{31-20} = imm;
  let Inst{19-15} = rs1;
  let Inst{14-12} = func3;
  let Inst{11-7} = rd;
  let Inst{6-0} = opcode;
}

// Pseudo instructions
class PseudoInstRV64<dag outs, dag ins, string asmstr, list<dag> pattern>
  : InstRV64<outs, ins, asmstr, pattern> {

  let Inst{31-0} = 0;
  let isPseudo = 1;
}
