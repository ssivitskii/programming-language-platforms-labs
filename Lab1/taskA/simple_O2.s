	.file	"simple.cpp"
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	_Z6squarei
	.type	_Z6squarei, @function
_Z6squarei:
.LFB15:
	.cfi_startproc
	imul	edi, edi
	mov	eax, edi
	ret
	.cfi_endproc
.LFE15:
	.size	_Z6squarei, .-_Z6squarei
	.p2align 4
	.globl	_Z14sum_of_squaresii
	.type	_Z14sum_of_squaresii, @function
_Z14sum_of_squaresii:
.LFB16:
	.cfi_startproc
	imul	edi, edi
	imul	esi, esi
	lea	eax, [rdi+rsi]
	ret
	.cfi_endproc
.LFE16:
	.size	_Z14sum_of_squaresii, .-_Z14sum_of_squaresii
	.p2align 4
	.globl	_Z12bump_counterv
	.type	_Z12bump_counterv, @function
_Z12bump_counterv:
.LFB17:
	.cfi_startproc
	add	DWORD PTR global_counter[rip], 1
	ret
	.cfi_endproc
.LFE17:
	.size	_Z12bump_counterv, .-_Z12bump_counterv
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align 8
.LC0:
	.string	"Result: %d, Counter: %d, Magic: %d\n"
	.section	.text.startup,"ax",@progbits
	.p2align 4
	.globl	main
	.type	main, @function
main:
.LFB18:
	.cfi_startproc
	sub	rsp, 8
	.cfi_def_cfa_offset 16
	mov	eax, DWORD PTR global_counter[rip]
	mov	ecx, 42
	mov	esi, 25
	mov	edi, OFFSET FLAT:.LC0
	lea	edx, [rax+1]
	xor	eax, eax
	mov	DWORD PTR global_counter[rip], edx
	call	printf
	xor	eax, eax
	add	rsp, 8
	.cfi_def_cfa_offset 8
	ret
	.cfi_endproc
.LFE18:
	.size	main, .-main
	.globl	global_counter
	.bss
	.align 4
	.type	global_counter, @object
	.size	global_counter, 4
global_counter:
	.zero	4
	.ident	"GCC: (GNU) 14.4.0"
	.section	.note.GNU-stack,"",@progbits
