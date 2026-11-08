//===-- RV64RegisterInfo.td - RV64 Register defs ------------*- tablegen -*-===//
// todo : review

//===----------------------------------------------------------------------===//
//  Declarations that describe the RV64 register file
//===----------------------------------------------------------------------===//

def AltNameABI : RegAltNameIndex;

class RV64Reg<bits<5> enc, string n, list<string> altNames = []> : Register<n> {
  let HWEncoding{4-0} = enc;
  let Namespace = "RV";
  let AltNames = altNames;
  let RegAltNameIndices = [AltNameABI];
}

// Define registers x0-x31
def X0 : RV64Reg<0, "x0", ["zero"]>, DwarfRegNum<[0]> { let isConstant = true; }
def X1 : RV64Reg<1, "x1", ["ra"]>, DwarfRegNum<[1]>;
def X2 : RV64Reg<2, "x2", ["sp"]>, DwarfRegNum<[2]>;
def X3 : RV64Reg<3, "x3", ["gp"]>, DwarfRegNum<[3]>;
def X4 : RV64Reg<4, "x4", ["tp"]>, DwarfRegNum<[4]>;
def X5 : RV64Reg<5, "x5", ["t0"]>, DwarfRegNum<[5]>;
def X6 : RV64Reg<6, "x6", ["t1"]>, DwarfRegNum<[6]>;
def X7 : RV64Reg<7, "x7", ["t2"]>, DwarfRegNum<[7]>;
def X8 : RV64Reg<8, "x8", ["s0", "fp"]>, DwarfRegNum<[8]>;
def X9 : RV64Reg<9, "x9", ["s1"]>, DwarfRegNum<[9]>;
def X10 : RV64Reg<10,"x10", ["a0"]>, DwarfRegNum<[10]>;
def X11 : RV64Reg<11,"x11", ["a1"]>, DwarfRegNum<[11]>;
def X12 : RV64Reg<12,"x12", ["a2"]>, DwarfRegNum<[12]>;
def X13 : RV64Reg<13,"x13", ["a3"]>, DwarfRegNum<[13]>;
def X14 : RV64Reg<14,"x14", ["a4"]>, DwarfRegNum<[14]>;
def X15 : RV64Reg<15,"x15", ["a5"]>, DwarfRegNum<[15]>;
def X16 : RV64Reg<16,"x16", ["a6"]>, DwarfRegNum<[16]>;
def X17 : RV64Reg<17,"x17", ["a7"]>, DwarfRegNum<[17]>;
def X18 : RV64Reg<18,"x18", ["s2"]>, DwarfRegNum<[18]>;
def X19 : RV64Reg<19,"x19", ["s3"]>, DwarfRegNum<[19]>;
def X20 : RV64Reg<20,"x20", ["s4"]>, DwarfRegNum<[20]>;
def X21 : RV64Reg<21,"x21", ["s5"]>, DwarfRegNum<[21]>;
def X22 : RV64Reg<22,"x22", ["s6"]>, DwarfRegNum<[22]>;
def X23 : RV64Reg<23,"x23", ["s7"]>, DwarfRegNum<[23]>;
def X24 : RV64Reg<24,"x24", ["s8"]>, DwarfRegNum<[24]>;
def X25 : RV64Reg<25,"x25", ["s9"]>, DwarfRegNum<[25]>;
def X26 : RV64Reg<26,"x26", ["s10"]>, DwarfRegNum<[26]>;
def X27 : RV64Reg<27,"x27", ["s11"]>, DwarfRegNum<[27]>;
def X28 : RV64Reg<28,"x28", ["t3"]>, DwarfRegNum<[28]>;
def X29 : RV64Reg<29,"x29", ["t4"]>, DwarfRegNum<[29]>;
def X30 : RV64Reg<30,"x30", ["t5"]>, DwarfRegNum<[30]>;
def X31 : RV64Reg<31,"x31", ["t6"]>, DwarfRegNum<[31]>;

// Register classes
def GeneralPurposeRegisters : RegisterClass<"RV", [i64, i32], XLEN, (add
  (sequence "X%u", 10, 17), // a0 .. a7
  (sequence "X%u", 5, 7),   // t0 .. t2
  (sequence "X%u", 28, 31), // t3 .. t6
  (sequence "X%u", 8, 9),   // s0 .. s1
  (sequence "X%u", 18, 27), // s2 .. s11
  (sequence "X%u", 0, 4)   // zero, ra, sp, gp, tp
)>;