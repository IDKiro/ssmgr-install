#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Current folder
cur_dir=`pwd`

libsodium_file="libsodium-1.0.16"
libsodium_url="https://github.com/jedisct1/libsodium/releases/download/1.0.16/libsodium-1.0.16.tar.gz"

mbedtls_file="mbedtls-2.6.0"
mbedtls_url="https://tls.mbed.org/download/mbedtls-2.6.0-gpl.tgz"

ciphers=(
aes-256-cfb
aes-192-cfb
aes-128-cfb
aes-256-ctr
aes-192-ctr
aes-128-ctr
camellia-256-cfb
camellia-192-cfb
camellia-128-cfb
aes-256-gcm
aes-192-gcm
aes-128-gcm
chacha20-ietf
chacha20-ietf-poly1305
)
# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1

check_sys()
{
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ ${checkType} == "sysRelease" ]]; then
        if [ "$value" == "$release" ]; then
            return 0
        else
            return 1
        fi
    elif [[ ${checkType} == "packageManager" ]]; then
        if [ "$value" == "$systemPackage" ]; then
            return 0
        else
            return 1
        fi
    fi
}

getversion()
{
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

centosversion()
{
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

check_centos()
{
    if check_sys sysRelease centos; then
        if centosversion 5; then
            echo -e "[${red}Error${plain}] The script don't support CentOS 5."
            exit 1
        fi
    else
        echo -e "[${red}Error${plain}] The script only support CentOS."
        exit 1
    fi
}

disable_selinux()
{
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

get_latest_version()
{
    ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep 'tag_name' | cut -d\" -f4)
    [ -z ${ver} ] && echo "Error: Get shadowsocks-libev latest version failed" && exit 1
    shadowsocks_libev_ver="shadowsocks-libev-$(echo ${ver} | sed -e 's/^[a-zA-Z]//g')"
    download_link="https://github.com/shadowsocks/shadowsocks-libev/releases/download/${ver}/${shadowsocks_libev_ver}.tar.gz"
}

pre_install()
{
    echo -e "[${green}Info${plain}] Checking the EPEL repository..."
    if [ ! -f /etc/yum.repos.d/epel.repo ]; then
        yum install -y -q epel-release
    fi
    [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "[${red}Error${plain}] Install EPEL repository failed, please check it." && exit 1
    [ ! "$(command -v yum-config-manager)" ] && yum install -y -q yum-utils
    if [ x"`yum-config-manager epel | grep -w enabled | awk '{print $3}'`" != x"True" ]; then
        yum-config-manager --enable epel
    fi
    echo -e "[${green}Info${plain}] Checking the EPEL repository complete..."
    yum install -y -q unzip openssl openssl-devel gettext gcc autoconf libtool automake make asciidoc xmlto libev-devel pcre pcre-devel git c-ares-devel
    yum update -y nss curl
}

download()
{
    local filename=${1}
    local cur_dir=`pwd`
    if [ -s ${filename} ]; then
        echo -e "[${green}Info${plain}] ${filename} [found]"
    else
        echo -e "[${green}Info${plain}] ${filename} not found, download now..."
        wget --no-check-certificate -cq -t3 -T3 -O ${1} ${2}
        if [ $? -eq 0 ]; then
            echo -e "[${green}Info${plain}] ${filename} download completed..."
        else
            echo -e "[${red}Error${plain}] Failed to download ${filename}, please download it to ${cur_dir} directory manually and try again."
            exit 1
        fi
    fi
}

# Download latest shadowsocks-libev
download_files()
{
    cd ${cur_dir}
    get_latest_version
    download "${shadowsocks_libev_ver}.tar.gz" "${download_link}"
    download "${libsodium_file}.tar.gz" "${libsodium_url}"
    download "${mbedtls_file}-gpl.tgz" "${mbedtls_url}"
}

check_installed()
{
    if [ "$(command -v "$1")" ]; then
        return 0
    else
        return 1
    fi
}

install_libsodium()
{
    if [ ! -f /usr/lib/libsodium.a ]; then
        cd ${cur_dir}
        tar zxf ${libsodium_file}.tar.gz
        cd ${libsodium_file}
        ./configure --prefix=/usr && make && make install
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] ${libsodium_file} install failed."
            exit 1
        fi
    else
        echo -e "[${green}Info${plain}] ${libsodium_file} already installed."
    fi
}

install_mbedtls()
{
    if [ ! -f /usr/lib/libmbedtls.a ]; then
        cd ${cur_dir}
        tar xf ${mbedtls_file}-gpl.tgz
        cd ${mbedtls_file}
        make SHARED=1 CFLAGS=-fPIC
        make DESTDIR=/usr install
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] ${mbedtls_file} install failed."
            exit 1
        fi
    else
        echo -e "[${green}Info${plain}] ${mbedtls_file} already installed."
    fi
}

# Install Shadowsocks-libev
install_shadowsocks()
{
    install_libsodium
    install_mbedtls
    ldconfig
    check_installed "ss-server"
    if [ $? -eq 0 ]; then
        echo -e "[${green}Info${plain}] Shadowsocks-libev has already been installed, nothing to do..."
    else
        cd ${cur_dir}
        tar zxf ${shadowsocks_libev_ver}.tar.gz
        cd ${shadowsocks_libev_ver}
        ./configure --disable-documentation
        make && make install
    fi
    cd ${cur_dir}
    rm -rf ${shadowsocks_libev_ver} ${shadowsocks_libev_ver}.tar.gz
    rm -rf ${libsodium_file} ${libsodium_file}.tar.gz
    rm -rf ${mbedtls_file} ${mbedtls_file}-gpl.tgz
    clear
    echo "Shadowsocks-libev install completed"
}

get_ip()
{
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

get_information()
{
    # Set shadowsocks-manager password
    echo "Please enter password of shadowsocks-manager: "
    stty erase '^H' && read -p "(Default password: 123456): " ssmgrpwd
    [ -z "${ssmgrpwd}" ] && ssmgrpwd="123456"

    # Set shadowsocks-libev config port
    while true
    do
    echo -e "Please enter a port for shadowsocks-libev [1-65535]"
    stty erase '^H' && read -p "(Default port: 4000): " ssport
    [ -z "$ssport" ] && ssport=4000
    expr ${ssport} + 1 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${ssport} -ge 1 ] && [ ${ssport} -le 65535 ] && [ ${ssport:0:1} != 0 ]; then
            break
        fi
    fi
    echo -e "[${red}Error${plain}] Please enter a correct number [1-65535]"
    done

    # Set shadowsocks-manager config port
    while true
    do
    echo -e "Please enter a port for shadowsocks-manager [1-65535]"
    stty erase '^H' && read -p "(Default port: 4001): " mgrport
    [ -z "$mgrport" ] && mgrport=4001
    expr ${mgrport} + 1 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${mgrport} -ge 1 ] && [ ${mgrport} -le 65535 ] && [ ${mgrport:0:1} != 0 ]; then
            break
        fi
    fi
    echo -e "[${red}Error${plain}] Please enter a correct number [1-65535]"
    done

    # Set shadowsocks config stream ciphers
    while true
    do
    echo -e "Please select stream cipher for shadowsocks-libev: "
    for ((i=1;i<=${#ciphers[@]};i++ )); do
        hint="${ciphers[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    stty erase '^H' && read -p "Which cipher you'd select(Default: ${ciphers[0]}): " pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Please enter a number"
        continue
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#ciphers[@]} ]]; then
        echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#ciphers[@]}"
        continue
    fi
    shadowsockscipher=${ciphers[$pick-1]}
    break
    done

    ipaddress="$(get_ip)"

    echo
    echo "-----------------------------------------------------"
    echo -e "Server ip:                 ${ipaddress}"
    echo -e "password:                  ${ssmgrpwd}"
    echo -e "shadowsocks-libev port:    ${ssport}"
    echo -e "shadowsocks-manager port:  ${mgrport}"
    echo -e "cipher:                    ${shadowsockscipher}"
    echo "-----------------------------------------------------"
    echo
}

firewall_set()
{
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ssport} -j ACCEPT
            iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${ssport} -j ACCEPT
            iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${mgrport} -j ACCEPT
            iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${mgrport} -j ACCEPT
            iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
            iptables -I INPUT -m state --state NEW -m udp -p udp --dport 80 -j ACCEPT
            iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 50000:60000 -j ACCEPT
            iptables -I INPUT -m state --state NEW -m udp -p udp --dport 50000:60000 -j ACCEPT
            /etc/init.d/iptables save
            /etc/init.d/iptables restart
            echo -e "[${green}Info${plain}] Set up the iptables successfully."
        else
            echo -e "[${yellow}Warning${plain}] iptables looks like shutdown or not installed."
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            firewall-cmd --permanent --zone=public --add-port=${ssport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${ssport}/udp
            firewall-cmd --permanent --zone=public --add-port=${mgrport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${mgrport}/udp
            firewall-cmd --permanent --zone=public --add-port=80/tcp
            firewall-cmd --permanent --zone=public --add-port=80/udp
            firewall-cmd --permanent --zone=public --add-port=50000-60000/tcp
            firewall-cmd --permanent --zone=public --add-port=50000-60000/udp
            firewall-cmd --reload
            echo -e "[${green}Info${plain}] Set up the firewall successfully."
        else
            echo -e "[${yellow}Warning${plain}] firewall looks like not running or not installed."
            echo -e "[${yellow}Warning${plain}] If you use iptables, you may need to change it's setting."
        fi
    fi
    echo -e "[${green}Info${plain}] firewall set completed..."
}

install_selected()
{
    clear
    while true
    do
    echo
    echo "###########################################################"
    echo "# One click Install shadowsocks-manager for CentOS        #"
    echo "# Github: https://github.com/IDKiro/ssmgr-install         #"
    echo "# Author: IDKiro                                          #"
    echo "# Please choose the server you want                       #"
    echo "# 1. shadowsocks-manager and node                         #"
    echo "# 2. Only the node                                        #"
    echo "# 3. Enable the BBRmod                                    #"
    echo "###########################################################"
    echo
    stty erase '^H' && read -p "Please enter a number: " selected
    case "${selected}" in
        1|2|3)
        break
        ;;
        *)
        echo -e "[${red}Error${plain}] Please only enter a number [1-3]"
        ;;
    esac
    done
}

install_nodejs()
{
    check_installed "node"
    if [ $? -eq 0 ]; then
        node_ver=$(node -v | cut -b 2)
        if [ ${node_ver} -eq 8 ]; then
            echo -e "[${green}Info${plain}] nodejs v8 has already been installed, nothing to do..."
        else
            echo -e "[${red}Error${plain}] Other version nodejs has been installed..."
            exit 1
        fi
    else
        curl -sL https://rpm.nodesource.com/setup_8.x | bash -
        yum install -y nodejs
    fi
}

npm_install_ssmgr()
{
    cd /root
    git clone https://github.com/IDKiro/shadowsocks-manager.git
    cd shadowsocks-manager
    npm i
    npm i -g pm2
}

get_ssmgrt()
{
    cd /root
    git clone https://github.com/IDKiro/shadowsocks-manager-tiny.git
    npm i -g pm2
}

set_ssmgr()
{
    mkdir /root/.ssmgr
    wget -N -P  /root/.ssmgr/ https://raw.githubusercontent.com/IDKiro/ssmgr-install/master/ss.yml
    sed -i "s#4000#${ssport}#g" /root/.ssmgr/ss.yml
    sed -i "s#4001#${mgrport}#g" /root/.ssmgr/ss.yml
    sed -i "s#passwd#${ssmgrpwd}#g" /root/.ssmgr/ss.yml
    wget -N -P  /root/.ssmgr/ https://raw.githubusercontent.com/IDKiro/ssmgr-install/master/webgui.yml
    sed -i "s#12.34.56.78#${ipaddress}#g" /root/.ssmgr/webgui.yml
    sed -i "s#4000#${ssport}#g" /root/.ssmgr/webgui.yml
    sed -i "s#passwd#${ssmgrpwd}#g" /root/.ssmgr/webgui.yml
}

set_mailgun()
{
    echo "Please enter baseUrl of mailgun: "
    stty erase '^H' && read -p "(Example: https://api.mailgun.net/v3/mg.xxxxx.xxx): " mailgunurl
    echo "Please enter apiKey of mailgun: "
    stty erase '^H' && read -p "(Example: key-xxxxxxxxxxxxx): " mailgunkey
    sed -i "s#https://api.mailgun.net/v3/mg.xxxxx.xxx#${mailgunurl}#g" /root/.ssmgr/webgui.yml
    sed -i "s#key-xxxxxxxxxxxxx#${mailgunkey}#g" /root/.ssmgr/webgui.yml
}

set_smtp()
{
    sed -i "s#type: 'mailgun'#type: 'smtp'#g" /root/.ssmgr/webgui.yml
    sed -i "s#baseUrl: 'https://api.mailgun.net/v3/mg.xxxxx.xxx'#username: 'user_name'#g" /root/.ssmgr/webgui.yml
    sed -i "s#apiKey: 'key-xxxxxxxxxxxxx'#password: 'password'#g" /root/.ssmgr/webgui.yml
    sed -i 'N;28a\\t\thost: 'smtp.your-email.com'' /root/.ssmgr/webgui.yml
    stty erase '^H' && read -p "Please enter host of SMTP:(smtp.your-email.com): " smtphost
    stty erase '^H' && read -p "Please enter username of your email: " smtpusrname
    stty erase '^H' && read -p "Please enter password of your email: " smtppasswd
    sed -i "s#user_name#${smtpusrname}#g" /root/.ssmgr/webgui.yml
    sed -i "s#password#${smtppasswd}#g" /root/.ssmgr/webgui.yml
    sed -i "s#smtp.your-email.com#${smtphost}#g" /root/.ssmgr/webgui.yml
}

set_mail()
{
    clear
    while true
    do
    echo
    echo "###############################################"
    echo "# Everything almost completed!                #"
    echo "# Please choose the email server you want:     #"
    echo "# 1. mailgun                                  #"
    echo "# 2. others                                   #"
    echo "###############################################"
    echo
    stty erase '^H' && read -p "Please enter a number: " mailselected
    case "${mailselected}" in
        1|2)
        break
        ;;
        *)
        echo -e "[${red}Error${plain}] Please only enter a number [1-2]"
        ;;
    esac
    done
    if [ "${mailselected}" == "1" ]; then
        set_mailgun
    else
        set_smtp
    fi
}

set_ssmgr_startup()
{
    pm2 --name "webgui" -f start /root/shadowsocks-manager/server.js -x -- -c /root/.ssmgr/webgui.yml
    pm2 --name "ss" -f start /root/shadowsocks-manager/server.js -x -- -c /root/.ssmgr/ss.yml -r libev:${shadowsockscipher}
    pm2 save
    pm2 startup
}

set_ssmgrt_startup()
{
    pm2 --name "ss" -f start /root/shadowsocks-manager-tiny/index.js -x -- 127.0.0.1:${ssport} 0.0.0.0:${mgrport} ${ssmgrpwd} libev:${shadowsockscipher}
    pm2 save
    pm2 startup
}

install_ssmgr()
{
    npm_install_ssmgr
    set_ssmgr
    set_mail
    set_ssmgr_startup
}

install_ssmgrt()
{
    get_ssmgrt
    set_ssmgrt_startup
}

detele_kernel()
{
    rpm_total=`rpm -qa | grep kernel | grep -v "4.11.8" | grep -v "noarch" | wc -l`
    if [ "${rpm_total}" > "1" ]; then
        for((integer = 1; integer <= ${rpm_total}; integer++)); do
            rpm_del=`rpm -qa | grep kernel | grep -v "4.11.8" | grep -v "noarch" | head -${integer}`
            yum remove -y ${rpm_del}
        done
        echo -e "[${green}Info${plain}] Successfully removed the kernel!"
    else
        echo -e "[${red}Error${plain}] Failed to remove the kernel..." && exit 1
    fi
}

BBR_grub()
{
    if centosversion 6; then
        if [ ! -f "/boot/grub/grub.conf" ]; then
            echo -e "[${red}Error${plain}] Can not find the file: /boot/grub/grub.conf"
            exit 1
        fi
        sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
    elif centosversion 7; then
        if [ ! -f "/boot/grub2/grub.cfg" ]; then
            echo -e "[${red}Error${plain}] Can not find the file: /boot/grub2/grub.cfg"
            exit 1
        fi
        grub2-set-default 0
    fi
}

install_bbr()
{
    if centosversion 6; then
        rpm --import http://raw.githubusercontent.com/IDKiro/ssmgr-install/master/bbr/RPM-GPG-KEY-elrepo.org
        yum install -y http://raw.githubusercontent.com/IDKiro/ssmgr-install/master/bbr/centos6/kernel-ml-4.11.8.rpm
        yum remove -y kernel-headers
        yum install -y http://raw.githubusercontent.com/IDKiro/ssmgr-install/master/bbr/centos6/kernel-ml-headers-4.11.8.rpm
        yum install -y http://raw.githubusercontent.com/IDKiro/ssmgr-install/master/bbr/centos6/kernel-ml-devel-4.11.8.rpm
    elif centosversion 7; then
        rpm --import http://raw.githubusercontent.com/IDKiro/ssmgr-install/master/bbr/RPM-GPG-KEY-elrepo.org
        yum install -y http://raw.githubusercontent.com/IDKiro/ssmgr-install/master/bbr/centos7/kernel-ml-4.11.8.rpm
        yum remove -y kernel-headers
        yum install -y http://raw.githubusercontent.com/IDKiro/ssmgr-install/master/bbr/centos7/kernel-ml-headers-4.11.8.rpm
        yum install -y http://raw.githubusercontent.com/IDKiro/ssmgr-install/master/bbr/centos7/kernel-ml-devel-4.11.8.rpm
    fi

    detele_kernel
	BBR_grub
	echo -e "[${green}Info${plain}] Now you need to reboot to make the bbr work."
	stty erase '^H' && read -p "[${green}Info${plain}] Do you like to reboot right now? [Y/n] : " yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
		echo -e "${Info} Rebooting..."
		reboot
	fi
}

check_bbr()
{
    stty erase '^H' && read -p "Do you like to install the BBRmod?[Y/n]: " yn
    [ -z "$yn" ] && yn="y"
    if [[ $yn == [Yy] ]]; then
        echo -e "[${green}Info${plain}] Start installing the BBRmod..."
        install_bbr
    fi
}

remove_all()
{
	sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sed -i '/fs.file-max/d' /etc/sysctl.conf
	sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
	sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
	sed -i '/net.core.rmem_default/d' /etc/sysctl.conf
	sed -i '/net.core.wmem_default/d' /etc/sysctl.conf
	sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
	sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_recycle/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_keepalive_time/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
	sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
	sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
	sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
	sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.conf
	sleep 1s
}

startbbrmod()
{
	remove_all
    yum install -y gcc
    mkdir bbrmod && cd bbrmod
    wget -N --no-check-certificate http://raw.githubusercontent.com/IDKiro/ssmgr-install/master/bbr/tcp_tsunami.c
    echo "obj-m:=tcp_tsunami.o" > Makefile
    make -C /lib/modules/$(uname -r)/build M=`pwd` modules CC=/usr/bin/gcc
    chmod +x ./tcp_tsunami.ko
    cp -rf ./tcp_tsunami.ko /lib/modules/$(uname -r)/kernel/net/ipv4
    insmod tcp_tsunami.ko
    depmod -a

	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=tsunami" >> /etc/sysctl.conf
	sysctl -p
    cd .. && rm -rf bbrmod
	echo -e "[${green}Info${plain}] Successfully ran the BBRmod!" && exit 0
}


# Installation start
check_centos
install_selected
if [ "${selected}" == "3" ]; then
    startbbrmod 
fi
get_information
disable_selinux
pre_install
download_files
install_shadowsocks
firewall_set
install_nodejs
if [ "${selected}" == "1" ]; then
    install_ssmgr
elif [ "${selected}" == "2" ]; then
    install_ssmgrt
fi
check_bbr

clear

echo "#############################################################"
echo "# Install shadowsocks-manager  Success                      #"
echo "# Author: IDKiro                                            #"
echo "# Github: https://github.com/IDKiro/ssmgr-install           #"
echo "#############################################################"
