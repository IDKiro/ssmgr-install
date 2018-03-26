#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Current folder
cur_dir=`pwd`

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

install_nodejs(){
	curl -sL https://rpm.nodesource.com/setup_6.x | bash -
    yum install -y nodejs
}

install_ssmgr(){
	npm i -g shadowsocks-manager
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
