#!/bin/bash

# 颜色定义
Red="\033[31m"
Green="\033[32m"
Yellow="\033[33m"
Nc="\033[0m"
Red_globa="\033[41;37m"
Green_globa="\033[42;37m"
Info="${Green}[信息]${Nc}"
Error="${Red}[错误]${Nc}"
Tip="${Yellow}[提示]${Nc}"

# 检查是否是 root
check_root(){
    if [ "$(id -u)" != "0" ]; then
        echo -e "${Error} 需要使用 root 用户运行，请使用 ${Green_globa}sudo -i${Nc}"
        exit 1
    fi
}

# 获取系统信息
detect_os(){
    if [ -e /etc/os-release ]; then
        . /etc/os-release
        release=$ID
    fi
    os_version="${VERSION_ID%%.*}"

    case "$release" in
        ubuntu|debian|kali|armbian) pkg_update="apt update -y" && pkg_install="apt install -y" ;;
        centos|almalinux|rocky|oracle) pkg_update="yum update -y" && pkg_install="yum install -y" ;;
        fedora|amzn) pkg_update="dnf update -y" && pkg_install="dnf install -y" ;;
        arch|manjaro|parch) pkg_update="pacman -Syu" && pkg_install="pacman -Syu --noconfirm" ;;
        alpine) pkg_update="apk update" && pkg_install="apk add" ;;
        opensuse-tumbleweed) pkg_update="zypper refresh" && pkg_install="zypper -q install -y" ;;
        *) echo -e "${Error} 不支持的系统：$release" && exit 1 ;;
    esac
}

# 安装必要组件
install_tools(){
    $pkg_update &> /dev/null
    $pkg_install net-tools &> /dev/null
}

# 设置 root 密码
set_root_passwd(){
    echo -e "${Tip} 输入新的 root 密码："
    read -s passwd
    if [ -z "$passwd" ]; then
        echo -e "${Error} 密码不能为空"
        exit 1
    fi
    echo root:$passwd | chpasswd
}

# 设置 SSH 端口
configure_ssh(){
    old_port=$(grep -E '^#?Port' /etc/ssh/sshd_config | awk '{print $2}' | head -n 1)
    echo -e "${Tip} 输入新的 SSH 端口（留空使用默认端口 $old_port）："
    read port
    port=${port:-$old_port}

    if [[ $port -lt 22 || $port -gt 65535 ]]; then
        echo -e "${Error} 无效端口"
        port=$old_port
    fi

    sed -i "s/^#\?Port.*/Port $port/" /etc/ssh/sshd_config
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*

    if command -v systemctl &> /dev/null; then
        systemctl restart sshd
    else
        service ssh restart
    fi

    echo
    echo -e "${Info} SSH 配置完成"
    echo -e "${Info} 新端口: ${Red_globa} $port ${Nc}"
    echo -e "${Info} 用户名: ${Red_globa} root ${Nc}"
    echo -e "${Info} 密码:   ${Red_globa} $passwd ${Nc}"
}

main(){
    check_root
    detect_os
    install_tools
    set_root_passwd
    configure_ssh
}

main
