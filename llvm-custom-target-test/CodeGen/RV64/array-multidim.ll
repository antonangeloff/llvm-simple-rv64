; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 -relocation-model=static | FileCheck %s

; Multi-dimensional array indexing
@matrix = global [4 x [4 x i64]] zeroinitializer

define i64 @read_matrix(i64 %i, i64 %j) {
; CHECK-LABEL: read_matrix:
; CHECK: lui [[HI:x[0-9]+]], %hi(matrix)
; CHECK: addi [[BASE:x[0-9]+]], [[HI]], %lo(matrix)
; CHECK: addi [[ROW:x[0-9]+]], x0, 32
; CHECK: mul x10, x10, [[ROW]]
; CHECK: add x10, [[BASE]], x10
; CHECK: addi [[COL:x[0-9]+]], x0, 8
; CHECK: mul x11, x11, [[COL]]
; CHECK: add x10, x10, x11
; CHECK: ld x10, 0(x10)
entry:
  %p = getelementptr [4 x [4 x i64]], ptr @matrix, i64 0, i64 %i, i64 %j
  %v = load i64, ptr %p
  ret i64 %v
}

define void @write_matrix(i64 %i, i64 %j, i64 %val) {
; CHECK-LABEL: write_matrix:
; CHECK: lui [[HI:x[0-9]+]], %hi(matrix)
; CHECK: addi [[BASE:x[0-9]+]], [[HI]], %lo(matrix)
; CHECK: addi [[ROW:x[0-9]+]], x0, 32
; CHECK: mul x10, x10, [[ROW]]
; CHECK: add x10, [[BASE]], x10
; CHECK: addi [[COL:x[0-9]+]], x0, 8
; CHECK: mul x11, x11, [[COL]]
; CHECK: add x10, x10, x11
; CHECK: sd x12, 0(x10)
entry:
  %p = getelementptr [4 x [4 x i64]], ptr @matrix, i64 0, i64 %i, i64 %j
  store i64 %val, ptr %p
  ret void
}
