#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# WatchGuard Firebox T30/T30-W p4 auto-expand
#
# SD card layout (see scripts/make_watchguard_t30w_sdimage.sh):
#   p1: 1MB placeholder
#   p2: 128MB squashfs root (kernel boots with root=/dev/mmcblk0p2)
#   p3: 32MB boot partition (U-Boot loads kernel from here)
#   p4: default sized at build time, expanded to fill the SD card on first
#       boot if the user's card is larger than the build-time default.
#
# This script runs at preinit_main, BEFORE the rootfs pivot. The rootfs
# (squashfs on p2) is mounted at this point, so the disk is "in use" and
# sfdisk cannot issue a full BLKRRPART re-read. The fix: use --force to
# write the new MBR, then use partx -u (BLKPG) to update only p4's size in
# the kernel, then resize2fs to grow the ext4 filesystem. If partx cannot
# update the kernel's view (rare), we DO NOT reboot - we create a flag file
# in the (writable) tmpfs and let the system boot normally. On the next
# boot the kernel reads the new MBR directly and finishes the resize.
#
# block-mount then mounts p4 as /overlay via files/etc/config/fstab.

expand_sd_partition() {
	case "$(board_name)" in
	watchguard,firebox-t30|watchguard,firebox-t30-w)
		[ -b /dev/mmcblk0p4 ] || return 0

		# Already expanded? Check if filesystem needs growing too.
		# Resize2fs is a no-op if the ext4 filesystem is already full,
		# so it's safe to run every boot. This handles the case where
		# the previous boot wrote the new MBR but couldn't resize2fs
		# before the kernel finished (deferred resize path).
		local part_sectors
		part_sectors=$(cat /sys/block/mmcblk0/mmcblk0p4/size 2>/dev/null || echo 0)
		if [ "$part_sectors" -gt 5000000 ]; then
			resize2fs /dev/mmcblk0p4 >/dev/null 2>&1 || true
			return 0
		fi

		# Need sfdisk (util-linux) and resize2fs (e2fsprogs).
		# They are listed in DEVICE_PACKAGES (p1010.mk) and get installed
		# at first boot via apk, but the factory image's squashfs does not
		# include them. Try to install them silently via apk if missing -
		# this lets the expand run on a fresh factory image without user
		# intervention.
		if ! command -v sfdisk >/dev/null 2>&1 || \
		   ! command -v resize2fs >/dev/null 2>&1; then
			if command -v apk >/dev/null 2>&1; then
				apk add -q sfdisk resize2fs >/dev/null 2>&1 || true
			fi
		fi
		command -v sfdisk >/dev/null 2>&1 || return 0
		command -v resize2fs >/dev/null 2>&1 || return 0


		local p3_end
		p3_end=$(cat /sys/block/mmcblk0/mmcblk0p3/start 2>/dev/null || echo 0)
		p3_end=$((p3_end + $(cat /sys/block/mmcblk0/mmcblk0p3/size 2>/dev/null || echo 0)))

		# Write the new MBR with p4 extended to fill the card.
		# --force: ignore the in-use warning and write anyway.
		# --no-tell-kernel: don't issue BLKRRPART (the disk is busy).
		# The new MBR will be picked up on the next boot, or
		# immediately via partx -u (BLKPG) below.
		sfdisk -q --force --no-tell-kernel /dev/mmcblk0 -N 4 \
			<<-EOF >/dev/null 2>&1
		$p3_end,
		EOF
		local sfdisk_rc=$?

		# Try to update the kernel's view of p4 in place via BLKPG.
		# partx -u works even when the disk is busy because it
		# updates a single partition, not the whole table.
		local partx_sectors=0
		if command -v partx >/dev/null 2>&1; then
			partx -u /dev/mmcblk0p4 >/dev/null 2>&1 || true
			partx_sectors=$(cat /sys/block/mmcblk0/mmcblk0p4/size 2>/dev/null || echo 0)
		fi

		# If the kernel sees the new size, grow the ext4 filesystem.
		# If not, fall through to the next-boot path (flag file).
		if [ "$partx_sectors" -gt "$part_sectors" ]; then
			resize2fs /dev/mmcblk0p4 >/dev/null 2>&1
			# Mark this boot as the one that finished the resize.
			[ -d /tmp ] && touch /tmp/.t30_p4_expanded
			return 0
		fi

		# Could not update kernel view in place. Write a flag file in
		# tmpfs (always writable) so a post-boot script can retry, or
		# so the next boot picks up the new MBR and grows the fs.
		# We do NOT call reboot -f here - that would create a loop.
		if [ -d /tmp ]; then
			touch /tmp/.t30_p4_expand_pending
		fi
		;;
	esac
}

boot_hook_add preinit_main expand_sd_partition
