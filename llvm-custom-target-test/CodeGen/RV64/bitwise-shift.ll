; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

define i64 @and_rr(i64 %a, i64 %b) {
; CHECK-LABEL: and_rr:
; CHECK: and x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = and i64 %a, %b
  ret i64 %r
}

define i64 @and_imm(i64 %a) {
; CHECK-LABEL: and_imm:
; CHECK: andi x10, x10, 255
; CHECK: jalr x0, 0(x1)
  %r = and i64 %a, 255
  ret i64 %r
}

define i64 @or_rr(i64 %a, i64 %b) {
; CHECK-LABEL: or_rr:
; CHECK: or x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = or i64 %a, %b
  ret i64 %r
}

define i64 @or_imm(i64 %a) {
; CHECK-LABEL: or_imm:
; CHECK: ori x10, x10, 1
; CHECK: jalr x0, 0(x1)
  %r = or i64 %a, 1
  ret i64 %r
}

define i64 @xor_rr(i64 %a, i64 %b) {
; CHECK-LABEL: xor_rr:
; CHECK: xor x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = xor i64 %a, %b
  ret i64 %r
}

define i64 @xor_imm(i64 %a) {
; CHECK-LABEL: xor_imm:
; CHECK: xori x10, x10, -1
; CHECK: jalr x0, 0(x1)
  %r = xor i64 %a, -1
  ret i64 %r
}

define i64 @shl_rr(i64 %a, i64 %b) {
; CHECK-LABEL: shl_rr:
; CHECK: sll x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = shl i64 %a, %b
  ret i64 %r
}

define i64 @shl_imm(i64 %a) {
; CHECK-LABEL: shl_imm:
; CHECK: slli x10, x10, 3
; CHECK: jalr x0, 0(x1)
  %r = shl i64 %a, 3
  ret i64 %r
}

define i64 @lshr_rr(i64 %a, i64 %b) {
; CHECK-LABEL: lshr_rr:
; CHECK: srl x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = lshr i64 %a, %b
  ret i64 %r
}

define i64 @lshr_imm(i64 %a) {
; CHECK-LABEL: lshr_imm:
; CHECK: srli x10, x10, 4
; CHECK: jalr x0, 0(x1)
  %r = lshr i64 %a, 4
  ret i64 %r
}

define i64 @ashr_rr(i64 %a, i64 %b) {
; CHECK-LABEL: ashr_rr:
; CHECK: sra x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = ashr i64 %a, %b
  ret i64 %r
}

define i64 @ashr_imm(i64 %a) {
; CHECK-LABEL: ashr_imm:
; CHECK: srai x10, x10, 5
; CHECK: jalr x0, 0(x1)
  %r = ashr i64 %a, 5
  ret i64 %r
}

define i32 @and_rr_i32(i32 %a, i32 %b) {
; CHECK-LABEL: and_rr_i32:
; CHECK: and x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = and i32 %a, %b
  ret i32 %r
}

define i32 @and_imm_i32(i32 %a) {
; CHECK-LABEL: and_imm_i32:
; CHECK: addi [[T:x[0-9]+]], x0, 255
; CHECK: and x10, x10, [[T]]
; CHECK: jalr x0, 0(x1)
  %r = and i32 %a, 255
  ret i32 %r
}

define i32 @or_rr_i32(i32 %a, i32 %b) {
; CHECK-LABEL: or_rr_i32:
; CHECK: or x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = or i32 %a, %b
  ret i32 %r
}

define i32 @or_imm_i32(i32 %a) {
; CHECK-LABEL: or_imm_i32:
; CHECK: addi [[T:x[0-9]+]], x0, 1
; CHECK: or x10, x10, [[T]]
; CHECK: jalr x0, 0(x1)
  %r = or i32 %a, 1
  ret i32 %r
}

define i32 @xor_rr_i32(i32 %a, i32 %b) {
; CHECK-LABEL: xor_rr_i32:
; CHECK: xor x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = xor i32 %a, %b
  ret i32 %r
}

define i32 @xor_imm_i32(i32 %a) {
; CHECK-LABEL: xor_imm_i32:
; CHECK: addi [[T:x[0-9]+]], x0, -1
; CHECK: xor x10, x10, [[T]]
; CHECK: jalr x0, 0(x1)
  %r = xor i32 %a, -1
  ret i32 %r
}

define i32 @shl_rr_i32(i32 %a, i32 %b) {
; CHECK-LABEL: shl_rr_i32:
; CHECK: sllw x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = shl i32 %a, %b
  ret i32 %r
}

define i32 @shl_imm_i32(i32 %a) {
; CHECK-LABEL: shl_imm_i32:
; CHECK: slliw x10, x10, 3
; CHECK: jalr x0, 0(x1)
  %r = shl i32 %a, 3
  ret i32 %r
}

define i32 @lshr_rr_i32(i32 %a, i32 %b) {
; CHECK-LABEL: lshr_rr_i32:
; CHECK: srlw x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = lshr i32 %a, %b
  ret i32 %r
}

define i32 @lshr_imm_i32(i32 %a) {
; CHECK-LABEL: lshr_imm_i32:
; CHECK: srliw x10, x10, 4
; CHECK: jalr x0, 0(x1)
  %r = lshr i32 %a, 4
  ret i32 %r
}

define i32 @ashr_rr_i32(i32 %a, i32 %b) {
; CHECK-LABEL: ashr_rr_i32:
; CHECK: sraw x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = ashr i32 %a, %b
  ret i32 %r
}

define i32 @ashr_imm_i32(i32 %a) {
; CHECK-LABEL: ashr_imm_i32:
; CHECK: sraiw x10, x10, 5
; CHECK: jalr x0, 0(x1)
  %r = ashr i32 %a, 5
  ret i32 %r
}
