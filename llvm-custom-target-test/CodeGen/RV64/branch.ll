; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

define void @loop_forever() {
; CHECK-LABEL: loop_forever:
; CHECK: jal x0, [[LOOP:\.LBB[0-9]+_[0-9]+]]
; CHECK: [[LOOP]]:
; CHECK: jal x0, [[LOOP]]
entry:
  br label %loop
loop:
  br label %loop
}

define i64 @select_min(i64 %a, i64 %b) {
; CHECK-LABEL: select_min:
; CHECK: b{{eq|ne|lt|ge|ltu|geu}} x10, x11, [[TARGET:\.LBB[0-9]+_[0-9]+]]
entry:
  %cmp = icmp slt i64 %a, %b
  br i1 %cmp, label %a_lt_b, label %b_le_a
a_lt_b:
  ret i64 %a
b_le_a:
  ret i64 %b
}

define i64 @sel_eq(i64 %a, i64 %b) {
; CHECK-LABEL: sel_eq:
; CHECK: beq x10, x11, [[TARGET:\.LBB[0-9]+_[0-9]+]]
entry:
  %cmp = icmp eq i64 %a, %b
  br i1 %cmp, label %t, label %f
t:
  ret i64 %a
f:
  ret i64 %b
}

define i64 @sel_ne(i64 %a, i64 %b) {
; CHECK-LABEL: sel_ne:
; CHECK: bne x10, x11, [[TARGET:\.LBB[0-9]+_[0-9]+]]
entry:
  %cmp = icmp ne i64 %a, %b
  br i1 %cmp, label %t, label %f
t:
  ret i64 %a
f:
  ret i64 %b
}

define i64 @sel_sge(i64 %a, i64 %b) {
; CHECK-LABEL: sel_sge:
; CHECK: bge x10, x11, [[TARGET:\.LBB[0-9]+_[0-9]+]]
entry:
  %cmp = icmp sge i64 %a, %b
  br i1 %cmp, label %t, label %f
t:
  ret i64 %a
f:
  ret i64 %b
}

define i64 @sel_ult(i64 %a, i64 %b) {
; CHECK-LABEL: sel_ult:
; CHECK: bltu x10, x11, [[TARGET:\.LBB[0-9]+_[0-9]+]]
entry:
  %cmp = icmp ult i64 %a, %b
  br i1 %cmp, label %t, label %f
t:
  ret i64 %a
f:
  ret i64 %b
}

define i64 @sel_uge(i64 %a, i64 %b) {
; CHECK-LABEL: sel_uge:
; CHECK: bgeu x10, x11, [[TARGET:\.LBB[0-9]+_[0-9]+]]
entry:
  %cmp = icmp uge i64 %a, %b
  br i1 %cmp, label %t, label %f
t:
  ret i64 %a
f:
  ret i64 %b
}

define i64 @sel_sgt(i64 %a, i64 %b) {
; CHECK-LABEL: sel_sgt:
; CHECK: blt x11, x10, [[TARGET:\.LBB[0-9]+_[0-9]+]]
entry:
  %cmp = icmp sgt i64 %a, %b
  br i1 %cmp, label %t, label %f
t:
  ret i64 %a
f:
  ret i64 %b
}

define i64 @sel_bool(i1 %cond, i64 %a, i64 %b) {
; CHECK-LABEL: sel_bool:
; CHECK: bne x10, x0, [[TARGET:\.LBB[0-9]+_[0-9]+]]
entry:
  br i1 %cond, label %t, label %f
t:
  ret i64 %a
f:
  ret i64 %b
}
