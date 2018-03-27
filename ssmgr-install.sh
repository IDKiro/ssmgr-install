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

disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

get_latest_version(){
    ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep 'tag_name' | cut -d\" -f4)
    [ -z ${ver} ] && echo "Error: Get shadowsocks-libev latest version failed" && exit 1
    shadowsocks_libev_ver="shadowsocks-libev-$(echo ${ver} | sed -e 's/^[a-zA-Z]//g')"
    download_link="https://github.com/shadowsocks/shadowsocks-libev/releases/download/${ver}/${shadowsocks_libev_ver}.tar.gz"
}

pre_install(){
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
}

download() {
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
download_files(){
    cd ${cur_dir}
    get_latest_version
    download "${shadowsocks_libev_ver}.tar.gz" "${download_link}"
    download "${libsodium_file}.tar.gz" "${libsodium_url}"
    download "${mbedtls_file}-gpl.tgz" "${mbedtls_url}"
}

install_libsodium() {
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

install_mbedtls() {
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
install_shadowsocks(){
    install_libsodium
    install_mbedtls
    ldconfig
    cd ${cur_dir}
    tar zxf ${shadowsocks_libev_ver}.tar.gz
    cd ${shadowsocks_libev_ver}
    ./configure --disable-documentation
    make && make install
    cd ${cur_dir}
    rm -rf ${shadowsocks_libev_ver} ${shadowsocks_libev_ver}.tar.gz
    rm -rf ${libsodium_file} ${libsodium_file}.tar.gz
    rm -rf ${mbedtls_file} ${mbedtls_file}-gpl.tgz
    clear

    echo "Shadowsocks-libev install completed"
}

get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

get_information(){
    # Set shadowsocks-manager password
    echo "Please enter password of shadowsocks-manager:"
    read -p "(Default password: 123456):" ssmgrpwd
    [ -z "${ssmgrpwd}" ] && ssmgrpwd="123456"

    # Set shadowsocks-libev config port
    while true
    do
    echo -e "Please enter a port for shadowsocks-libev [1-65535]"
    read -p "(Default port: 4000):" ssport
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
    read -p "(Default port: 4001):" mgrport
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
    echo -e "Please select stream cipher for shadowsocks-libev:"
    for ((i=1;i<=${#ciphers[@]};i++ )); do
        hint="${ciphers[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    read -p "Which cipher you'd select(Default: ${ciphers[0]}):" pick
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
    echo "---------------------------"
    echo -e "Server ip:                 ${ipaddress}"
    echo -e "password:                  ${ssmgrpwd}"
    echo -e "shadowsocks-libev port:    ${ssport}"
    echo -e "shadowsocks-manager port:  ${mgrport}"
    echo -e "cipher:                    ${shadowsockscipher}"
    echo "---------------------------"
    echo
}

firewall_set(){
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
    else
        echo -e "[${yellow}Warning${plain}] firewalld looks like not running or not installed."
        echo -e "[${yellow}Warning${plain}] If you use iptables, you may need to change it's setting."
    fi
    echo -e "[${green}Info${plain}] firewall set completed..."
}

install_selected(){
    while true
    do
    echo
    echo "#############################################################"
    echo "# One click Install shadowsocks-manager for Centos 7        #"
    echo "# Github: https://github.com/IDKiro/ssmgr-install           #"
    echo "# Author: IDKiro                                            #"
    echo "# Please choose the server you want                         #"
    echo "# 1  shadowsocks-manager and node                           #"
    echo "# 2  Only the node                                          #"
    echo "#############################################################"
    echo
    read -p "Please enter a number:" selected
    case "${selected}" in
        1|2)
        break
        ;;
        *)
        echo -e "[${red}Error${plain}] Please only enter a number [1-2]"
        ;;
    esac
    done
}

install_nodejs(){
	curl -sL https://rpm.nodesource.com/setup_6.x | bash -
    yum install -y nodejs
}

npm_install_ssmgr(){
	npm i -g shadowsocks-manager
    npm i -g pm2
}

get_ssmgrt(){
    cd /root
    git clone https://github.com/gyteng/shadowsocks-manager-tiny.git
    npm i -g pm2
}

set_ssmgr(){
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

set_ssmgr_startup(){
    pm2 --name "webgui" -f start ssmgr -x -- -c /root/.ssmgr/webgui.yml
    pm2 --name "ss" -f start ssmgr -x -- -c /root/.ssmgr/ss.yml -r libev:${shadowsockscipher}
    pm2 save
    pm2 startup
}

set_ssmgrt_startup(){
    pm2 --name "ss" -f start /root/shadowsocks-manager-tiny/index.js -x -- 127.0.0.1:${ssport} 0.0.0.0:${mgrport} ${ssmgrpwd} libev:${shadowsockscipher}
    pm2 save
    pm2 startup
}

install_ssmgr(){
    npm_install_ssmgr
    set_ssmgr
    set_ssmgr_startup
}

install_ssmgrt(){
    get_ssmgrt
    set_ssmgrt_startup
}

# Installation start
install_selected
get_information
disable_selinux
pre_install
download_files
install_shadowsocks
firewall_set
install_nodejs
if [ "${selected}" == "1" ]; then
    install_ssmgr
else
    install_ssmgrt
fi

echo "#############################################################"
echo "# Install shadowsocks-manager  Success                      #"
echo "# Author: IDKiro                                            #"
echo "# Github: https://github.com/IDKiro/ssmgr-install           #"
echo "#############################################################"
