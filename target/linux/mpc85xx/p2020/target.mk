BOARDNAME:=P2020
KERNEL_IMAGES:=zImage.la3000000
DEFAULT_PACKAGES += xtm330-paneld

define Target/Description
	Build firmware images for Freescale P2020 based boards.
endef
