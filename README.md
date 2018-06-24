# shadowsocks-manager 一键安装脚本

系统要求：CentOS

内存要求：管理面板≥1G，节点≥256M

依赖：wget

**特性：**

1. 管理面板安装完整版，节点安装tiny版，降低节点的安装内存要求
2. 安装时可自定义加密方式、密码、端口、邮箱
3. 自动配置开机自启

### 安装方法：

复制下面的指令粘贴到vps终端中，按照提示进行操作

``` 
wget --no-check-certificate https://raw.githubusercontent.com/IDKiro/ssmgr-install/master/ssmgr-install.sh
chmod +x ssmgr-install.sh
./ssmgr-install.sh
```

支付宝、图标等参照官方wiki配置

[https://github.com/shadowsocks/shadowsocks-manager/wiki](https://github.com/shadowsocks/shadowsocks-manager/wiki)

**TODO:**

1. 安装时配置支付功能
2. 其他系统支持
