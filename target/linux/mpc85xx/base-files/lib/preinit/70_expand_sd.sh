#!/bin/sh
# Copyright (C) 2026 OpenWrt.org

expand_sd_partition() {
    case "$(board_name)" in
        watchguard,firebox-t30|watchguard,firebox-t30-w)
            [ -b /dev/mmcblk0p4 ] || return 0

            # SAFEGUARD: If partition 4 is already expanded (> 2.5GB), NEVER run again (Prevents loops)
            local part_size
            part_size=$(cat /sys/block/mmcblk0/mmcblk0p4/size 2>/dev/null || echo 0)
            if [ "$part_size" -gt 5000000 ]; then
                return 0
            fi

            if command -v fdisk >/dev/null && command -v mkfs.ext4 >/dev/null; then
                local P3_START P3_SIZE SAFE_START
                P3_START=$(cat /sys/block/mmcblk0/mmcblk0p3/start 2>/dev/null || echo 0)
                P3_SIZE=$(cat /sys/block/mmcblk0/mmcblk0p3/size 2>/dev/null || echo 0)
                
                if [ "$P3_START" -gt 0 ] && [ "$P3_SIZE" -gt 0 ]; then
                    SAFE_START=$((P3_START + P3_SIZE))

                    # Recreate partition 4 at the end spanning to max size safely
                    printf "d\n4\nn\np\n4\n%s\n\nw\n" "$SAFE_START" | fdisk /dev/mmcblk0 >/dev/null 2>&1
                    sync

                    # Format immediately with compatibility flags for OpenWrt kernel
                    mkfs.ext4 -F -O ^metadata_csum,^64bit /dev/mmcblk0p4 >/dev/null 2>&1
                    sync

                    # Force one single clean reboot to let OpenWrt recognize the new partition and fstab
                    reboot -f
                    exit 0
                fi
            fi
            ;;
    esac
}

boot_hook_add preinit_main expand_sd_partition
