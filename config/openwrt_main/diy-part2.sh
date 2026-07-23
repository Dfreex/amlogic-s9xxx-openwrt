#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt (Super Light + Gaming Tuned + AdGuard Built-in + XOOD Signature)
#========================================================================================================================

# ------------------------------- Main source configuration -------------------------------
default_ip="192.168.1.1"
ip_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
[[ -n "${1}" && "${1}" != "${default_ip}" && "${1}" =~ ${ip_regex} ]] && {
    echo "Modify default IP address to: ${1}"
    sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${1}\"}/" package/base-files/*/bin/config_generate
}
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow

# --- CUSTOM SIGNATURE (FIRMWARE VERSION) ---
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d) by XOOD'|g" package/base-files/files/etc/openwrt_release
echo "DISTRIB_DESCRIPTION='OpenWrt Gaming Edition V1'" >>package/base-files/files/etc/openwrt_release
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

rm -rf package/luci-app-amlogic
git clone -b main https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic
# ------------------------------- Main source configuration ends -------------------------------


# =========================================================================================
# 1. CLONE TEMA ARGON
# =========================================================================================
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config


# =========================================================================================
# 2. INJEKSI PAKET SUPER RINGAN + TTYD
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
CONFIG_PACKAGE_luci-app-ttyd=y
EOF


# =========================================================================================
# 3. FULL AUTOMATION SCRIPT (PLUG & PLAY B860H / HG680P)
# =========================================================================================
mkdir -p package/base-files/files/etc/uci-defaults/

cat << "EOF" > package/base-files/files/etc/uci-defaults/99-custom-setup
#!/bin/sh

# --- 1. JARINGAN & FIREWALL ---
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

# --- 2. WIFI TEST ---
uci set wireless.@wifi-device[0].disabled='0'
uci set wireless.@wifi-iface[0].disabled='0'
uci set wireless.@wifi-iface[0].ssid='XOOD-Net'
uci set wireless.@wifi-iface[0].network='lan'

# --- 3. SQM & PING OPTIMIZER ---
uci set sqm.@queue[0].enabled='1'
uci set sqm.@queue[0].interface='eth1'
uci set sqm.@queue[0].download='8500'
uci set sqm.@queue[0].upload='8500'
uci set sqm.@queue[0].qdisc='cake'
uci set sqm.@queue[0].script='piece_of_cake.qos'
uci set sqm.@queue[0].linklayer='ethernet'
uci set sqm.@queue[0].overhead='44'

# --- 4. DNSMASQ, ANTI KEBOCORAN IPV6, & FORCE DNS ADGUARD ---
uci set dhcp.@dnsmasq[0].port='5353'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.ndp='disabled'
uci add_list dhcp.lan.dhcp_option='6,192.168.1.1'

# --- 5. TEMA, HOSTNAME, & TTYD AUTO-LOGIN ---
uci set luci.main.mediaurlbase='/luci-static/argon'
uci set system.@system[0].hostname='XOOD-STB'
uci set ttyd.@ttyd[0].command='/bin/login -f root'

# --- 6. AKTIFKAN ADGUARD HOME ---
uci set adguardhome.AdGuardHome=adguardhome
uci set adguardhome.AdGuardHome.enabled='1'

# Simpan semua konfigurasi uci
uci commit
uci commit ttyd

# --- 7. INJEKSI TCP BBR (ALGORITMA ANTI-LAG GOOGLE) ---
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

# --- 8. KONFIGURASI ADGUARD HOME (BYPASS WIZARD AMAN) ---
mkdir -p /etc/adguardhome
cat << "YAMLEOF" > /etc/adguardhome/adguardhome.yaml
bind_host: 0.0.0.0
bind_port: 3000
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  bootstrap_dns:
    - 8.8.8.8
    - 1.1.1.1
  upstream_dns:
    - https://dns.google/dns-query
    - https://cloudflare-dns.com/dns-query
YAMLEOF

exit 0
EOF

# =========================================================================================
# 4. DOWNLOAD CORE ADGUARD SAAT PROSES BUILD DI GITHUB
# =========================================================================================
mkdir -p files/usr/bin/AdGuardHome
wget -qO /tmp/AdGuardHome.tar.gz https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_arm64.tar.gz
tar -xzvf /tmp/AdGuardHome.tar.gz -C /tmp/
cp /tmp/AdGuardHome/AdGuardHome files/usr/bin/AdGuardHome/
chmod +x files/usr/bin/AdGuardHome/AdGuardHome

# =========================================================================================
# 5. CUSTOM TERMINAL BANNER "XOOD"
# =========================================================================================
mkdir -p package/base-files/files/etc/
cat << "EOF" > package/base-files/files/etc/banner
 __  __  ____   ____  ____  
 \ \/ / / __ \ / __ \|  _ \ 
  \  / | |  | | |  | | | | |
  /  \ | |__| | |__| | |_| |
 /_/\_\ \____/ \____/|____/ 
                            
 -----------------------------------------------------------
     FIRMWARE BY XOOD | ANTI-LAG GAMING EDITION
 -----------------------------------------------------------
EOF

# Memberikan izin eksekusi untuk script otomatisasi pertama kali
chmod +x package/base-files/files/etc/uci-defaults/99-custom-setup
