; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

define double @add_d(double %a, double %b) {
; CHECK-LABEL: add_d:
; CHECK: jal x1, __adddf3
entry:
  %r = fadd double %a, %b
  ret double %r
}

define float @add_f(float %a, float %b) {
; CHECK-LABEL: add_f:
; CHECK: jal x1, __addsf3
entry:
  %r = fadd float %a, %b
  ret float %r
}

define double @sub_d(double %a, double %b) {
; CHECK-LABEL: sub_d:
; CHECK: jal x1, __subdf3
entry:
  %r = fsub double %a, %b
  ret double %r
}

define double @mul_d(double %a, double %b) {
; CHECK-LABEL: mul_d:
; CHECK: jal x1, __muldf3
entry:
  %r = fmul double %a, %b
  ret double %r
}

define double @div_d(double %a, double %b) {
; CHECK-LABEL: div_d:
; CHECK: jal x1, __divdf3
entry:
  %r = fdiv double %a, %b
  ret double %r
}

; Negation is a pure sign-bit flip
define double @neg_d(double %a) {
; CHECK-LABEL: neg_d:
; CHECK: lui [[M:x[0-9]+]], 1015808
; CHECK: slli [[M]], [[M]], 12
; CHECK: slli [[M]], [[M]], 12
; CHECK: slli [[M]], [[M]], 12
; CHECK: xor x10, x10, [[M]]
; CHECK: jalr x0, 0(x1)
entry:
  %r = fneg double %a
  ret double %r
}

; A float constant materializes as a plain integer constant carrying the
; same bits
define double @const_d() {
; CHECK-LABEL: const_d:
; CHECK: lui x10, 16396
; CHECK: slli x10, x10, 12
; CHECK: slli x10, x10, 12
; CHECK: slli x10, x10, 12
; CHECK: jalr x0, 0(x1)
entry:
  ret double 3.500000e+00
}

define i32 @cmp_oeq(double %a, double %b) {
; CHECK-LABEL: cmp_oeq:
; CHECK: jal x1, __eqdf2
; CHECK: addi [[Z:x[0-9]+]], x0, 0
; CHECK: xor x10, x10, [[Z]]
; CHECK: sltiu x10, x10, 1
entry:
  %c = fcmp oeq double %a, %b
  %r = zext i1 %c to i32
  ret i32 %r
}

define i32 @cmp_une(double %a, double %b) {
; CHECK-LABEL: cmp_une:
; CHECK: jal x1, __nedf2
; CHECK: addi [[Z:x[0-9]+]], x0, 0
; CHECK: xor x10, x10, [[Z]]
; CHECK: sltu x10, x0, x10
entry:
  %c = fcmp une double %a, %b
  %r = zext i1 %c to i32
  ret i32 %r
}

define i32 @cmp_olt(double %a, double %b) {
; CHECK-LABEL: cmp_olt:
; CHECK: jal x1, __ltdf2
; CHECK: addi [[Z:x[0-9]+]], x0, 0
; CHECK: slt x10, x10, [[Z]]
entry:
  %c = fcmp olt double %a, %b
  %r = zext i1 %c to i32
  ret i32 %r
}

define i32 @cmp_ole(double %a, double %b) {
; CHECK-LABEL: cmp_ole:
; CHECK: jal x1, __ledf2
; CHECK: addi [[Z:x[0-9]+]], x0, 0
; CHECK: slt x10, [[Z]], x10
; CHECK: xori x10, x10, 1
entry:
  %c = fcmp ole double %a, %b
  %r = zext i1 %c to i32
  ret i32 %r
}

define i32 @cmp_ogt(double %a, double %b) {
; CHECK-LABEL: cmp_ogt:
; CHECK: jal x1, __gtdf2
; CHECK: addi [[Z:x[0-9]+]], x0, 0
; CHECK: slt x10, [[Z]], x10
entry:
  %c = fcmp ogt double %a, %b
  %r = zext i1 %c to i32
  ret i32 %r
}

define i32 @cmp_oge(double %a, double %b) {
; CHECK-LABEL: cmp_oge:
; CHECK: jal x1, __gedf2
; CHECK: addi [[Z:x[0-9]+]], x0, 0
; CHECK: slt x10, x10, [[Z]]
; CHECK: xori x10, x10, 1
entry:
  %c = fcmp oge double %a, %b
  %r = zext i1 %c to i32
  ret i32 %r
}

define double @sitofp_d(i32 %a) {
; CHECK-LABEL: sitofp_d:
; CHECK: slli x10, x10, 32
; CHECK: srai x10, x10, 32
; CHECK: jal x1, __floatsidf
entry:
  %r = sitofp i32 %a to double
  ret double %r
}

define double @uitofp_d(i32 %a) {
; CHECK-LABEL: uitofp_d:
; CHECK: lui [[M:x[0-9]+]], 256
; CHECK: slli [[M]], [[M]], 12
; CHECK: addi [[M]], [[M]], -1
; CHECK: and x10, x10, [[M]]
; CHECK: jal x1, __floatunsidf
entry:
  %r = uitofp i32 %a to double
  ret double %r
}

define i32 @fptosi_d(double %a) {
; CHECK-LABEL: fptosi_d:
; CHECK: jal x1, __fixdfsi
entry:
  %r = fptosi double %a to i32
  ret i32 %r
}

define i32 @fptoui_d(double %a) {
; CHECK-LABEL: fptoui_d:
; CHECK: jal x1, __fixunsdfsi
entry:
  %r = fptoui double %a to i32
  ret i32 %r
}

define double @fpext_fd(float %a) {
; CHECK-LABEL: fpext_fd:
; CHECK: jal x1, __extendsfdf2
entry:
  %r = fpext float %a to double
  ret double %r
}

define float @fptrunc_df(double %a) {
; CHECK-LABEL: fptrunc_df:
; CHECK: jal x1, __truncdfsf2
entry:
  %r = fptrunc double %a to float
  ret float %r
}
