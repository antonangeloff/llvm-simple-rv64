; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

define i64 @icmp_slt_value(i64 %a, i64 %b) {
; CHECK-LABEL: icmp_slt_value:
; CHECK: slt x10, x10, x11
entry:
  %cmp = icmp slt i64 %a, %b
  %ext = zext i1 %cmp to i64
  ret i64 %ext
}

define i64 @icmp_ult_value(i64 %a, i64 %b) {
; CHECK-LABEL: icmp_ult_value:
; CHECK: sltu x10, x10, x11
entry:
  %cmp = icmp ult i64 %a, %b
  %ext = zext i1 %cmp to i64
  ret i64 %ext
}

define i64 @icmp_eq_value(i64 %a, i64 %b) {
; CHECK-LABEL: icmp_eq_value:
; CHECK: xor x10, x10, x11
; CHECK: sltiu x10, x10, 1
entry:
  %cmp = icmp eq i64 %a, %b
  %ext = zext i1 %cmp to i64
  ret i64 %ext
}

define i64 @icmp_ne_value(i64 %a, i64 %b) {
; CHECK-LABEL: icmp_ne_value:
; CHECK: xor x10, x10, x11
; CHECK: sltu x10, x0, x10
entry:
  %cmp = icmp ne i64 %a, %b
  %ext = zext i1 %cmp to i64
  ret i64 %ext
}

define i64 @icmp_sge_value(i64 %a, i64 %b) {
; CHECK-LABEL: icmp_sge_value:
; CHECK: slt x10, x10, x11
; CHECK: xori x10, x10, 1
entry:
  %cmp = icmp sge i64 %a, %b
  %ext = zext i1 %cmp to i64
  ret i64 %ext
}

define i64 @icmp_sle_value(i64 %a, i64 %b) {
; CHECK-LABEL: icmp_sle_value:
; CHECK: slt x10, x11, x10
; CHECK: xori x10, x10, 1
entry:
  %cmp = icmp sle i64 %a, %b
  %ext = zext i1 %cmp to i64
  ret i64 %ext
}

define i64 @icmp_sgt_value(i64 %a, i64 %b) {
; CHECK-LABEL: icmp_sgt_value:
; CHECK: slt x10, x11, x10
entry:
  %cmp = icmp sgt i64 %a, %b
  %ext = zext i1 %cmp to i64
  ret i64 %ext
}

define i64 @icmp_uge_value(i64 %a, i64 %b) {
; CHECK-LABEL: icmp_uge_value:
; CHECK: sltu x10, x10, x11
; CHECK: xori x10, x10, 1
entry:
  %cmp = icmp uge i64 %a, %b
  %ext = zext i1 %cmp to i64
  ret i64 %ext
}

define i64 @icmp_ule_value(i64 %a, i64 %b) {
; CHECK-LABEL: icmp_ule_value:
; CHECK: sltu x10, x11, x10
; CHECK: xori x10, x10, 1
entry:
  %cmp = icmp ule i64 %a, %b
  %ext = zext i1 %cmp to i64
  ret i64 %ext
}

define i64 @icmp_ugt_value(i64 %a, i64 %b) {
; CHECK-LABEL: icmp_ugt_value:
; CHECK: sltu x10, x11, x10
entry:
  %cmp = icmp ugt i64 %a, %b
  %ext = zext i1 %cmp to i64
  ret i64 %ext
}
