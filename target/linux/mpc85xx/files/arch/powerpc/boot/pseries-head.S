/* SPDX-License-Identifier: GPL-2.0 */
/* Modified: removed FIXUP_ENDIAN for 32-bit e500 compatibility */
#include "ppc_asm.h"

	.text

	.globl _zimage_start
_zimage_start:
	b	_zimage_start_lib
