; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

%Big = type { i64, i64, i64 }

define %Big @make_big(i64 %a, i64 %b, i64 %c) {
; CHECK-LABEL: make_big:
; CHECK: sd x11, 0(x10)
; CHECK: sd x12, 8(x10)
; CHECK: sd x13, 16(x10)
; CHECK: jalr x0, 0(x1)
entry:
  %b0 = insertvalue %Big undef, i64 %a, 0
  %b1 = insertvalue %Big %b0, i64 %b, 1
  %b2 = insertvalue %Big %b1, i64 %c, 2
  ret %Big %b2
}

; Caller side: per insertSRetOutgoingArgument, the caller allocates its own
; stack object for the result, passes its address as the hidden first
; argument (shifting %a/%b/%c to x11/x12/x13), and after the call reads the
; three fields back through its own tracked DemoteRegister
declare %Big @make_big_decl(i64, i64, i64)

define i64 @call_make_big(i64 %a, i64 %b, i64 %c) {
; CHECK-LABEL: call_make_big:
; CHECK: addi x2, x2, -{{[0-9]+}}
; CHECK: sd x1, {{[0-9]+}}(x2)
; CHECK: addi x10, x2, 0
; CHECK: jal x1, make_big_decl
; CHECK: ld [[V0:x[0-9]+]], 0(x2)
; CHECK: ld [[V1:x[0-9]+]], 8(x2)
; CHECK: ld [[V2:x[0-9]+]], 16(x2)
; CHECK: add [[S0:x[0-9]+]], [[V0]], [[V1]]
; CHECK: add x10, [[S0]], [[V2]]
; CHECK: jalr x0, 0(x1)
entry:
  %r = call %Big @make_big_decl(i64 %a, i64 %b, i64 %c)
  %v0 = extractvalue %Big %r, 0
  %v1 = extractvalue %Big %r, 1
  %v2 = extractvalue %Big %r, 2
  %s0 = add i64 %v0, %v1
  %s1 = add i64 %s0, %v2
  ret i64 %s1
}

; Boundary case for canLowerReturn itself - {i32,i32,i32} is 12 real bytes - 
; small enough to "fit" in 2x64-bit registers if its fields were packed.
%Triple32 = type { i32, i32, i32 }

define %Triple32 @make_triple32(i32 %a, i32 %b, i32 %c) {
; CHECK-LABEL: make_triple32:
; CHECK: sw x11, 0(x10)
; CHECK: sw x12, 4(x10)
; CHECK: sw x13, 8(x10)
; CHECK: jalr x0, 0(x1)
entry:
  %t0 = insertvalue %Triple32 undef, i32 %a, 0
  %t1 = insertvalue %Triple32 %t0, i32 %b, 1
  %t2 = insertvalue %Triple32 %t1, i32 %c, 2
  ret %Triple32 %t2
}

; Zero real IR parameters, but still one real argument once sret demotion
; kicks in: the hidden pointer
define %Big @make_nothing() {
; CHECK-LABEL: make_nothing:
; CHECK: addi [[Z:x[0-9]+]], x0, 0
; CHECK: sd [[Z]], 0(x10)
; CHECK: sd [[Z]], 8(x10)
; CHECK: sd [[Z]], 16(x10)
; CHECK: jalr x0, 0(x1)
entry:
  ret %Big zeroinitializer
}

declare %Big @make_nothing_decl()

define i64 @call_make_nothing() {
; CHECK-LABEL: call_make_nothing:
; CHECK: addi x2, x2, -{{[0-9]+}}
; CHECK: sd x1, {{[0-9]+}}(x2)
; CHECK: addi x10, x2, 0
; CHECK: jal x1, make_nothing_decl
; CHECK: ld [[V0:x[0-9]+]], 0(x2)
; CHECK: ld [[V1:x[0-9]+]], 8(x2)
; CHECK: add x10, [[V0]], [[V1]]
; CHECK: jalr x0, 0(x1)
entry:
  %r = call %Big @make_nothing_decl()
  %v0 = extractvalue %Big %r, 0
  %v1 = extractvalue %Big %r, 1
  %r0 = add i64 %v0, %v1
  ret i64 %r0
}
