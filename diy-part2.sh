#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate
# sed -i -e 's/3.3.4/3.2.2/g' -e 's/fe6a30f97d54e029768f2ddf4923699c416cdbc3a6e96db3e2d5716c7db96a34/96c57558871a6748de5bc9f274e93f4b5aad06cd8f37befa0e8d94e7b8a423bc/g'  feeds/packages/lang/ruby/Makefile
# sed -i -e 's/libpcre/libpcre2/g' package/feeds/telephony/freeswitch/Makefile
# sed -i -e 's/PKG_RELEASE:=1/PKG_RELEASE:=2/g' package/feeds/telephony/freeswitch/Makefile
sed -i 's/python3-pysocks/python3-socks/g' package/feeds/packages/onionshare-cli/Makefile || true
sed -i 's/python3-unidecode/python3-Unidecode/g' package/feeds/packages/onionshare-cli/Makefile || true
