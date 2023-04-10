#!/bin/bash

function blue(){
  echo -e "\033[34m\033[01m$1\033[0m"
}
function green(){
  echo -e "\033[32m\033[01m$1\033[0m"
}
function red(){
  echo -e "\033[31m\033[01m$1\033[0m"
}
function version_lt(){
  test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1";
}

#copy from 秋水逸冰 ss scripts
if [[ -f /etc/redhat-release ]]; then
  release_os="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
  release_os="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
  release_os="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
  release_os="centos"
elif cat /proc/version | grep -Eqi "debian"; then
  release_os="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
  release_os="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
  release_os="centos"
fi

if [ "$release_os" == "centos" ]; then
  systemPackage_os="yum"
elif [ "$release_os" == "ubuntu" ]; then
  systemPackage_os="apt"
elif [ "$release_os" == "debian" ]; then
  systemPackage_os="apt"
fi


#安装zerotier和ztncui
function creat_ztncui(){
  green "安装zerotier软件"
  curl -s https://install.zerotier.com/ | sudo bash
  green "启动zerotier"
  systemctl start zerotier-one.service
  systemctl enable zerotier-one.service
  green "安装ztncui软件"
  curl -O https://s3-us-west-1.amazonaws.com/key-networks/deb/ztncui/1/x86_64/ztncui_0.8.13_amd64.deb
  sudo apt-get install ./ztncui_0.8.6_amd64.deb
  green "修改.env文件"
  echo "HTTPS_PORT = 3443" >>  /opt/key-networks/ztncui/.env
  green "重启ztncui服务"
  sudo systemctl restart ztncui
  red "安装完成，请在web端登录ztncui控制台，https://ip:3443，账户：admin 密码：password。创建局域网并获取ID"
  red "获取ID并设置好局域网以后，请按任意键返回进行第2步"
  sleep 1s
  read -s -n1 -p "按任意键返回菜单 ... "
  start_menu
}

#创建moon节点
function creat_moon(){
  blue "加入你ztncui的虚拟局域网中"
  read -p "请输入你的ztncui虚拟局域网ID号：" you_net_ID
  zerotier-cli join $you_net_ID | grep OK
  if [ $? -eq 0 ]; then
    green "加入网络成功！请去ztncui管理页面，对加入的设备进行打钩"
    read -s -n1 -p "确认ztncui管理页面加入该moon节点后按任意键继续... "
    blue "搭建ztncui的Moon中转服务器，生成moon配置文件"
    cd /var/lib/zerotier-one/
    blue "生成moon.json文件并对其进行编辑"
    ip_addr=`curl ipv4.icanhazip.com`
    zerotier-idtool initmoon identity.public > moon.json
    if sed -i "s/\[\]/\[ \"$ip_addr\/9993\" \]/" moon.json >/dev/null 2>/dev/null; then
      green "编辑完成"
    else
      red "编辑出错"
    fi
    if [ "$release_os" == "centos" ]; then
      blue "防火墙开启zerotier默认udp端口9993"
      firewall-cmd --zone=public --add-port=9993/udp --permanent
      blue "防火墙重启"
      firewall-cmd --reload
    elif [ "$release_os" == "ubuntu" ]; then
      blue "防火墙开启zerotier默认udp端口9993"
      ufw allow 9993
      bule "防火墙重启"
      ufw reload
    fi
    blue "生成签名文件"
    zerotier-idtool genmoon moon.json
    blue "创建moons.d文件夹，并把签名文件移动到文件夹内"
    mkdir moons.d
    mv ./*.moon ./moons.d/
    cp /var/lib/zerotier-one/moon.json /home/
	blue 重启"zerotier-one服务"
    systemctl restart zerotier-one
	green "配置ztncui"
	cd /opt/key-networks/ztncui
    token=`cat /var/lib/zerotier-one/authtoken.secret`
    echo "ZT_TOKEN=$token" >> /opt/key-networks/ztncui/.env
	echo "ZT_ADDR=127.0.0.1:9993" >> /opt/key-networks/ztncui/.env
    echo "NODE_ENV=production" >> /opt/key-networks/ztncui/.env
    red "moon节点创建完成"
    red "请记得将moons.d文件夹拷贝出来用于客户端的配置，路径/var/lib/zerotier-one/"
  else
    red "加入失败，请检查你的网络ID号有无错误"
  fi
  red "moon加入成功，请进行第3步"
  sleep 1s
  read -s -n1 -p "按任意键返回菜单 ... "
  start_menu
}

#迁移控制器ztncui
function move_ztncui(){
  green "下载mkmoonworld主程序，并赋予执行权限"
  cd /home
  wget https://github.com/kaaass/ZeroTierOne/releases/download/mkmoonworld-1.0/mkmoonworld-x86
  chmod 777 mkmoonworld-x86
  green "生成planet文件"
  ./mkmoonworld-x86 ./moon.json
  green "让planet文件生效"
  mv world.bin planet
  green “重启zerotier”
  systemctl restart zerotier-one
  red "请下载planet文件到windows的客户端并替换，路径/home/"
  red "恭喜你，服务器安装成功"
}

#开始菜单
start_menu(){
  clear
  green " ======================================="
  green "              介      绍：              "
  green " 一键安装zerotier并加入moon迁移至ztncui " 
  green " 组成私人控制器的虚拟局域网综合脚本。   "
  green " 本脚本借鉴自dajiangfu                  "
  green " ======================================="
  echo
  green " 1. 启动ztncui节点安装脚本"
  green " 2. 启动moon节点安装脚本"
  green " 3. 启动迁移控制器ztncui脚本"
  green " 0. 退出脚本"
  echo
  read -p "请输入数字:" num
  case "$num" in
  1)
  creat_ztncui
  exit
  ;;
  2)
  creat_moon
  sleep 1s
  read -s -n1 -p "按任意键返回菜单 ... "
  start_menu
  ;;
  3)
  move_ztncui
  sleep 1s
  read -s -n1 -p "按任意键返回菜单 ... "
  start_menu
  ;;
  0)
  exit 1
  ;;
  *)
  clear
  red "请输入正确数字"
  sleep 1s
  start_menu
  ;;
  esac
}

start_menu
