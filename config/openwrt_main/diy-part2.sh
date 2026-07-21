#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: DIY script (After updating feeds — modify the default IP, hostname, theme, add/remove packages, etc.)
# Source code repository: https://github.com/openwrt/openwrt / Branch: main
#========================================================================================================================

# ------------------------------- Main source configuration -------------------------------
default_ip="192.168.1.1"
ip_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
[[ -n "${1}" && "${1}" != "${default_ip}" && "${1}" =~ ${ip_regex} ]] && {
    echo "Modify default IP address to: ${1}"
    sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${1}\"}/" package/base-files/*/bin/config_generate
}
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEREPO='github.com/openwrt/openwrt'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='openwrt'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEBRANCH='main'" >>package/base-files/files/etc/openwrt_release

if [[ "${2}" == "true" ]]; then
    echo "CONFIG_DEVEL=y" >>.config
    echo "CONFIG_CCACHE=y" >>.config
    echo 'CONFIG_CCACHE_DIR="$(TOPDIR)/.ccache"' >>.config
else
    echo '# CONFIG_DEVEL is not set' >>.config
    echo "# CONFIG_CCACHE is not set" >>.config
    echo 'CONFIG_CCACHE_DIR=""' >>.config
fi

# Add luci-app-amlogic (Untuk memantau suhu STB)
rm -rf package/luci-app-amlogic
git clone -b main https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic
# ------------------------------- Main source configuration ends -------------------------------


# =========================================================================================
# 1. CLONE TEMA ARGON (GAYA REYRE)
# =========================================================================================
# Mengambil Tema Argon versi terbaru dan Plugin pengubah Wallpaper Login
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config


# =========================================================================================
# 2. INJEKSI SEMUA PAKET (WIFI, SQM, ADGUARD, TEMA ARGON)
# =========================================================================================
cat >> .config <<EOF
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_PACKAGE_wireless-tools=y
CONFIG_PACKAGE_wpad-basic-mbedtls=y
CONFIG_PACKAGE_iw=y
CONFIG_PACKAGE_hostapd-common=y
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_sqm-scripts-tc-cake=y
CONFIG_PACKAGE_kmod-sched-cake=y
CONFIG_PACKAGE_luci-app-adguardhome=y
EOF


# =========================================================================================
# 3. FULL AUTOMATION SCRIPT (PLUG & PLAY UNTUK STB B860H)
# =========================================================================================
mkdir -p package/base-files/files/etc/uci-defaults/

cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-setup
#!/bin/sh

# --- 1. KONFIGURASI JARINGAN ---
uci set network.br_lan=device
uci set network.br_lan.name='br-lan'
uci set network.br_lan.type='bridge'
uci add_list network.br_lan.ports='eth0'

uci set network.lan=interface
uci set network.lan.device='br-lan'
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.1'
uci set network.lan.netmask='255.255.255.0'

uci set network.wan=interface
uci set network.wan.proto='dhcp'
uci set network.wan.device='eth1'

uci set firewall.@zone[0].network='lan'
uci set firewall.@zone[1].network='wan wan6'

# --- 2. KONFIGURASI WIFI TEST ---
uci set wireless.@wifi-device[0].disabled='0'
uci set wireless.@wifi-iface[0].disabled='0'
uci set wireless.@wifi-iface[0].ssid='OpenWrt-STB'
uci set wireless.@wifi-iface[0].network='lan'

# --- 3. KONFIGURASI SQM (ANTI-LAG GAMING 10MBPS) ---
uci set sqm.@queue[0].enabled='1'
uci set sqm.@queue[0].interface='eth1'
uci set sqm.@queue[0].download='8500'
uci set sqm.@queue[0].upload='8500'
uci set sqm.@queue[0].qdisc='cake'
uci set sqm.@queue[0].script='piece_of_cake.qos'
uci set sqm.@queue[0].linklayer='none'

# --- 4. KONFIGURASI DNSMASQ & ADGUARD ---
uci set dhcp.@dnsmasq[0].port='5353'
uci set adguardhome.AdGuardHome=adguardhome
uci set adguardhome.AdGuardHome.enabled='1'

# --- 5. JADIKAN TEMA ARGON SEBAGAI TEMA UTAMA ---
# Secara otomatis mengganti tema bawaan (bootstrap) menjadi Tema Argon
uci set luci.main.mediaurlbase='/luci-static/argon'

# Simpan semua konfigurasi LuCI dan Sistem
uci commit luci
uci commit network
uci commit firewall
uci commit wireless
uci commit sqm
uci commit dhcp
uci commit adguardhome

# --- 6. BYPASS WIZARD ADGUARD HOME ---
mkdir -p /etc/adguardhome
cat << "YAMLEOF" > /etc/adguardhome.yaml
bind_host: 0.0.0.0
bind_port: 3000
dns:
  bind_hosts:
  - 0.0.0.0
  port: 53
  bootstrap_dns:
  - 1.1.1.1
  - 8.8.8.8
  upstream_dns:
  - 1.1.1.1
  - 8.8.8.8
filters:
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
    name: AdGuard DNS filter
    id: 1
YAMLEOF

exit 0
EOF

chmod +x package/base-files/files/etc/uci-defaults/99-custom-setup
