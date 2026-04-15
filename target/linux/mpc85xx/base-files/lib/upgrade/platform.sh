#
# Copyright (C) 2011 OpenWrt.org
#

PART_NAME=firmware
REQUIRE_IMAGE_METADATA=1

platform_check_image() {
	return 0
}

platform_do_upgrade() {
	local board=$(board_name)

	case "$board" in
	watchguard,xtm330)
		local fwenv="/tmp/fw_env.config.xtm330"

		cat >"$fwenv" <<EOFW
/dev/mtd4 0x0 0x10000 0x10000
EOFW

		FW_ENV_CONFIG="$fwenv" fw_setenv bootcmd 'nand read 0x1000000 0x20000 0x500000;bootm 0x1000000'
		nand_do_upgrade "$1"
		;;
	hpe,msm460|\
	ocedo,panda|\
	sophos,red-15w-rev1|\
	watchguard,firebox-t10|\
	watchguard,firebox-t15)
		nand_do_upgrade "$1"
		;;
	*)
		default_do_upgrade "$1"
		;;
	esac
}
