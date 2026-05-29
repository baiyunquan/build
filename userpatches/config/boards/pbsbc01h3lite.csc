# Allwinner H3 quad core 512MB/1GB RAM WiFi
BOARD_NAME="pbsbc01h3 Lite"
BOARD_VENDOR="xunlong"
BOARDFAMILY="sun8i"
BOARD_MAINTAINER="liaic"
INTRODUCED="2026"

# Keep a known-good H3 Lite boot chain while selecting board-specific kernel DTB.
BOOTCONFIG="orangepi_lite_defconfig"
BOOT_FDT_FILE="sun8i-h3-pbsbc01h3-lite.dtb"

MODULES_LEGACY="g_serial"
MODULES_CURRENT="g_serial"
DEFAULT_OVERLAYS="usbhost2 usbhost3"
SERIALCON="ttyS0"

KERNEL_TARGET="current"
KERNEL_TEST_TARGET="current"

function post_config_uboot_target__extra_configs_for_pbsbc01h3_lite() {
	display_alert "$BOARD" "set dram clock" "info"
	run_host_command_logged scripts/config --set-val CONFIG_DRAM_CLK "624"
	run_host_command_logged scripts/config --set-val CONFIG_DRAM_ZQ "3881979"
	run_host_command_logged scripts/config --enable CONFIG_DRAM_ODT_EN
}
