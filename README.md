# Internal Network Scanning

> 纯原生内网扫描工具集 —— 无需安装任何第三方工具，仅依赖 Windows/Linux 系统自带组件。

## 📋 工具总览

| 文件 | 环境 | 功能 | 并发方式 | 适用场景 |
|------|------|------|----------|----------|
| `powershell-scan(ping+port)` | PowerShell 5+ | 主机发现 + 端口扫描 | 异步 Ping + TCP 并发池 | **推荐：一条命令完成全套扫描** |
| `powershell-port_scan` | PowerShell 5+ | 端口扫描 | TCP 异步并发池 (500) | 需要可读脚本 / 自定义修改 |
| `powershell-ping_scan` | PowerShell 5+ | 主机发现 | 异步 Ping (254并发) | 快速存活探测 + OS 识别 |
| `port_scan.bat` | CMD (任意 Windows) | 端口扫描 | C# 编译 + ThreadPool | **最强兼容：只要有 .NET 就能跑** |
| `cmd-port_scan(powershell)` | CMD → PowerShell | 端口扫描 | TCP 异步并发池 | CMD 下一行调用 PowerShell |
| `cmd-port_scan(csc)` | CMD → csc.exe | 端口扫描 | Parallel.For | CMD 下一行编译执行 |
| `cmd-port_scan(curl)` | CMD (Win10+) | 端口扫描 | 多进程 curl | 简单但较慢 |
| `cmd-ping_scan(for)` | CMD | 主机发现 | 串行 ping | 最简单，无依赖 |
| `cmd-ping_scan(powershell)` | CMD → PowerShell | 主机发现 | 异步 Ping | CMD 下调用 PowerShell 异步扫 |
| `bash-port_scan` | Bash (Linux) | 端口扫描 | /dev/tcp 后台并发 | Linux 环境 |

## 🚀 快速开始

### 一、主机发现 + 端口扫描（推荐）

PowerShell 中直接粘贴，修改前两个变量即可：

```powershell
# 修改 $subnet 为目标网段，$targetIP 留空则扫描所有存活主机
$subnet="10.9.15";$targetIP="";$portStart=1;$portEnd=1000;...
```

输出示例：
```
[+] Alive hosts
IP          OS      TTL Time
--          --      --- ----
10.9.15.1   Windows 128 1ms
10.9.15.100 Linux   64  3ms

[+] Port scan on 10.9.15.1 (1-1000), concurrency=500, timeout=100ms
[+] 10.9.15.1 open ports: 80,135,445,3389
IP        Port Service
--        ---- -------
10.9.15.1   80 http
10.9.15.1  135 msrpc
10.9.15.1  445 smb
10.9.15.1 3389 rdp
```

### 二、仅端口扫描

**PowerShell（可读版）：**
```powershell
# 修改 powershell-port_scan 文件头部的 $ip 变量
$ip = "10.9.15.1"
$ports = 1..10000      # 端口范围
$timeoutMs = 100       # 连接超时(ms)
$concurrency = 500     # 并发数
```

**CMD（Bat 万能版）：**
```cmd
port_scan.bat 10.9.15.1
port_scan.bat 10.9.15.1 1-65535
```

**CMD 一行版：**
```cmd
:: 方式1：通过 PowerShell
powershell -NoProfile -Command "$ip='10.9.15.1';$ports=1..10000;..."

:: 方式2：通过 csc 编译（复制 cmd-port_scan(csc) 内容）

:: 方式3：通过 curl（Win10+，较慢）
for /L %p in (1,1,1000) do @start /b cmd /c "curl -s telnet://10.9.15.1:%p --connect-timeout 1 >nul 2>&1 && echo Port %p Open"
```

### 三、仅主机发现

**PowerShell：**
```powershell
# 修改 $s 为目标网段前三段
$s="10.9.15";$t=500;...
```

