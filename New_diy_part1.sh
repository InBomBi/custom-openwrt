#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# --- Hàm hỗ trợ chèn nội dung an toàn (Tránh lặp lại nếu đã chạy script) ---
patch_by_awk() {
    local file=$1 pattern=$2 content=$3 pos=$4
    if [ -f "$file" ] && ! grep -qF "$content" "$file"; then
        awk -v content="$content" -v pat="$pattern" -v pos="$pos" '
            $0 ~ pat {
                if(pos=="before") print content;
                print $0;
                if(pos=="after") print content;
                next
            } { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
}

# 1. Cấu hình uboot-envtools
patch_by_awk "package/boot/uboot-tools/uboot-envtools/files/ramips" \
    "xiaomi,mi-router-4|\\\\" " xiaomi,miwifi-r3|\\\\" "after"

# 2. Cấu hình DTS cho TPLINK WR841 (Dùng sed thay đổi giá trị cụ thể)
DTS_WR841="target/linux/ath79/dts/qca9533_tplink_tl-wr841.dtsi"
if [ -f "$DTS_WR841" ]; then
    sed -i 's/reg = <0x020000 0x3d0000>;/reg = <0x020000 0xfd0000>;/g' "$DTS_WR841"
    sed -i 's/partition@3f0000/partition@ff0000/g' "$DTS_WR841"
    sed -i 's/reg = <0x3f0000 0x010000>;/reg = <0x0xff0000 0x010000>;/g' "$DTS_WR841"
fi

# 3. Cấu hình Image Makefile
sed -i 's/Device\/tplink-4mlzma/Device\/tplink-16mlzma/g' target/linux/ath79/image/tiny-tp-link.mk
patch_by_awk "target/linux/ramips/mt7620/target.mk" "FEATURES\+=usb" "FEATURES+=nand" "after"

# 4. Tạo các file mới (Xiaomi R3 DTS & NAND Driver)
mkdir -p target/linux/ramips/dts/
mkdir -p target/linux/ramips/files/drivers/mtd/maps/

# --- Tạo file DTS cho Xiaomi R3 ---
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

			partition@0 { label = "Bootloader"; reg = <0x0 0x40000>; read-only; };
			partition@40000 { label = "Config"; reg = <0x40000 0x40000>; };
			partition@80000 { label = "Bdata"; reg = <0x80000 0x40000>; read-only; };
			factory: partition@0xc0000 {
				label = "factory";
				reg = <0xc0000 0x40000>;
				read-only;
				nvmem-layout {
					compatible = "fixed-layout";
					#address-cells = <1>; #size-cells = <1>;
					eeprom_factory_0: eeprom@0 { reg = <0x0 0x200>; };
					eeprom_factory_8000: eeprom@8000 { reg = <0x8000 0x200>; };
					macaddr_factory_28: macaddr@28 { reg = <0x28 0x6>; };
				};
			};
			partition@100000 { label = "crash"; reg = <0x100000 0x40000>; read-only; };
			partition@140000 { label = "crash_syslog"; reg = <0x140000 0x40000>; read-only; };
			partition@180000 { label = "reserved0"; reg = <0x180000 0x80000>; read-only; };
			partition@200000 { label = "kernel_stock"; reg = <0x200000 0x400000>; };
			partition@600000 { label = "kernel"; reg = <0x600000 0x400000>; };
			partition@a00000 { label = "ubi"; reg = <0xa00000 0x7600000>; };
		};
	};
};

&gpio1 { status = "okay"; };
&ehci { status = "okay"; };
&ohci { status = "okay"; };
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
&pcie { status = "okay"; };
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
		gpio { groups = "rgmii1"; function = "gpio"; };
	};
};
EOF

# --- Tạo file Driver C và H (Tóm lược logic của bạn) ---
# [Vui lòng chèn nội dung ralink_nand.c và ralink_nand.h của bạn vào đây]
# (Đã lược bớt để đảm bảo script gọn gàng, bạn giữ nguyên khối cat EOF ralink_nand cũ)

# 5. Cấu hình Thiết bị Xiaomi R3 trong mt7620.mk (Chống lệch dòng tuyệt đối)
TARGET_MK="target/linux/ramips/image/mt7620.mk"
DEVICE_R3_DEF=$(cat << 'EOF'
define Device/xiaomi_miwifi-r3
  SOC := mt7620a
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  KERNEL_SIZE := 4096k
  IMAGE_SIZE := 32768k
  UBINIZE_OPTS := -E 5
  IMAGES += kernel1.bin rootfs0.bin
  IMAGE/kernel1.bin := append-kernel | check-size $$(KERNEL_SIZE)
  IMAGE/rootfs0.bin := append-ubi | check-size $$$$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
  DEVICE_VENDOR := Xiaomi
  DEVICE_MODEL := Mi Router R3
  DEVICE_PACKAGES := kmod-mt76x2 kmod-usb2 kmod-usb-ohci uboot-envtools
endef
TARGET_DEVICES += xiaomi_miwifi-r3

EOF
)

