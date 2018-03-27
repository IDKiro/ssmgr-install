# shadowsocks-manager 一键安装脚本

系统要求：Centos 7

内存要求：管理面板≥1G，节点≥256M

依赖：wget

**特性：**

1. 管理面板安装完整版，节点安装tiny版，降低节点的安装内存要求
2. 安装时可自定义加密方式、密码、端口
3. 自动配置开机自启

### 安装方法：

复制下面的指令粘贴到vps终端中，按照提示进行操作

``` 
wget --no-check-certificate https://raw.githubusercontent.com/IDKiro/ssmgr-install/master/ssmgr-install.sh
chmod +x ssmgr-install.sh
./ssmgr-install.sh
```

为了正常使用管理面板，请编辑`/root/.ssmgr/webgui.yml`中的email配置

普通SMTP：

```
email:
    use: true
    username: 'username'
    password: 'password'    host: 'smtp.your-email.com'
```

mailgun：

```
email:
    use: true
    type: 'mailgun'
    baseUrl: 'https://api.mailgun.net/v3/mg.xxxxx.xxx'
    apiKey: 'key-xxxxxxxxxxxxx'
```

支付宝、图标等参照官方wiki配置

[https://github.com/shadowsocks/shadowsocks-manager/wiki](https://github.com/shadowsocks/shadowsocks-manager/wiki)

**TODO:**

1. 提供安装时配置email的功能
2. 其他系统支持
3. 完整依赖检测流程
