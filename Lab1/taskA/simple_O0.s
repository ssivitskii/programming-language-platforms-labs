	.file	"simple.cpp"
	.intel_syntax noprefix
	.text
	.globl	global_counter
	.bss
	.align 4
	.type	global_counter, @object
	.size	global_counter, 4
global_counter:
	.zero	4
	.section	.rodata
	.align 4
	.type	_ZL5MAGIC, @object
	.size	_ZL5MAGIC, 4
_ZL5MAGIC:
	.long	42
	.text
	.globl	_Z6squarei
	.type	_Z6squarei, @function
_Z6squarei:
.LFB3:
	.cfi_startproc
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	mov	rbp, rsp
	.cfi_def_cfa_register 6
	mov	DWORD PTR [rbp-4], edi
	mov	eax, DWORD PTR [rbp-4]
	imul	eax, eax
	pop	rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE3:
	.size	_Z6squarei, .-_Z6squarei
	.globl	_Z14sum_of_squaresii
	.type	_Z14sum_of_squaresii, @function
_Z14sum_of_squaresii:
.LFB4:
	.cfi_startproc
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	mov	rbp, rsp
	.cfi_def_cfa_register 6
	push	rbx
	sub	rsp, 8
	.cfi_offset 3, -24
	mov	DWORD PTR [rbp-12], edi
	mov	DWORD PTR [rbp-16], esi
	mov	eax, DWORD PTR [rbp-12]
	mov	edi, eax
	call	_Z6squarei
	mov	ebx, eax
	mov	eax, DWORD PTR [rbp-16]
	mov	edi, eax
	call	_Z6squarei
	add	eax, ebx
	mov	rbx, QWORD PTR [rbp-8]
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE4:
	.size	_Z14sum_of_squaresii, .-_Z14sum_of_squaresii
	.globl	_Z12bump_counterv
	.type	_Z12bump_counterv, @function
_Z12bump_counterv:
.LFB5:
	.cfi_startproc
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	mov	rbp, rsp
	.cfi_def_cfa_register 6
	mov	eax, DWORD PTR global_counter[rip]
	add	eax, 1
	mov	DWORD PTR global_counter[rip], eax
	nop
	pop	rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE5:
	.size	_Z12bump_counterv, .-_Z12bump_counterv
	.section	.rodata
	.align 8
.LC0:
	.string	"Result: %d, Counter: %d, Magic: %d\n"
	.text
	.globl	main
	.type	main, @function
main:
.LFB6:
	.cfi_startproc
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	mov	rbp, rsp
	.cfi_def_cfa_register 6
	sub	rsp, 16
	mov	esi, 4
	mov	edi, 3
	call	_Z14sum_of_squaresii
	mov	DWORD PTR [rbp-4], eax
	call	_Z12bump_counterv
	mov	edx, DWORD PTR global_counter[rip]
	mov	eax, DWORD PTR [rbp-4]
	mov	ecx, 42
	mov	esi, eax
	mov	edi, OFFSET FLAT:.LC0
	mov	eax, 0
	call	printf
	mov	eax, 0
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE6:
	.size	main, .-main
	.ident	"GCC: (GNU) 14.4.0"
	.section	.note.GNU-stack,"",@progbits
