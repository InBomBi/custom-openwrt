#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# 1. File: package/boot/uboot-tools/uboot-envtools/files/ramips
awk '{
    print $0;
    if ($0 ~ /xiaomi,mi-router-4|\\/) {
        print " xiaomi,miwifi-r3|\\"
    }
}' package/boot/uboot-tools/uboot-envtools/files/ramips > temp.file && mv temp.file package/boot/uboot-tools/uboot-envtools/files/ramips

# 2. File: target/linux/ath79/dts/qca9533_tplink_tl-wr841.dtsi
awk '{
    if ($0 ~ /reg = <0x020000 0x3d0000>;/) 
        gsub(/0x3d0000/, "0xfd0000");
    if ($0 ~ /partition@3f0000/) 
        gsub(/3f0000/, "ff0000");
    if ($0 ~ /reg = <0x3f0000 0x010000>;/) 
        gsub(/0x3f0000/, "0xff0000");
    print $0;
}' target/linux/ath79/dts/qca9533_tplink_tl-wr841.dtsi > temp.file && mv temp.file target/linux/ath79/dts/qca9533_tplink_tl-wr841.dtsi

# 3. File: target/linux/ath79/image/tiny-tp-link.mk
awk '{
    if ($0 ~ /Device\/tplink-4mlzma/) 
        gsub(/4mlzma/, "16mlzma");
    print $0;
}' target/linux/ath79/image/tiny-tp-link.mk > temp.file && mv temp.file target/linux/ath79/image/tiny-tp-link.mk

# 4. Đối với các File Mới (New Files) Đối với file mt7620a_xiaomi_miwifi-r3.dts và ralink_nand.c, vì đây là file tạo mới hoàn 
# toàn (new file mode 100644), việc dùng awk để "sửa" là không khả thi vì chưa có file gốc.
cat << 'EOF' > target/linux/ramips/dts/mt7620a_xiaomi_miwifi-r3.dts
/dts-v1/;

#include "mt7620a.dtsi"

#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>

/ {
	compatible = "xiaomi,miwifi-r3", "ralink,mt7620a-soc";
	model = "Xiaomi Mi Router R3";

	aliases {
		led-status = &led_status_blue;
	};

	chosen {
		bootargs = "console=ttyS0,115200";
	};

	keys {
		compatible = "gpio-keys";

		reset {
			label = "reset";
			gpios = <&gpio1 6 GPIO_ACTIVE_HIGH>;
			linux,code = <KEY_RESTART>;
		};
	};

	leds {
		compatible = "gpio-leds";

		led_status_blue: blue {
			label = "blue:status";
			gpios = <&gpio1 0 GPIO_ACTIVE_LOW>;
			default-state = "on";
		};

		yellow {
			label = "yellow:status";
			gpios = <&gpio1 2 GPIO_ACTIVE_LOW>;
		};

		red {
			label = "red:status";
			gpios = <&gpio1 5 GPIO_ACTIVE_LOW>;
		};
	};

	nand {
		status = "okay";
		#address-cells = <1>;
		#size-cells = <1>;
		compatible = "mtk,mt7620-nand";

		partitions {
			compatible = "fixed-partitions";
			#address-cells = <1>;
			#size-cells = <1>;

			partition@0 {
				label = "Bootloader";
				reg = <0x0 0x40000>;
				read-only;
			};

			partition@40000 {
				label = "Config";
				reg = <0x40000 0x40000>;
			};

			partition@80000 {
				label = "Bdata";
				reg = <0x80000 0x40000>;
				read-only;
			};

			factory: partition@0xc0000 {
				label = "factory";
				reg = <0xc0000 0x40000>;
				read-only;

				nvmem-layout {
					compatible = "fixed-layout";
					#address-cells = <1>;
					#size-cells = <1>;

					eeprom_factory_0: eeprom@0 {
						reg = <0x0 0x200>;
					};

					eeprom_factory_8000: eeprom@8000 {
						reg = <0x8000 0x200>;
					};

					macaddr_factory_28: macaddr@28 {
						reg = <0x28 0x6>;
					};
				};
			};

			partition@100000 {
				label = "crash";
				reg = <0x100000 0x40000>;
				read-only;
			};

			partition@140000 {
				label = "crash_syslog";
				reg = <0x140000 0x40000>;
				read-only;
			};

			partition@180000 {
				label = "reserved0";
				reg = <0x180000 0x80000>;
				read-only;
			};

			partition@200000 {
				label = "kernel_stock";
				reg = <0x200000 0x400000>;
			};

			partition@600000 {
				label = "kernel";
				reg = <0x600000 0x400000>;
			};

			/* ubi partition is the result of squashing
			 * next consequent stock partitions:
			 * - rootfs0 (rootfs partition for stock kernel0),
			 * - rootfs1 (rootfs partition for stock failsafe kernel1),
			 * - overlay (used as ubi overlay in stock fw)
			 * resulting 117,5MiB space for packages.
			 */
			partition@a00000 {
				label = "ubi";
				reg = <0xa00000 0x7600000>;
			};
		};
	};
};

