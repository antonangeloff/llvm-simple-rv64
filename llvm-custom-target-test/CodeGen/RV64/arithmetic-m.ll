; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

; Plain register-register multiply. Mul is commutative in IR, but the
; pattern's rs1/rs2 binding is still expected to mirror operand order the way
; ADD's RR form does.
define i64 @mul_rr(i64 %a, i64 %b) {
; CHECK-LABEL: mul_rr:
; CHECK: mul x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = mul i64 %a, %b
  ret i64 %r
}

; Signed division. Unlike add/mul, div/rem are not commutative, so operand
; order (dividend first, divisor second) must be preserved exactly: rs1=%a
; (dividend, x10), rs2=%b (divisor, x11).
define i64 @sdiv_rr(i64 %a, i64 %b) {
; CHECK-LABEL: sdiv_rr:
; CHECK: div x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = sdiv i64 %a, %b
  ret i64 %r
}

; Unsigned division.
define i64 @udiv_rr(i64 %a, i64 %b) {
; CHECK-LABEL: udiv_rr:
; CHECK: divu x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = udiv i64 %a, %b
  ret i64 %r
}

; Signed remainder.
define i64 @srem_rr(i64 %a, i64 %b) {
; CHECK-LABEL: srem_rr:
; CHECK: rem x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = srem i64 %a, %b
  ret i64 %r
}

; Unsigned remainder.
define i64 @urem_rr(i64 %a, i64 %b) {
; CHECK-LABEL: urem_rr:
; CHECK: remu x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = urem i64 %a, %b
  ret i64 %r
}

; Multiply by an immediate: unlike ADD, there is no MULI - RV64M has no
; immediate-operand form for any of these five ops - so even a trivially
; small constant (here 7, well within the 12-bit ADDI range) must always be
; materialized into its own register first (same single-ADDI-with-x0 shape
; ret_i64 in ret-int-constant.ll exercises), then fed to the register-register
; MUL form. No combine can fold this away the way sub_to_add folds SUB into
; ADDI, since there's no MULI target for it to fold into.
define i64 @mul_imm(i64 %a) {
; CHECK-LABEL: mul_imm:
; CHECK: addi [[T:x[0-9]+]], x0, 7
; CHECK: mul x10, x10, [[T]]
; CHECK: jalr x0, 0(x1)
  %r = mul i64 %a, 7
  ret i64 %r
}

; i32 counterparts of the five register-register cases above: these are the
; ones that actually exercise width-based dispatch, since MUL/DIV/DIVU/REM/REMU
; only exist as 64-bit forms - an i32 op here must select the *W-suffixed
; instruction instead (MULW/DIVW/DIVUW/REMW/REMUW), which is exactly the
; GeneralPurposeRegisters-dual-VT + per-operand-(i64/i32 ...)-wrapping work
; this file's sibling .td changes are threading through. Calling-convention-
; wise, an i32 argument still arrives in the low bits of the same a0/a1 (x10/
; x11) registers as the i64 case - width is a property of the operation
; selected, not of which physical register holds the value.
define i32 @mul_rr_i32(i32 %a, i32 %b) {
; CHECK-LABEL: mul_rr_i32:
; CHECK: mulw x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = mul i32 %a, %b
  ret i32 %r
}

define i32 @sdiv_rr_i32(i32 %a, i32 %b) {
; CHECK-LABEL: sdiv_rr_i32:
; CHECK: divw x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = sdiv i32 %a, %b
  ret i32 %r
}

define i32 @udiv_rr_i32(i32 %a, i32 %b) {
; CHECK-LABEL: udiv_rr_i32:
; CHECK: divuw x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = udiv i32 %a, %b
  ret i32 %r
}

define i32 @srem_rr_i32(i32 %a, i32 %b) {
; CHECK-LABEL: srem_rr_i32:
; CHECK: remw x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = srem i32 %a, %b
  ret i32 %r
}

define i32 @urem_rr_i32(i32 %a, i32 %b) {
; CHECK-LABEL: urem_rr_i32:
; CHECK: remuw x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = urem i32 %a, %b
  ret i32 %r
}
