; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

%Big = type { i64, i64, i64, i64 }

define i64 @sum_big(ptr byval(%Big) %p) {
; CHECK-LABEL: sum_big:
; CHECK: addi [[P:x[0-9]+]], x2, 0
; CHECK: ld [[V0:x[0-9]+]], 0([[P]])
; CHECK: ld [[V1:x[0-9]+]], 8([[P]])
; CHECK: ld [[V2:x[0-9]+]], 16([[P]])
; CHECK: ld [[V3:x[0-9]+]], 24([[P]])
; CHECK: add [[S0:x[0-9]+]], [[V0]], [[V1]]
; CHECK: add [[S1:x[0-9]+]], [[S0]], [[V2]]
; CHECK: add x10, [[S1]], [[V3]]
; CHECK: jalr x0, 0(x1)
entry:
  %p0 = getelementptr %Big, ptr %p, i32 0, i32 0
  %p1 = getelementptr %Big, ptr %p, i32 0, i32 1
  %p2 = getelementptr %Big, ptr %p, i32 0, i32 2
  %p3 = getelementptr %Big, ptr %p, i32 0, i32 3
  %v0 = load i64, ptr %p0
  %v1 = load i64, ptr %p1
  %v2 = load i64, ptr %p2
  %v3 = load i64, ptr %p3
  %s0 = add i64 %v0, %v1
  %s1 = add i64 %s0, %v2
  %s2 = add i64 %s1, %v3
  ret i64 %s2
}

declare i64 @sum_big_decl(ptr byval(%Big))

define i64 @call_sum_big(i64 %a, i64 %b, i64 %c, i64 %d) {
; CHECK-LABEL: call_sum_big:
; CHECK: addi x2, x2, -{{[0-9]+}}
; CHECK: sd x1, {{[0-9]+}}(x2)
; CHECK: sd {{x[0-9]+}}, {{[0-9]+}}(x2)
; CHECK: sd {{x[0-9]+}}, {{[0-9]+}}(x2)
; CHECK: sd {{x[0-9]+}}, {{[0-9]+}}(x2)
; CHECK: sd {{x[0-9]+}}, {{[0-9]+}}(x2)
; CHECK: jal x1, sum_big_decl
; CHECK: jalr x0, 0(x1)
entry:
  %buf = alloca %Big
  %p0 = getelementptr %Big, ptr %buf, i32 0, i32 0
  %p1 = getelementptr %Big, ptr %buf, i32 0, i32 1
  %p2 = getelementptr %Big, ptr %buf, i32 0, i32 2
  %p3 = getelementptr %Big, ptr %buf, i32 0, i32 3
  store i64 %a, ptr %p0
  store i64 %b, ptr %p1
  store i64 %c, ptr %p2
  store i64 %d, ptr %p3
  %r = call i64 @sum_big_decl(ptr byval(%Big) %buf)
  ret i64 %r
}

%Pair = type { i64, i64 }

declare void @mutate_byval(ptr byval(%Pair))

define void @call_mutate_byval(i64 %a, i64 %b) {
; CHECK-LABEL: call_mutate_byval:
; CHECK: sd {{x[0-9]+}}, {{[0-9]+}}(x2)
; CHECK: sd {{x[0-9]+}}, {{[0-9]+}}(x2)
; CHECK: addi x10, x0, 0
; CHECK: add x10, x2, x10
; CHECK: addi x12, x0, 16
; CHECK: addi x11, {{x[0-9]+}}, 0
; CHECK: jal x1, memcpy
; CHECK: jal x1, mutate_byval
; CHECK: jalr x0, 0(x1)
entry:
  %buf = alloca %Pair
  %p0 = getelementptr %Pair, ptr %buf, i32 0, i32 0
  %p1 = getelementptr %Pair, ptr %buf, i32 0, i32 1
  store i64 %a, ptr %p0
  store i64 %b, ptr %p1
  call void @mutate_byval(ptr byval(%Pair) %buf)
  ret void
}
