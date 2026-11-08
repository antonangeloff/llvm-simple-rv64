; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

; Struct-valued return values that fit entirely within the return registers
; (x10/x11)

%Pair = type { i64, i64 }
%Mixed = type { i32, i64 }

define %Pair @make_pair(i64 %a, i64 %b) {
; CHECK-LABEL: make_pair:
; CHECK: jalr x0, 0(x1)
entry:
  %p0 = insertvalue %Pair undef, i64 %a, 0
  %p1 = insertvalue %Pair %p0, i64 %b, 1
  ret %Pair %p1
}

define %Mixed @make_mixed(i32 %a, i64 %b) {
; CHECK-LABEL: make_mixed:
; CHECK: jalr x0, 0(x1)
entry:
  %m0 = insertvalue %Mixed undef, i32 %a, 0
  %m1 = insertvalue %Mixed %m0, i64 %b, 1
  ret %Mixed %m1
}

declare %Pair @make_pair_decl(i64, i64)

define i64 @call_make_pair(i64 %x, i64 %y) {
; CHECK-LABEL: call_make_pair:
; CHECK: jal x1, make_pair_decl
; CHECK: add x10, x10, x11
; CHECK: jalr x0, 0(x1)
entry:
  %p = call %Pair @make_pair_decl(i64 %x, i64 %y)
  %a = extractvalue %Pair %p, 0
  %b = extractvalue %Pair %p, 1
  %r = add i64 %a, %b
  ret i64 %r
}

; Nested aggregate return: an outer struct wrapping an inner struct, still
; small enough to fit in the return registers (2 leaves total, same as
; %Pair alone)
%NestedPair = type { %Pair }

define %NestedPair @make_nested_pair(i64 %a, i64 %b) {
; CHECK-LABEL: make_nested_pair:
; CHECK: jalr x0, 0(x1)
entry:
  %p0 = insertvalue %Pair undef, i64 %a, 0
  %p1 = insertvalue %Pair %p0, i64 %b, 1
  %n0 = insertvalue %NestedPair undef, %Pair %p1, 0
  ret %NestedPair %n0
}