**CMD（最简）：**
```cmd
for /L %i in (1,1,254) do @ping -n 1 -w 500 10.9.15.%i | find "TTL="
```

### 四、Linux 环境

```bash
# 快速扫描 1-1000
IP=10.9.15.1; for port in {1..1000}; do { echo >/dev/tcp/$IP/$port; } 2>/dev/null && echo "Port $port open" & sleep 0.01; done

# 全端口扫描（兼容旧系统）
TARGET=10.9.15.1; for p in {1..65535}; do (timeout 0.5 bash -c "echo >/dev/tcp/$TARGET/$p" && echo "OPEN: $p") & [ $((p % 128)) -eq 0 ] && wait; done
```

## ⚙️ 技术细节

### 性能参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `concurrency` | 500 | 同时发起的 TCP 连接数 |
| `timeoutMs` / `connectTimeout` | 100ms | 单次连接超时，内网建议 100-200ms |
| `pingTimeout` | 500ms | Ping 超时，跨网段可适当增大 |
| `ports` | 1-10000 | 端口范围，bat 版支持命令行参数指定 |

### 并发模型

- **PowerShell 版**：手动管理 `TcpClient.BeginConnect` 异步连接池，反向索引遍历 + `RemoveAt` O(n) 移除
- **Bat/C# 版**：`ThreadPool.QueueUserWorkItem` + `SetMinThreads(500)` 预热线程池，`Interlocked` 原子计数
- **Ping 扫描**：`SendPingAsync` 全量并发 254 个异步任务，`Task.WaitAll` 一次等待

### OS 识别（Ping 扫描）

通过 TTL 值粗略判断：
- **TTL ≤ 64** → Linux / macOS / 网络设备
- **TTL ≤ 128** → Windows
- **TTL > 128** → Other

### 服务识别

自动识别 21 个常见端口的服务名：

```
FTP(21) SSH(22) Telnet(23) SMTP(25) DNS(53) HTTP(80) POP3(110)
MSRPC(135) NetBIOS(139) IMAP(143) LDAP(389) HTTPS(443) SMB(445)
MSSQL(1433) Oracle(1521) MySQL(3306) RDP(3389) PostgreSQL(5432)
WinRM(5985) Redis(6379) HTTP-Alt(8080) HTTPS-Alt(8443)
```

### port_scan.bat 工作流程

```
1. 穷举可写目录（%TEMP% → %PUBLIC% → C:\Users\Public → ...）
2. 穷举 C# 编译器（.NET 4 x64 → .NET 4 x86 → .NET 2 x64 → .NET 2 x86）
3. 生成 C# 源码 → 静默编译 → 执行
4. 扫描完成后自动删除源码和可执行文件
```

## ⚠️ 注意事项

- 所有工具**仅限授权的内网环境**使用
- `concurrency` 过高可能触发安全设备告警，酌情调整
- 内网超时建议 100ms，跨网段 / VPN 环境建议 200-500ms
- `port_scan.bat` 需要系统存在 .NET Framework（Windows 7+ 默认自带）
- Bash 版依赖 `/dev/tcp`，部分精简发行版可能不支持

## 📁 文件结构

```
Internal network scanning/
├── powershell-scan(ping+port)   # 一体化扫描（推荐）
├── powershell-port_scan         # 端口扫描（可读版）
├── powershell-ping_scan         # Ping 存活探测
├── port_scan.bat                # Bat+C# 万能端口扫描
├── cmd-port_scan(powershell)    # CMD 调 PowerShell 扫端口
├── cmd-port_scan(csc)           # CMD 调 csc 编译扫端口
├── cmd-port_scan(curl)          # CMD 调 curl 扫端口
├── cmd-ping_scan(for)           # CMD 原生 ping 扫描
├── cmd-ping_scan(powershell)    # CMD 调 PowerShell 扫存活
├── bash-port_scan               # Linux Bash 端口扫描
└── README.md
```