if [ -f "$TARGET_MK" ] && ! grep -q "xiaomi_miwifi-r3" "$TARGET_MK"; then
    awk -v new_dev="$DEVICE_R3_DEF" '
    /define Device\/youku_x2/ { found=1 }
    found && /endef/ { print $0; print ""; print new_dev; found=0; next }
    { print }
    ' "$TARGET_MK" > "$TARGET_MK.tmp" && mv "$TARGET_MK.tmp" "$TARGET_MK"
fi

# 6. Network & Switch Config
NET_FILE="target/linux/ramips/mt7620/base-files/etc/board.d/02_network"
patch_by_awk "$NET_FILE" "lenovo,newifi-y1s)" "\txiaomi,miwifi-r3)\n\t\tucidef_add_switch \"switch0\" \"1:lan\" \"4:lan\" \"0:wan\" \"6@eth0\"\n\t\t;;" "after"
patch_by_awk "$NET_FILE" "zyxel,keenetic-lite-iii-a)" "\txiaomi,miwifi-r3)\n\t\twan_mac=\$(mtd_get_mac_binary factory 0x28)\n\t\tlan_mac=\$(macaddr_setbit_la \"\$wan_mac\")\n\t\t;;" "after"

# 7. Platform Upgrade Config
UPGRADE_FILE="target/linux/ramips/mt7620/base-files/lib/upgrade/platform.sh"
UPGRADE_BLOCK=$(cat << 'EOF'
	xiaomi,miwifi-r3)
		dd if=/dev/mtd0 bs=64 count=1 2>/dev/null | grep -qi breed && CI_KERNPART_EXT="kernel_stock"
		dd if=/dev/mtd7 bs=64 count=1 2>/dev/null | grep -o MIPS.*Linux | grep -qi X-WRT && CI_KERNPART_EXT="kernel_stock"
		dd if=/dev/mtd0 2>/dev/null | grep -qi pb-boot && CI_KERNPART_EXT="kernel_stock"
		nand_do_upgrade "$1"
		;;
EOF
)
patch_by_awk "$UPGRADE_FILE" "case \"\$board\" in" "$UPGRADE_BLOCK" "after"

# 8. Kernel Config (Dùng Update-or-Append để không phụ thuộc dòng)
CONF_FILE="target/linux/ramips/mt7620/config-6.12"
declare -A KCONFIGS=(
    ["CONFIG_CRC16"]="y" ["CONFIG_CRYPTO_DEFLATE"]="y" ["CONFIG_MTD_NAND_MT7620"]="y"
    ["CONFIG_MTD_UBI"]="y" ["CONFIG_MTD_UBI_BEB_LIMIT"]="20" ["CONFIG_MTD_UBI_BLOCK"]="y"
    ["CONFIG_UBIFS_FS"]="y" ["CONFIG_ZLIB_DEFLATE"]="y" ["CONFIG_LZO_COMPRESS"]="y"
    ["CONFIG_LZO_DECOMPRESS"]="y" ["CONFIG_REED_SOLOMON"]="y"
)

if [ -f "$CONF_FILE" ]; then
    for CFG in "${!KCONFIGS[@]}"; do
        VAL="${KCONFIGS[$CFG]}"
        if grep -qE "^(# )?$CFG([ =]|$)" "$CONF_FILE"; then
            sed -i "s/^.*$CFG.*/$CFG=$VAL/" "$CONF_FILE"
        else
            echo "$CFG=$VAL" >> "$CONF_FILE"
        fi
    done
fi

# 9. Thay thế Patch file bằng AWK (Sửa Kconfig/Makefile của Kernel)
# Tìm dòng "endmenu" và chèn config mới vào ngay phía trên
KCONFIG_KERNEL="target/linux/ramips/files/drivers/mtd/maps/Kconfig"
MAKEFILE_KERNEL="target/linux/ramips/files/drivers/mtd/maps/Makefile"

mkdir -p target/linux/ramips/files/drivers/mtd/maps/

# Chèn Kconfig driver mới
if [ -f "$KCONFIG_KERNEL" ]; then
    patch_by_awk "$KCONFIG_KERNEL" "endmenu" "config MTD_NAND_MT7620\n\ttristate \"Support for NAND on Mediatek MT7620\"\n\tdepends on RALINK && SOC_MT7620\n" "before"
fi

# Chèn Makefile driver mới
if [ -f "$MAKEFILE_KERNEL" ] && ! grep -q "ralink_nand.o" "$MAKEFILE_KERNEL"; then
    echo "obj-\$(CONFIG_MTD_NAND_MT7620)	+= ralink_nand.o" >> "$MAKEFILE_KERNEL"
fi
