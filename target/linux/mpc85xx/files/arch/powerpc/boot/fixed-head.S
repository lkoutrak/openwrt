/* SPDX-License-Identifier: GPL-2.0 */
/* Modified to add early debug output */
	.text
	.global _zimage_start
_zimage_start:
	/* Write 'B' to UART at 0xffe04500 (DUART0 THR) */
	lis	r3, 0xffe0
	ori	r3, r3, 0x4500
	li	r4, 0x42	/* 'B' */
	stb	r4, 0(r3)
	/* Write 'O' */
	li	r4, 0x4F	/* 'O' */
	stb	r4, 0(r3)
	/* Write 'O' */
	li	r4, 0x4F	/* 'O' */
	stb	r4, 0(r3)
	/* Write 'T' */
	li	r4, 0x54	/* 'T' */
	stb	r4, 0(r3)
	b	_zimage_start_lib
