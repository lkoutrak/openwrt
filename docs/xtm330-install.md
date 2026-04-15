# WatchGuard XTM330 install / upgrade notes

## Firmware model

This target uses the upstream OpenWrt XTM330 image layout:

- FIT kernel image
- kernel linked for runtime load at `0x3000000`
- NAND kernel partition starts at `0x20000`

## Important hardware note

Some XTM330 units ship with a stock U-Boot environment that expects a split
kernel+DTB boot flow. Upstream OpenWrt for XTM330 uses a single FIT image
instead, so these units need a U-Boot `bootcmd` adjustment.

The working boot flow for this hardware variant is:

```sh
nand read 0x1000000 0x20000 0x500000
bootm 0x1000000
```

## Temporary TFTP boot

At the U-Boot prompt:

```sh
setenv ipaddr 10.0.0.214
setenv serverip 10.0.0.231
tftpboot 0x1000000 xtm330-initramfs-fit.bin
bootm 0x1000000
```

## Persistent NAND bootcmd

At the U-Boot prompt:

```sh
setenv bootcmd 'nand read 0x1000000 0x20000 0x500000;bootm 0x1000000'
saveenv
```

## Sysupgrade

Once booted into OpenWrt, install the normal sysupgrade image.

The XTM330 platform upgrade hook in this fork also updates the bootcmd during
sysupgrade so future upgrades preserve the working FIT boot flow.

## Notes

- Kernel partition offset: `0x20000`
- Safe NAND read size for current FIT kernel: `0x500000`
- The kernel is relocated by U-Boot to its runtime load address from the FIT
  metadata, so the image should be loaded into a temporary address like
  `0x1000000`, not directly into `0x3000000`.
