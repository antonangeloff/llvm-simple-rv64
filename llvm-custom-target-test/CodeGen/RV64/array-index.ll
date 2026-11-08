; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 -relocation-model=static | FileCheck %s

; Indexing an array by a runtime (non-constant) value. A constant index
; would fold straight into G_GLOBAL_VALUE's own offset (no G_PTR_ADD needed,
; as established for e.g. @arr+8) -- these specifically exercise the case
; that still has no support at all: G_PTR_ADD combining a materialized base
; address with a runtime-computed byte offset.

@arr = global [10 x i64] zeroinitializer

define i64 @read_arr(i64 %i) {
; CHECK-LABEL: read_arr:
; CHECK: lui [[HI:x[0-9]+]], %hi(arr)
; CHECK: addi [[BASE:x[0-9]+]], [[HI]], %lo(arr)
; CHECK: addi [[EIGHT:x[0-9]+]], x0, 8
; CHECK: mul [[OFF:x[0-9]+]], x10, [[EIGHT]]
; CHECK: add [[ADDR:x[0-9]+]], [[BASE]], [[OFF]]
; CHECK: ld x10, 0([[ADDR]])
entry:
  %p = getelementptr [10 x i64], ptr @arr, i64 0, i64 %i
  %v = load i64, ptr %p
  ret i64 %v
}

define void @write_arr(i64 %i, i64 %val) {
; CHECK-LABEL: write_arr:
; CHECK: lui [[HI:x[0-9]+]], %hi(arr)
; CHECK: addi [[BASE:x[0-9]+]], [[HI]], %lo(arr)
; CHECK: addi [[EIGHT:x[0-9]+]], x0, 8
; CHECK: mul [[OFF:x[0-9]+]], x10, [[EIGHT]]
; CHECK: add [[ADDR:x[0-9]+]], [[BASE]], [[OFF]]
; CHECK: sd x11, 0([[ADDR]])
entry:
  %p = getelementptr [10 x i64], ptr @arr, i64 0, i64 %i
  store i64 %val, ptr %p
  ret void
}

define i64 @read_local_arr(i64 %i) {
; CHECK-LABEL: read_local_arr:
; CHECK: addi x2, x2, -80
; CHECK: addi [[BASE:x[0-9]+]], x2, 0
; CHECK: addi [[EIGHT:x[0-9]+]], x0, 8
; CHECK: mul [[OFF:x[0-9]+]], x10, [[EIGHT]]
; CHECK: add [[ADDR:x[0-9]+]], [[BASE]], [[OFF]]
; CHECK: ld x10, 0([[ADDR]])
; CHECK: addi x2, x2, 80
entry:
  %arr = alloca [10 x i64]
  %p = getelementptr [10 x i64], ptr %arr, i64 0, i64 %i
  %v = load i64, ptr %p
  ret i64 %v
}

define void @write_local_arr(i64 %i, i64 %val) {
; CHECK-LABEL: write_local_arr:
; CHECK: addi x2, x2, -80
; CHECK: addi [[BASE:x[0-9]+]], x2, 0
; CHECK: addi [[EIGHT:x[0-9]+]], x0, 8
; CHECK: mul [[OFF:x[0-9]+]], x10, [[EIGHT]]
; CHECK: add [[ADDR:x[0-9]+]], [[BASE]], [[OFF]]
; CHECK: sd x11, 0([[ADDR]])
; CHECK: addi x2, x2, 80
entry:
  %arr = alloca [10 x i64]
  %p = getelementptr [10 x i64], ptr %arr, i64 0, i64 %i
  store i64 %val, ptr %p
  ret void
}
