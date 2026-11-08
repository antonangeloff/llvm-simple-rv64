; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

; Struct-valued arguments that fit entirely within the integer argument
; registers (no byval, no stack overflow).
%Pair = type { i64, i64 }
%Mixed = type { i32, i64 }

; Homogeneous: both fields are i64, so this is the "easy" case even under
; the current isSupportedType restriction -- %p's two fields flatten
; directly onto x10/x11, and extractvalue just picks the already-bound vreg
; for each field; no merge/unmerge or copy should be needed.
define i64 @sum_pair_arg(%Pair %p) {
; CHECK-LABEL: sum_pair_arg:
; CHECK: add x10, x10, x11
; CHECK: jalr x0, 0(x1)
entry:
  %a = extractvalue %Pair %p, 0
  %b = extractvalue %Pair %p, 1
  %r = add i64 %a, %b
  ret i64 %r
}

; Non-homogeneous: field 0 is i32, field 1 is i64. CC_RV64_LP64 promotes i32 to
; i64 before assignment, so field 0 still consumes a full register (x10)
define i64 @sum_mixed_arg(%Mixed %m) {
; CHECK-LABEL: sum_mixed_arg:
; CHECK: lui [[MASK:x[0-9]+]], 256
; CHECK: slli [[MASK]], [[MASK]], 12
; CHECK: addi [[MASK]], [[MASK]], -1
; CHECK: and x10, x10, [[MASK]]
; CHECK: add x10, x10, x11
; CHECK: jalr x0, 0(x1)
entry:
  %a = extractvalue %Mixed %m, 0
  %b = extractvalue %Mixed %m, 1
  %a64 = zext i32 %a to i64
  %r = add i64 %a64, %b
  ret i64 %r
}

; A struct argument mixed with a plain scalar argument, to check assignment
; order: %x should consume x10 first (declaration order), then %p's two
; fields take x11/x12.
define i64 @sum_pair_plus_scalar(i64 %x, %Pair %p) {
; CHECK-LABEL: sum_pair_plus_scalar:
; CHECK: add [[S:x[0-9]+]], x11, x12
; CHECK: add x10, [[S]], x10
; CHECK: jalr x0, 0(x1)
entry:
  %a = extractvalue %Pair %p, 0
  %b = extractvalue %Pair %p, 1
  %s = add i64 %a, %b
  %r = add i64 %s, %x
  ret i64 %r
}

; Call-site composition: build a struct value out of two scalars via
; insertvalue, then pass it by value
declare i64 @sum_pair_arg_decl(%Pair)

define i64 @call_sum_pair(i64 %x, i64 %y) {
; CHECK-LABEL: call_sum_pair:
; CHECK: addi x2, x2, -16
; CHECK: sd x1, 8(x2)
; CHECK: jal x1, sum_pair_arg_decl
; CHECK: ld x1, 8(x2)
; CHECK: addi x2, x2, 16
; CHECK: jalr x0, 0(x1)
entry:
  %p0 = insertvalue %Pair undef, i64 %x, 0
  %p1 = insertvalue %Pair %p0, i64 %y, 1
  %r = call i64 @sum_pair_arg_decl(%Pair %p1)
  ret i64 %r
}

; Nested aggregate argument: a field that is itself a struct
%Inner = type { i32, i64 }
%Outer = type { i64, %Inner }

define i64 @sum_nested_arg(%Outer %o) {
; CHECK-LABEL: sum_nested_arg:
; CHECK: lui [[MASK:x[0-9]+]], 256
; CHECK: slli [[MASK]], [[MASK]], 12
; CHECK: addi [[MASK]], [[MASK]], -1
; CHECK: and x11, x11, [[MASK]]
; CHECK: add x10, x10, x11
; CHECK: add x10, x10, x12
; CHECK: jalr x0, 0(x1)
entry:
  %a = extractvalue %Outer %o, 0
  %inner = extractvalue %Outer %o, 1
  %b = extractvalue %Inner %inner, 0
  %c = extractvalue %Inner %inner, 1
  %b64 = zext i32 %b to i64
  %s0 = add i64 %a, %b64
  %s1 = add i64 %s0, %c
  ret i64 %s1
}

; A direct (non-byval) struct argument large enough to exhaust CC_RV64_LP64's 8
; integer argument registers (X10-X17): 9 i64 fields need 9 register-sized
; slots, but only 8 registers exist, so the 9th field should overflow onto
; the stack via the existing CCAssignToStack<8,8> fallback
%Nine = type { i64, i64, i64, i64, i64, i64, i64, i64, i64 }

define i64 @read_nine_arg_overflow(%Nine %n) {
; CHECK-LABEL: read_nine_arg_overflow:
; CHECK: ld x10, 0(x2)
; CHECK: jalr x0, 0(x1)
entry:
  %v8 = extractvalue %Nine %n, 8
  ret i64 %v8
}

declare i64 @read_nine_arg_overflow_decl(%Nine)

define i64 @call_nine_arg_overflow(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, i64 %g, i64 %h, i64 %i) {
; CHECK-LABEL: call_nine_arg_overflow:
; CHECK: addi x2, x2, -{{[0-9]+}}
; CHECK: sd x1, {{[0-9]+}}(x2)
; CHECK: ld [[I:x[0-9]+]], 16(x2)
; CHECK: sd [[I]], 0(x2)
; CHECK: jal x1, read_nine_arg_overflow_decl
; CHECK: jalr x0, 0(x1)
entry:
  %n0 = insertvalue %Nine undef, i64 %a, 0
  %n1 = insertvalue %Nine %n0, i64 %b, 1
  %n2 = insertvalue %Nine %n1, i64 %c, 2
  %n3 = insertvalue %Nine %n2, i64 %d, 3
  %n4 = insertvalue %Nine %n3, i64 %e, 4
  %n5 = insertvalue %Nine %n4, i64 %f, 5
  %n6 = insertvalue %Nine %n5, i64 %g, 6
  %n7 = insertvalue %Nine %n6, i64 %h, 7
  %n8 = insertvalue %Nine %n7, i64 %i, 8
  %r = call i64 @read_nine_arg_overflow_decl(%Nine %n8)
  ret i64 %r
}
