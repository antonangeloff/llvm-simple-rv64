; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 -relocation-model=static | FileCheck %s

; Globals with non-zero initializers. Unlike global-var-abs.ll/pcrel.ll's
; `global i64 0` or array-index.ll's zeroinitializer array (both land in
; .bss with no real data to emit), these need actual .data/.rodata content
; emission
@initialized = global i64 42
@arr_init = global [3 x i64] [i64 1, i64 2, i64 3]
@str = constant [4 x i8] c"hi!\00"

define i64 @read_initialized() {
; CHECK-LABEL: read_initialized:
; CHECK: lui [[HI:x[0-9]+]], %hi(initialized)
; CHECK: addi x10, [[HI]], %lo(initialized)
; CHECK: ld x10, 0(x10)
entry:
  %v = load i64, ptr @initialized
  ret i64 %v
}

define i64 @read_arr_init(i64 %i) {
; CHECK-LABEL: read_arr_init:
; CHECK: lui [[HI:x[0-9]+]], %hi(arr_init)
; CHECK: addi [[BASE:x[0-9]+]], [[HI]], %lo(arr_init)
; CHECK: addi [[EIGHT:x[0-9]+]], x0, 8
; CHECK: mul x10, x10, [[EIGHT]]
; CHECK: add x10, [[BASE]], x10
; CHECK: ld x10, 0(x10)
entry:
  %p = getelementptr [3 x i64], ptr @arr_init, i64 0, i64 %i
  %v = load i64, ptr %p
  ret i64 %v
}

define i8 @read_str(i64 %i) {
; CHECK-LABEL: read_str:
; CHECK: lui [[HI:x[0-9]+]], %hi(str)
; CHECK: addi [[BASE:x[0-9]+]], [[HI]], %lo(str)
; CHECK: add x10, [[BASE]], x10
; CHECK: lb x10, 0(x10)
entry:
  %p = getelementptr [4 x i8], ptr @str, i64 0, i64 %i
  %v = load i8, ptr %p
  ret i8 %v
}

; CHECK: .data
; CHECK: initialized:
; CHECK-NEXT: .quad 42
; CHECK: arr_init:
; CHECK-NEXT: .quad 1
; CHECK-NEXT: .quad 2
; CHECK-NEXT: .quad 3
; CHECK: .section .rodata
; CHECK: str:
; CHECK-NEXT: .asciz "hi!"
