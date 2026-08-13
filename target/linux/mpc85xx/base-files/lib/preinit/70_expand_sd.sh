#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# WatchGuard Firebox T30/T30-W p4 auto-expand
#
# SD card layout (see scripts/make_watchguard_t30w_sdimage.sh):
#   p1: 1MB placeholder
#   p2: 128MB squashfs root (kernel boots with root=/dev/mmcblk0p2)
#   p3: 32MB boot partition (U-Boot loads kernel from here)
#   p4: ~2GB default, expanded to fill the SD card on first boot
#
# On first boot, partition 4 is grown to fill the remaining card space
# and the ext4 filesystem inside it is grown in place. This is non-
# destructive: p4's contents are preserved across the partition resize.
# block-mount then mounts p4 as /overlay via files/etc/config/fstab.
#
# If the kernel refuses to re-read the partition table on the in-use
# root device (rare), we fall back to a forced reboot; on the next boot
# the new table is in effect.

expand_sd_partition() {
	case "$(board_name)" in
	watchguard,firebox-t30|watchguard,firebox-t30-w)
		[ -b /dev/mmcblk0p4 ] || return 0

		# Already expanded? Skip.
		local part_sectors
		part_sectors=$(cat /sys/block/mmcblk0/mmcblk0p4/size 2>/dev/null || echo 0)
		# 2GB partition = 4194304 sectors (512-byte). Anything well above
		# 2.5GB is clearly already grown; 5M sectors ≈ 2.5GB.
		[ "$part_sectors" -gt 5000000 ] && return 0

		# Need sfdisk (util-linux) and resize2fs (e2fsprogs)
		command -v sfdisk >/dev/null 2>&1 || return 0
		command -v resize2fs >/dev/null 2>&1 || return 0

		local p3_end
		p3_end=$(cat /sys/block/mmcblk0/mmcblk0p3/start 2>/dev/null || echo 0)
		p3_end=$((p3_end + $(cat /sys/block/mmcblk0/mmcblk0p3/size 2>/dev/null || echo 0)))

		# Resize partition 4: keep its start, extend its end to fill the card.
		# sfdisk writes the new MBR in place (non-destructive for the
		# filesystem data on p4 since we only move the trailing boundary).
		sfdisk -q --no-tell-kernel /dev/mmcblk0 -N 4 <<-EOF >/dev/null 2>&1
		$p3_end,
		EOF
		local rc=$?

		# Ask the kernel to re-read the partition table. partx on the
		# specific partition uses BLKPG, which works even when the disk
		# is in use. If partx is unavailable, fall back to partprobe.
		if command -v partx >/dev/null 2>&1; then
			partx -u /dev/mmcblk0p4 >/dev/null 2>&1 || true
		elif command -v partprobe >/dev/null 2>&1; then
			partprobe /dev/mmcblk0 >/dev/null 2>&1 || true
		fi

		# Grow the ext4 filesystem to fill the now-larger partition.
		resize2fs /dev/mmcblk0p4 >/dev/null 2>&1 || true

		# If the partition resize failed entirely (kernel rejected the
		# table update on the busy root disk), reboot so the new table
		# takes effect on the next boot.
		[ "$rc" -eq 0 ] || reboot -f
		;;
	esac
}

boot_hook_add preinit_main expand_sd_partition