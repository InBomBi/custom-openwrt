#!/bin/bash

# --- Hàm hỗ trợ chèn nội dung an toàn ---
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

# 2. Cấu hình DTS cho TPLINK WR841
DTS_WR841="target/linux/ath79/dts/qca9533_tplink_tl-wr841.dtsi"
if [ -f "$DTS_WR841" ]; then
    sed -i 's/reg = <0x020000 0x3d0000>;/reg = <0x020000 0xfd0000>;/g' "$DTS_WR841"
    sed -i 's/partition@3f0000/partition@ff0000/g' "$DTS_WR841"
    sed -i 's/reg = <0x3f0000 0x010000>;/reg = <0x0xff0000 0x010000>;/g' "$DTS_WR841"
fi

# 3. Cấu hình Image Makefile
sed -i 's/Device\/tplink-4mlzma/Device\/tplink-16mlzma/g' target/linux/ath79/image/tiny-tp-link.mk
patch_by_awk "target/linux/ramips/mt7620/target.mk" "FEATURES\+=usb" "FEATURES+=nand" "after"

# 4. Tạo các file mới cho Xiaomi R3 (DTS & NAND Driver)
mkdir -p target/linux/ramips/dts/
mkdir -p target/linux/ramips/files/drivers/mtd/maps/

# --- [Đoạn cat << 'EOF' cho mt7620a_xiaomi_miwifi-r3.dts, ralink_nand.c, ralink_nand.h của bạn giữ nguyên ở đây] ---

# 5. Cấu hình mt7620.mk bằng AWK (Chống lệch dòng)
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
    awk -v new_dev="$DEVICE_R3_DEF" '/define Device\/youku_x2/ { f=1 } f && /endef/ { print $0; print ""; print new_dev; f=0; next } { print }' "$TARGET_MK" > "$TARGET_MK.tmp" && mv "$TARGET_MK.tmp" "$TARGET_MK"
fi

# 6 & 7. Network & Platform Upgrade (Giữ nguyên logic AWK an toàn)
# ... [Phần 6 và 7 của bạn giữ nguyên] ...

# 8. Kernel Config (Sửa lỗi "Enable UBI" bằng cách khai báo đầy đủ phụ thuộc)
CONF_FILE="target/linux/ramips/mt7620/config-6.12"
if [ -f "$CONF_FILE" ]; then
    sed -i '$a\' "$CONF_FILE" # Đảm bảo có dòng trống cuối file
    cat << 'EOF' >> "$CONF_FILE"
CONFIG_MTD_NAND_MT7620=y
CONFIG_MTD_UBI=y
CONFIG_MTD_UBI_WL_THRESHOLD=4096
CONFIG_MTD_UBI_BEB_LIMIT=20
CONFIG_MTD_UBI_BLOCK=y
CONFIG_UBIFS_FS=y
CONFIG_UBIFS_FS_ADVANCED_COMPR=y
CONFIG_CRC16=y
CONFIG_CRYPTO_DEFLATE=y
CONFIG_LZO_COMPRESS=y
CONFIG_LZO_DECOMPRESS=y
EOF
fi

# 9. Kconfig & Makefile Kernel (Sửa lỗi TAB để vượt qua syncconfig)
KCONFIG_KERNEL="target/linux/ramips/files/drivers/mtd/maps/Kconfig"
MAKEFILE_KERNEL="target/linux/ramips/files/drivers/mtd/maps/Makefile"

if [ -f "$KCONFIG_KERNEL" ] && ! grep -q "MTD_NAND_MT7620" "$KCONFIG_KERNEL"; then
    # Sử dụng Tab thực sự (\t) cho Kconfig
    printf "config MTD_NAND_MT7620\n\ttristate \"Support for NAND on Mediatek MT7620\"\n\tdepends on RALINK && SOC_MT7620\n\n" > kconfig_part.tmp
    awk '/endmenu/ { system("cat kconfig_part.tmp"); print $0; next } { print }' "$KCONFIG_KERNEL" > "$KCONFIG_KERNEL.tmp" && mv "$KCONFIG_KERNEL.tmp" "$KCONFIG_KERNEL"
    rm kconfig_part.tmp
fi

if [ -f "$MAKEFILE_KERNEL" ] && ! grep -q "ralink_nand.o" "$MAKEFILE_KERNEL"; then
    sed -i '$a\' "$MAKEFILE_KERNEL"
    echo "obj-\$(CONFIG_MTD_NAND_MT7620)	+= ralink_nand.o" >> "$MAKEFILE_KERNEL"
fi