&gpio1 {
	status = "okay";
};

&ehci {
	status = "okay";
};

&ohci {
	status = "okay";
};

&ethernet {
	pinctrl-names = "default";
	pinctrl-0 = <&ephy_pins>;
	nvmem-cells = <&macaddr_factory_28>;
	nvmem-cell-names = "mac-address";
	mediatek,portmap = "llllw";
};

&wmac {
	pinctrl-names = "default", "pa_gpio";
	pinctrl-0 = <&pa_pins>;
	pinctrl-1 = <&pa_gpio_pins>;
	nvmem-cells = <&eeprom_factory_0>;
	nvmem-cell-names = "eeprom";
};

&pcie {
	status = "okay";
};

&pcie0 {
	wifi@0,0 {
		compatible = "pci14c3,7662";
		reg = <0x0000 0 0 0 0>;
		nvmem-cells = <&eeprom_factory_8000>;
		nvmem-cell-names = "eeprom";
		ieee80211-freq-limit = <5000000 6000000>;
	};
};

&pinctrl {
	state_default: pinctrl0 {
		gpio {
			groups = "rgmii1";
			function = "gpio";
		};
	};
};
EOF

# 5.File: target/linux/ramips/image/mt7620.mk
awk '/define Device\/youku_x2/ {
    print "define Device/xiaomi_miwifi-r3"
    print "  SOC := mt7620a"
    print "  BLOCKSIZE := 128k"
    print "  PAGESIZE := 2048"
    print "  KERNEL_SIZE := 4096k"
    print "  IMAGE_SIZE := 32768k"
    print "  UBINIZE_OPTS := -E 5"
    print "  IMAGES += kernel1.bin rootfs0.bin breed-factory.bin factory.bin"
    print "  IMAGE/kernel1.bin := append-kernel | check-size $$(KERNEL_SIZE)"
    print "  IMAGE/rootfs0.bin := append-ubi | check-size"
    print "  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata"
    print "  IMAGE/factory.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-ubi | check-size"
    print "  IMAGE/breed-factory.bin := append-kernel | pad-to $$(KERNEL_SIZE) | \\"
    print "                         append-kernel | pad-to $$(KERNEL_SIZE) | \\"
    print "                         append-ubi | check-size"
    print "  DEVICE_VENDOR := Xiaomi"
    print "  DEVICE_MODEL := Mi Router R3"
    print "  DEVICE_PACKAGES := kmod-mt76x2 kmod-usb2 kmod-usb-ohci uboot-envtools"
    print "endef"
    print "TARGET_DEVICES += xiaomi_miwifi-r3"
    print ""
} { print }' target/linux/ramips/image/mt7620.mk > temp.mk && mv temp.mk target/linux/ramips/image/mt7620.mk

# 6. File: .../base-files/etc/board.d/02_network
# Thêm switch config
awk '/lenovo,newifi-y1s\)/ {
    print "\txiaomi,miwifi-r3)"
    print "\t\tucidef_add_switch \"switch0\" \\"
    print "\t\t\t\"1:lan\" \"4:lan\" \"0:wan\" \"6@eth0\""
    print "\t\t;;"
} { print }' target/linux/ramips/mt7620/base-files/etc/board.d/02_network > temp.net && mv temp.net target/linux/ramips/mt7620/base-files/etc/board.d/02_network

# Thêm MAC config
awk '/zyxel,keenetic-lite-iii-a\)/ {
    print "\txiaomi,miwifi-r3)"
    print "\t\twan_mac=$(mtd_get_mac_binary factory 0x28)"
    print "\t\tlan_mac=$(macaddr_setbit_la \"$wan_mac\")"
    print "\t\t;;"
} { print }' target/linux/ramips/mt7620/base-files/etc/board.d/02_network > temp.net && mv temp.net target/linux/ramips/mt7620/base-files/etc/board.d/02_network

