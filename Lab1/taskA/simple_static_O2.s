	.file	"simple_static.cpp"
	.intel_syntax noprefix
	.text
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
