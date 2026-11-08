; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

; Smallest value just above the 12-bit ADDI range (2048 = 0x800).
define i32 @ret_i32_boundary() {
; CHECK-LABEL: ret_i32_boundary:
; CHECK: lui x10, 1
; CHECK: addiw x10, x10, -2048
; CHECK: jalr x0, 0(x1)
  ret i32 2048
}

; Largest-magnitude negative value that still fits a single ADDI (mirror of
; the positive boundary above).
define i32 @ret_i32_negative_boundary() {
; CHECK-LABEL: ret_i32_negative_boundary:
; CHECK: lui x10, 1048575
; CHECK: addiw x10, x10, 2047
; CHECK: jalr x0, 0(x1)
  ret i32 -2049
}

; Larger positive value, well outside the 12-bit range.
define i32 @ret_i32_large() {
; CHECK-LABEL: ret_i32_large:
; CHECK: lui x10, 244
; CHECK: addiw x10, x10, 576
; CHECK: jalr x0, 0(x1)
  ret i32 1000000
}

; Largest positive value representable as a 32-bit signed int. The +0x800
; Hi20 rounding compensation crosses bit 31 here, which is exactly why the
; low-immediate add must be ADDIW (32-bit add, re-sign-extended) rather than
; a plain 64-bit ADDI - the latter would produce 0xFFFFFFFF7FFFFFFF instead
; of the correct 0x000000007FFFFFFF.
define i32 @ret_i32_int32_max() {
; CHECK-LABEL: ret_i32_int32_max:
; CHECK: lui x10, 524288
; CHECK: addiw x10, x10, -1
; CHECK: jalr x0, 0(x1)
  ret i32 2147483647
}

; Exact multiple of 4096: LUI alone supplies the full value (Lo12 == 0).
; Whether the selector elides a redundant `addi x10, x10, 0` or always emits
; one is an open implementation choice, so only the LUI and the final jalr
; are checked here - no CHECK line constrains what (if anything) comes
; between them.
define i32 @ret_i32_exact_multiple() {
; CHECK-LABEL: ret_i32_exact_multiple:
; CHECK: lui x10, 1
; CHECK: jalr x0, 0(x1)
  ret i32 4096
}

; Same boundary value as an i64 return, to confirm width doesn't change
; wide-immediate materialization.
define i64 @ret_i64_boundary() {
; CHECK-LABEL: ret_i64_boundary:
; CHECK: lui x10, 1
; CHECK: addiw x10, x10, -2048
; CHECK: jalr x0, 0(x1)
  ret i64 2048
}

; Negative value outside the 12-bit range.
define i32 @ret_i32_negative() {
; CHECK-LABEL: ret_i32_negative:
; CHECK: lui x10, 1048552
; CHECK: addiw x10, x10, -1696
; CHECK: jalr x0, 0(x1)
  ret i32 -100000
}

; Genuinely wide (>32-bit) constants, requiring the SLLI-based unwind loop
; on top of the LUI+ADDIW base case.

; 2^32 exactly: one loop iteration with a zero chunk, and a zero immAddi in
; the base case - both the ADDIW and the unwind ADDI are elided.
define i64 @ret_i64_pow2_32() {
; CHECK-LABEL: ret_i64_pow2_32:
; CHECK: lui x10, 256
; CHECK: slli x10, x10, 12
; CHECK: jalr x0, 0(x1)
  ret i64 4294967296
}

; 2^32 + 1: one loop iteration with a nonzero (positive) chunk, but the
; base case's immAddi is still zero - ADDIW elided, unwind ADDI present.
define i64 @ret_i64_pow2_32_plus1() {
; CHECK-LABEL: ret_i64_pow2_32_plus1:
; CHECK: lui x10, 256
; CHECK: slli x10, x10, 12
; CHECK: addi x10, x10, 1
; CHECK: jalr x0, 0(x1)
  ret i64 4294967297
}

; One loop iteration where both the base case's immAddi and the unwound
; chunk are nonzero - every instruction in the sequence is present,
; including a negative (sign-flipped) chunk from the loop.
define i64 @ret_i64_one_step_full() {
; CHECK-LABEL: ret_i64_one_step_full:
; CHECK: lui x10, 256
; CHECK: addiw x10, x10, 1
; CHECK: slli x10, x10, 12
; CHECK: addi x10, x10, -2047
; CHECK: jalr x0, 0(x1)
  ret i64 4294969345
}

; Worst-case-shaped 64-bit pattern (no repeated-halves or other special
; structure to exploit): three loop iterations, full 8-instruction
; sequence, including one negative chunk.
define i64 @ret_i64_three_steps() {
; CHECK-LABEL: ret_i64_three_steps:
; CHECK: lui x10, 4660
; CHECK: addiw x10, x10, 1384
; CHECK: slli x10, x10, 12
; CHECK: addi x10, x10, -2030
; CHECK: slli x10, x10, 12
; CHECK: addi x10, x10, 837
; CHECK: slli x10, x10, 12
; CHECK: addi x10, x10, 1656
; CHECK: jalr x0, 0(x1)
  ret i64 1311768465173141112
}
