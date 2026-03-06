# xcaddy

自定义 Caddy 构建工具，集成 [NaiveProxy](https://github.com/klzgrad/forwardproxy) 插件。

## 下载

从 [Releases](https://github.com/liasica/xcaddy/releases) 页面下载预编译二进制文件。

支持平台：
- Linux (amd64, arm64, arm)
- macOS (amd64, arm64)

## 快速安装 (Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/liasica/xcaddy/master/install.sh | sudo bash
```

安装脚本会：
1. 自动检测系统架构
2. 下载最新版本
3. 交互式配置域名、邮箱、认证信息
4. 创建 systemd 服务并启动

## 手动构建

```bash
# 安装 xcaddy
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# 构建
xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
```

### 跨平台编译

```bash
./build.sh [版本号]
```

输出文件位于 `dist/` 目录。

## 配置示例

```caddyfile
:443, example.com
tls admin@example.com

route {
    forward_proxy {
        basic_auth username password
        hide_ip
        hide_via
        probe_resistance
    }

    reverse_proxy https://cdn.jsdelivr.net {
        header_up Host {upstream_hostport}
        header_up X-Forwarded-Host {host}
    }
}
```

## 常用命令

```bash
# 查看状态
systemctl status caddy

# 重启服务
systemctl restart caddy

# 重新加载配置
systemctl reload caddy

# 查看日志
journalctl -u caddy -f
```

## 许可证

Apache-2.0