# 7. File: .../base-files/lib/upgrade/platform.sh
awk '/\*\)/ && !done {
    print "\txiaomi,miwifi-r3)"
    print "\t\t# this make it compatible with breed"
    print "\t\tdd if=/dev/mtd0 bs=64 count=1 2>/dev/null | grep -qi breed && CI_KERNPART_EXT=\"kernel_stock\""
    print "\t\tdd if=/dev/mtd7 bs=64 count=1 2>/dev/null | grep -o MIPS.*Linux | grep -qi X-WRT && CI_KERNPART_EXT=\"kernel_stock\""
    print "\t\tdd if=/dev/mtd7 bs=64 count=1 2>/dev/null | grep -o MIPS.*Linux | grep -qi NATCAP && CI_KERNPART_EXT=\"kernel0_rsvd\""
    print "\t\tnand_do_upgrade \"$1\""
    print "\t\t;;"
    done=1
} { print }' target/linux/ramips/mt7620/base-files/lib/upgrade/platform.sh > temp.sh && mv temp.sh target/linux/ramips/mt7620/base-files/lib/upgrade/platform.sh
# thay doi target/linux/ramips/mt7620/config-6.12
sed -i \
-e '/CONFIG_CPU_SUPPORTS_MSA=y/a CONFIG_CRC16=y\nCONFIG_CRYPTO_DEFLATE=y\nCONFIG_CRYPTO_HASH_INFO=y' \
-e '/CONFIG_CRYPTO_LIB_UTILS=y/a CONFIG_CRYPTO_LZO=y\nCONFIG_CRYPTO_RNG2=y' \
-e '/# CONFIG_GPIO_WATCHDOG_ARCH_INITCALL is not set/a # CONFIG_GSW150_SUPPORT is not set' \
-e '/CONFIG_LOCK_DEBUGGING_SUPPORT=y/a CONFIG_LZO_COMPRESS=y\nCONFIG_LZO_DECOMPRESS=y' \
-e '/CONFIG_MODULES_USE_ELF_REL=y/a # CONFIG_MT753X_GSW is not set' \
-e '/CONFIG_MTD_CMDLINE_PARTS=y/a CONFIG_MTD_NAND_MT7620=y' \
-e '/CONFIG_MTD_SPLIT_UIMAGE_FW=y/a CONFIG_MTD_UBI=y\nCONFIG_MTD_UBI_BEB_LIMIT=20\nCONFIG_MTD_UBI_BLOCK=y\nCONFIG_MTD_UBI_WL_THRESHOLD=4096' \
-e '/CONFIG_PREEMPT_NONE_BUILD=y/a CONFIG_PSTORE=y\nCONFIG_PSTORE_COMPRESS=y\nCONFIG_PSTORE_COMPRESS_DEFAULT="deflate"\nCONFIG_PSTORE_DEFLATE_COMPRESS=y\nCONFIG_PSTORE_DEFLATE_COMPRESS_DEFAULT=y\nCONFIG_PSTORE_RAM=y' \
-e '/CONFIG_RATIONAL=y/a CONFIG_REED_SOLOMON=y\nCONFIG_REED_SOLOMON_DEC8=y\nCONFIG_REED_SOLOMON_ENC8=y' \
-e '/CONFIG_SOC_BUS=y/a CONFIG_SGL_ALLOC=y' \
-e '/CONFIG_TINY_SRCU=y/a CONFIG_UBIFS_FS=y\nCONFIG_UBIFS_FS_ADVANCED_COMPR=y\n# CONFIG_UBIFS_FS_ZSTD is not set' \
-e '/CONFIG_ZBOOT_LOAD_ADDRESS=0x0/a CONFIG_ZLIB_DEFLATE=y\nCONFIG_ZLIB_INFLATE=y' \
target/linux/ramips/mt7620/config-6.12

# 8. Tạo File Patch Mới (0038-mtd-ralink-add-mt7620-nand-driver.patch)
cat << 'EOF' > target/linux/ramips/patches-6.12/0038-mtd-ralink-add-mt7620-nand-driver.patch
--- a/drivers/mtd/maps/Kconfig
+++ b/drivers/mtd/maps/Kconfig
@@ -385,4 +385,8 @@ config MTD_PISMO
 
 	  When built as a module, it will be called pismo.ko
 
+config MTD_NAND_MT7620
+	tristate "Support for NAND on Mediatek MT7620"
+	depends on RALINK && SOC_MT7620
+
 endmenu
--- a/drivers/mtd/maps/Makefile
+++ b/drivers/mtd/maps/Makefile
@@ -43,3 +43,4 @@ obj-$(CONFIG_MTD_PLATRAM)	+= plat-ram.o
 obj-$(CONFIG_MTD_INTEL_VR_NOR)	+= intel_vr_nor.o
 obj-$(CONFIG_MTD_VMU)		+= vmu-flash.o
 obj-$(CONFIG_MTD_LANTIQ)	+= lantiq-flash.o
+obj-$(CONFIG_MTD_NAND_MT7620)	+= ralink_nand.o
EOF
