#!/bin/bash
#=================================================
shopt -s extglob

sed -i '$a src-git jell https://github.com/kenzok8/jell.git;main' feeds.conf.default
sed -i "/telephony/d" feeds.conf.default

sed -i "s?targets/%S/packages?targets/%S/\$(LINUX_VERSION)?" include/feeds.mk

sed -i '/	refresh_config();/d' scripts/feeds

./scripts/feeds update -a
./scripts/feeds install -a -p jell -f
./scripts/feeds install -a

echo "$(date +"%s")" >version.date
sed -i '/$(curdir)\/compile:/c\$(curdir)/compile: package/opkg/host/compile' package/Makefile
sed -i 's/$(TARGET_DIR)) install/$(TARGET_DIR)) install --force-overwrite --force-depends/' package/Makefile
sed -i "s/DEFAULT_PACKAGES:=/DEFAULT_PACKAGES:=luci-app-firewall luci-app-opkg luci-app-upnp luci-app-upnp luci-app-mosdns luci-app-openclash luci-app-smartdns \
luci-app-wizard luci-base luci-compat luci-lib-ipkg luci-lib-fs \
coremark wget-ssl curl autocore htop nano zram-swap kmod-lib-zstd kmod-tcp-bbr bash openssh-sftp-server block-mount resolveip ds-lite swconfig luci-app-fan /" include/target.mk
sed -i "s/procd-ujail//" include/target.mk

sed -i "s/^.*vermagic$/\techo '1' > \$(LINUX_DIR)\/.vermagic/" include/kernel-defaults.mk


mv -f feeds/jell/r81* tmp/

sed -i "s/192.168.1/192.168.1.2/" package/feeds/jell/base-files/files/bin/config_generate
sed -i "s/192.168.1/192.168.1.2/" package/base-files/files/bin/config_generate

(
svn co https://github.com/coolsnowwolf/lede/trunk/target/linux/generic/hack-5.15 target/linux/generic/hack-5.15
curl -sfL https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/generic/pending-5.15/613-netfilter_optional_tcp_window_check.patch -o target/linux/generic/pending-5.15/613-netfilter_optional_tcp_window_check.patch
sed -i "s/CONFIG_WERROR=y/CONFIG_WERROR=n/" target/linux/generic/config-5.15
) &

# NeoBird
sed -i 's/^IMG_PREFIX\:\=.*/IMG_PREFIX:=$(VERSION_DIST_SANITIZED)-$(shell TZ=UTC-8 date +"%Y.%m.%d-%H%M")-$(IMG_PREFIX_VERNUM)$(IMG_PREFIX_VERCODE)$(IMG_PREFIX_EXTRA)$(BOARD)$(if $(SUBTARGET),-$(SUBTARGET))/g' include/image.mk
curl -sfL https://github.com/leesuncom/package/raw/main/99-default-settings -o feeds/kiddin9/my-default-settings/files/etc/uci-defaults/99-default-settings
# NeoBird

grep -q "23.05" include/version.mk && [ -d package/kernel/mt76 ] && {
mkdir package/kernel/mt76/patches
curl -sfL https://raw.githubusercontent.com/immortalwrt/immortalwrt/master/package/kernel/mt76/patches/0001-mt76-allow-VHT-rate-on-2.4GHz.patch -o package/kernel/mt76/patches/0001-mt76-allow-VHT-rate-on-2.4GHz.patch
} || rm -rf devices/common/patches/mt7922.patch

grep -q "1.8.8" package/network/utils/iptables/Makefile && {
rm -rf package/network/utils/iptables
svn co https://github.com/openwrt/openwrt/branches/openwrt-22.03/package/network/utils/iptables package/network/utils/iptables
}

grep -q 'PKG_RELEASE:=9' package/libs/openssl/Makefile && {
sh -c "curl -sfL https://github.com/openwrt/openwrt/commit/a48d0bdb77eb93f7fba6e055dace125c72755b6a.patch | patch -d './' -p1 --forward"
}

sed -i "/wireless.\${name}.disabled/d" package/kernel/mac80211/files/lib/wifi/mac80211.sh

sed -i "/BuildPackage,miniupnpd-iptables/d" feeds/packages/net/miniupnpd/Makefile
sed -i 's/Os/O2/g' include/target.mk
sed -i "/mediaurlbase/d" package/feeds/*/luci-theme*/root/etc/uci-defaults/*
sed -i 's/=bbr/=cubic/' package/kernel/linux/files/sysctl-tcp-bbr.conf

# find target/linux/x86 -name "config*" -exec bash -c 'cat kernel.conf >> "{}"' \;
sed -i 's/max_requests 3/max_requests 20/g' package/network/services/uhttpd/files/uhttpd.config
#rm -rf ./feeds/packages/lang/{golang,node}
sed -i "s/tty\(0\|1\)::askfirst/tty\1::respawn/g" target/linux/*/base-files/etc/inittab

sed -i "/wireless.\${name}.disabled/d" package/kernel/mac80211/files/lib/wifi/mac80211.sh || sed -i "/wireless.\${name}.disabled/d" package/network/config/wifi-scripts/files/lib/wifi/mac80211.sh

date=`date +%m.%d`
sed -i -e "/\(# \)\?REVISION:=/c\REVISION:=$date" -e '/VERSION_CODE:=/c\VERSION_CODE:=$(REVISION)' include/version.mk

sed -i \
	-e "s/+\(luci\|luci-ssl\|uhttpd\)\( \|$\)/\2/" \
	-e "s/+nginx\( \|$\)/+nginx-ssl\1/" \
	-e 's/+python\( \|$\)/+python3/' \
	-e 's?../../lang?$(TOPDIR)/feeds/packages/lang?' \
	package/feeds/jell/*/Makefile

(
if [ -f sdk.tar.xz ]; then
	sed -i 's,$(STAGING_DIR_HOST)/bin/upx,upx,' package/feeds/jell/*/Makefile
	mkdir sdk
	tar -xJf sdk.tar.xz -C sdk
	cp -rf sdk/*/staging_dir/* ./staging_dir/
	rm -rf sdk.tar.xz sdk
	sed -i '/\(tools\|toolchain\)\/Makefile/d' Makefile
	if [ -f /usr/bin/python ]; then
		ln -sf /usr/bin/python staging_dir/host/bin/python
	else
		ln -sf /usr/bin/python3 staging_dir/host/bin/python
	fi
	ln -sf /usr/bin/python3 staging_dir/host/bin/python3
fi
) &
