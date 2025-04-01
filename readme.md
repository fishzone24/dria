# Dria 计算节点一键安装脚本

这是一个在Ubuntu系统或Windows WSL环境中自动安装和配置Dria计算节点的脚本。该脚本简化了Dria节点的安装和管理过程，让您能够轻松地参与Dria网络并赚取$DRIA点数。本脚本解决了多种常见问题，特别是针对中国用户和WSL环境进行了优化。

## 功能特点

- **系统环境自动检测与配置**：自动识别Ubuntu、Debian和WSL环境
- **Docker环境安装**：全自动安装最新版Docker和Docker Compose
- **Ollama安装**：配置Ollama用于本地AI模型运行
- **Dria计算节点安装与配置**：提供多种安装方式，确保最高成功率
- **节点管理界面**：启动、配置、查看点数等全功能管理
- **WSL环境深度支持**：解决WSL特有的网络和性能问题
- **网络代理自动配置**：针对中国大陆用户的网络环境优化
- **WSL网络穿透配置**：彻底解决WSL环境中的P2P连接问题
- **自动诊断与修复**：自动检测并修复常见网络和配置问题
- **DNS修复工具**：专门解决WSL环境中的DNS解析失败问题
- **超级修复工具**：一键修复所有常见连接问题的综合解决方案
- **直接IP连接**：使用IP地址直接连接，绕过DNS解析问题
- **色彩丰富的交互式菜单**：友好的用户界面和详细的运行状态反馈

## 一键安装命令

使用以下命令可以直接下载、设置权限并运行脚本：

```bash
curl -fsSL https://raw.githubusercontent.com/fishzone24/dria/main/dria_auto_install.sh -o dria_auto_install.sh && chmod +x dria_auto_install.sh && sudo ./dria_auto_install.sh 
```

## 使用说明

脚本提供了以下主要功能，每个选项均进行了详细的优化设计：

### 1. 系统环境配置

自动检测系统环境并进行必要配置：
- **环境检测**：识别Ubuntu、Debian和WSL环境
- **系统更新**：更新系统包并安装必要依赖
- **权限检查**：确保脚本有足够权限执行所有操作
- **网络配置检查**：验证网络连接并提供诊断

### 2. Docker环境安装

全自动配置Docker环境：
- 检查现有Docker安装情况
- 使用官方脚本安装最新版Docker
- 配置Docker权限和用户组
- 优化Docker网络设置
- WSL环境下的Docker特别配置

### 3. Ollama安装

用于运行本地AI模型：
- 安装最新版Ollama
- 配置Ollama服务
- 自动设置开机启动
- 测试Ollama可用性

### 4. Dria计算节点安装

多种安装方式确保最高成功率：
- **直接安装**：使用预编译二进制直接安装
- **官方安装器**：使用Dria官方安装脚本
- **源码编译**：提供源码编译安装选项
- **版本管理**：自动检测最新版并提供版本选择
- **安装验证**：验证安装成功并测试基本功能

### 5. 网络代理配置

专为网络受限环境设计：
- **代理检测**：自动检测系统代理设置
- **WSL主机代理**：自动识别并使用Windows主机代理
- **代理测试**：测试代理连接GitHub的可用性
- **Docker代理**：为Docker配置独立代理
- **临时代理**：仅在安装过程中使用代理

### 6. WSL网络优化

彻底解决WSL环境中的P2P连接问题：
- **端口转发**：自动配置Windows主机端口转发
- **防火墙规则**：添加必要的Windows防火墙规则
- **多种执行方式**：提供自动和手动执行PowerShell的选项
- **网络配置优化**：创建专用于WSL环境的Dria网络配置
- **服务管理**：设置systemd服务便于管理

### 7. 节点管理选项

全面的Dria节点管理功能：
- **启动节点**：使用优化配置启动Dria节点
- **查看点数**：实时查询$DRIA点数余额
- **性能测试**：测量本地模型性能
- **节点升级**：一键升级到最新版本
- **节点监控**：查看节点运行状态和日志
- **推荐码管理**：设置和查看推荐码

### 8. 网络诊断与修复

自动诊断和修复常见网络问题：
- **DNS诊断**：检测并修复DNS配置问题
- **连接测试**：测试到Dria服务器的连接
- **网络重置**：提供网络重置选项
- **日志收集**：收集详细网络诊断日志
- **错误分析**：智能分析常见错误并提供解决方案

### 9. DNS修复工具 (新功能)

专门解决WSL环境中常见的DNS解析问题：
- **自动修复DNS配置**：设置可靠的DNS服务器（8.8.8.8和1.1.1.1）
- **静态hosts映射**：将Dria节点域名与IP地址映射添加到hosts文件
- **开机自动修复**：创建启动脚本，确保每次WSL启动都有正确的DNS配置
- **DNS解析测试**：自动测试DNS解析功能并报告结果
- **永久解决方案**：解决WSL环境中DNS配置容易被覆盖的问题

### 10. 超级修复工具 (新功能)

一键式综合解决方案，解决所有常见的Dria节点连接问题：
- **自动停止节点**：停止运行中的节点服务
- **DNS自动修复**：修复DNS解析问题
- **Docker网络重置**：清理并重置Docker网络配置
- **优化网络配置**：使用IP直连方式的优化网络配置
- **settings.json配置**：正确配置Dria节点使用优化的网络设置
- **增强模式启动**：以调试模式启动节点，提供更详细的连接信息
- **一键式解决**：只需一个命令即可解决所有常见连接问题

### 11. 直接IP连接功能 (新功能)

使用IP地址直接连接Dria网络，绕过DNS解析问题：
- **无需DNS解析**：直接使用Dria节点的IP地址建立连接
- **优化网络参数**：延长连接超时时间，提高连接成功率
- **配置文件优化**：创建专用于直接IP连接的配置文件
- **简化使用**：只需运行`dria-direct`命令即可使用此功能
- **增强兼容性**：适用于复杂网络环境和DNS受限的环境

## 详细功能说明

### WSL网络优化配置详解

WSL环境中运行Dria节点的最大挑战在于P2P网络连接。本脚本提供了全面解决方案：

1. **端口转发配置**
   - 自动配置Windows主机的4001、1337和11434端口转发到WSL
   - 使用`netsh interface portproxy`指令实现可靠端口映射
   - 自动清理旧的端口转发配置，防止冲突

2. **防火墙规则管理**
   - 创建命名为"WSL-Dria"的Windows防火墙入站规则
   - 同时配置TCP和UDP协议，确保P2P连接顺畅
   - 在WSL内部配置ufw规则，双重保障连接

3. **自动执行机制**
   - 检测WSL环境能否直接调用Windows命令
   - 如可用，自动生成并执行提升权限的批处理文件
   - 如不可用，提供格式化的PowerShell命令供手动复制执行

4. **网络配置文件优化**
   - 创建专用的`network_config.json`文件
   - 配置`external_multiaddrs`确保正确通告P2P地址
   - 优化连接超时和中继发现设置

5. **服务管理与便捷工具**
   - 创建`dria-node.service`系统服务
   - 提供`dria-optimized`命令启动优化配置的节点
   - 增加`dria-restart`和`dria-reset`命令用于快速管理

6. **网络自修复机制**
   - 节点启动时自动检查并修复DNS配置
   - 提供`--reset-docker`选项重置Docker网络
   - 每次启动显示详细网络信息便于诊断

### DNS修复工具详解 (新功能)

WSL环境中最常见的问题之一是DNS解析失败，导致无法连接到Dria节点的引导服务器。本工具提供了全面的解决方案：

1. **DNS配置自动修复**
   - 修改`/etc/resolv.conf`文件，设置可靠的DNS服务器（8.8.8.8和1.1.1.1）
   - 备份原有DNS配置，确保可以在需要时恢复
   - 自动测试修复后的DNS解析能力

2. **静态主机名映射**
   - 将Dria节点的域名与IP地址对应关系添加到`/etc/hosts`文件中
   - 提供完整的映射列表：
     ```
     34.145.16.76 node1.dria.co
     34.42.109.93 node2.dria.co
     34.42.43.172 node3.dria.co
     35.200.247.78 node4.dria.co
     34.92.171.75 node5.dria.co
     ```
   - 即使DNS服务器不可用，也能正常解析Dria节点域名

3. **启动自动修复脚本**
   - 创建`/usr/local/bin/fix-dns.sh`脚本，可随时手动修复DNS
   - 添加到系统启动项，确保每次WSL启动都有正确的DNS配置
   - 添加判断逻辑，只在需要时进行修复，避免不必要的修改

4. **配套节点配置优化**
   - 修改节点启动脚本，在启动前自动检查并修复DNS问题
   - 优化节点配置，同时支持域名和IP地址连接方式
   - 增强错误处理，提供更清晰的错误提示

### 超级修复工具详解 (新功能)

面对复杂的连接问题，有时需要全面的修复方案。超级修复工具(`dria-superfix`)提供了一键式解决方案：

1. **全流程自动化修复**
   - 停止正在运行的节点，确保配置修改可以正确应用
   - 修复DNS配置，确保域名解析正常
   - 重置Docker网络，解决网络命名空间混乱问题
   - 创建优化的网络配置文件，使用IP地址直接连接
   - 配置`settings.json`，确保节点使用优化的配置
   - 以增强模式启动节点，提供详细的连接信息

2. **网络配置优化**
   - 使用IP地址直接连接Dria引导节点，绕过DNS解析
   - 延长连接超时时间，从默认的120秒增加到300秒
   - 增加直接连接超时，从10000毫秒增加到20000毫秒
   - 增加中继连接超时，从30000毫秒增加到60000毫秒

3. **智能配置管理**
   - 自动检测现有的`settings.json`配置
   - 如存在，备份并更新，保留现有的其他配置
   - 如不存在，创建新的配置文件
   - 使用`jq`工具(如可用)进行JSON处理，确保格式正确

4. **增强调试模式**
   - 设置`DKN_LOG=debug`环境变量，启用详细日志
   - 实时显示连接过程和状态变化
   - 提供更多的诊断信息，便于排查具体问题

### 直接IP连接功能详解 (新功能)

当DNS解析不可靠或不可用时，直接IP连接功能(`dria-direct`)提供了可靠的替代方案：

1. **直接IP连接原理**
   - 使用Dria引导节点的IP地址而非域名
   - 创建专用的`direct_network_config.json`配置文件
   - 配置`settings.json`使用优化的连接参数
   - 自动启动前修复DNS配置，确保基本网络功能正常

2. **优化的连接参数**
   - 使用如下IP地址直接连接Dria引导节点：
     ```
     34.145.16.76 (node1.dria.co)
     34.42.109.93 (node2.dria.co)
     34.42.43.172 (node3.dria.co)
     35.200.247.78 (node4.dria.co)
     34.92.171.75 (node5.dria.co)
     ```
   - 延长连接超时时间，提高连接成功率
   - 启用中继发现和中继连接功能

3. **动态IP地址配置**
   - 自动检测WSL的IP地址
   - 动态生成correct`external_multiaddrs`配置
   - 确保P2P连接可以正确建立和维护

4. **简化使用流程**
   - 只需执行`dria-direct`命令即可启动
   - 自动执行所有必要的配置和优化
   - 以增强调试模式运行，提供更多诊断信息

## 系统要求

- Ubuntu系统（18.04/20.04/22.04）或Windows WSL2
- Root用户权限
- 稳定的网络连接或正确配置的代理
- 系统资源要求（基于选择的模型）：
  - 最低：4GB RAM, 2 CPU核心
  - 推荐：8GB+ RAM, 4+ CPU核心
  - 本地模型：16GB+ RAM, 支持AVX的CPU

## WSL环境使用指南

### 准备工作
1. 确保已安装WSL2（Windows 10 2004或更高版本）
2. 推荐使用Ubuntu 20.04或22.04 WSL发行版
3. 分配足够的系统资源给WSL（在`.wslconfig`中配置）

### 安装步骤
1. 在WSL中打开终端
2. 运行一键安装命令
3. 在主菜单中选择"W. WSL网络优化配置"
4. 根据提示配置网络（可能需要在Windows中执行PowerShell命令）
5. 安装完成后使用`dria-optimized`启动节点
6. 如遇连接问题，使用"D. DNS修复工具"或"F. 超级修复工具"

### 节点管理命令
```bash
# 使用优化配置启动节点
dria-optimized

# 带网络重置启动节点（网络问题时使用）
dria-optimized --reset-docker

# 直接IP连接方式启动（DNS问题时使用）
dria-direct

# 超级修复工具（遇到复杂连接问题时使用）
dria-superfix

# DNS修复工具（手动修复DNS）
sudo /usr/local/bin/fix-dns.sh

# 作为系统服务管理
systemctl start dria-node    # 启动节点服务
systemctl stop dria-node     # 停止节点服务
systemctl status dria-node   # 查看节点状态
dria-restart                 # 快速重启节点
dria-reset                   # 重置节点网络
```

### WSL特别注意事项
1. 每次重启Windows或WSL后，需要重新运行WSL网络优化配置
2. Windows防火墙可能会询问是否允许连接，请选择"允许"
3. 如遇到网络问题，尝试使用`dria-reset`命令重置网络
4. DNS问题是WSL中最常见的问题，使用"D"选项修复
5. 如果节点状态显示"CONNECTING"且没有收到ping，使用"F"选项超级修复
6. 在资源管理器中访问WSL文件系统可能会导致性能问题，建议在WSL终端中操作
7. 通过`\\wsl$\Ubuntu\`路径访问WSL文件系统

## 故障排除指南

### 安装问题

1. **Docker安装失败**
   - 错误：`Cannot connect to the Docker daemon`
   - 解决：运行`systemctl start docker`启动服务，然后重试

2. **Dria节点安装超时**
   - 错误：`Connection timed out`或`Connection refused`
   - 解决：
     - 检查网络连接（使用`网络诊断`选项）
     - 配置代理（使用`代理设置`选项）
     - 尝试直接安装模式或源码编译模式

3. **权限问题**
   - 错误：`Permission denied`
   - 解决：确保使用`sudo`运行脚本或已切换至root用户

### 网络问题

1. **节点无法连接到P2P网络**
   - 症状：节点状态显示`CONNECTING`，没有收到ping
   - 解决：
     - WSL环境：运行WSL网络优化，确保端口转发配置成功
     - 检查防火墙设置：确保4001端口已开放
     - 使用`dria-superfix`超级修复工具
     - 或使用`dria-direct`直接IP连接方式启动

2. **DNS解析失败**
   - 错误：`Could not resolve host: node1.dria.co`
   - 解决：
     - 使用"D. DNS修复工具"选项自动修复
     - 或手动运行`sudo /usr/local/bin/fix-dns.sh`
     - 使用`dria-direct`绕过DNS直接连接

3. **代理连接问题**
   - 错误：`Failed to connect to proxy`
   - 解决：
     - 验证代理地址和端口是否正确
     - 检查代理是否需要认证
     - 测试代理可用性：`curl -x <代理地址:端口> https://github.com`

### 节点运行问题

1. **点数不增加**
   - 原因：可能是网络连接问题或模型性能不足
   - 解决：
     - 确保节点已连接到P2P网络（有ping）
     - 使用`dria-superfix`确保最佳连接配置
     - 检查节点日志：`journalctl -u dria-node -f`
     - 运行性能测试评估系统性能

2. **节点崩溃或不稳定**
   - 原因：资源不足或配置问题
   - 解决：
     - 检查系统资源：`htop`
     - 减少本地模型大小或切换到较小模型
     - WSL环境：增加`.wslconfig`中的内存和CPU分配

3. **WSL特有问题**
   - 问题：频繁断开连接或性能下降
   - 解决：
     - 限制WSL内存使用：编辑`%UserProfile%\.wslconfig`
     - 禁用省电模式和睡眠
     - 使用`wsl --update`更新WSL内核
     - 重启后使用`dria-superfix`重新配置连接

## 便捷工具参考

脚本提供了多种便捷命令，简化节点管理：

```bash
# 标准启动和管理
start-dria                  # 标准启动
dkn-compute-launcher status # 查看状态
dkn-compute-launcher logs   # 查看日志

# WSL优化环境专用
dria-optimized              # 优化配置启动
dria-restart                # 快速重启
dria-reset                  # 重置网络
dria-direct                 # 直接IP连接启动
dria-superfix               # 超级修复工具

# 系统服务管理
systemctl start dria-node   # 启动服务
systemctl stop dria-node    # 停止服务
systemctl status dria-node  # 查看状态
journalctl -u dria-node -f  # 查看日志

# DNS修复
/usr/local/bin/fix-dns.sh   # 手动修复DNS
```

## 更新日志

最新更新：
- 增加WSL网络穿透配置，解决P2P连接问题
- 添加自动网络诊断与修复功能
- 优化代理配置逻辑，提高国内连接稳定性
- 增强安装成功率，添加多种安装方式
- 改进用户界面和错误处理
- 新增DNS修复工具，解决WSL环境中的DNS问题
- 新增超级修复工具，一键解决复杂连接问题
- 新增直接IP连接功能，绕过DNS解析问题
- 优化WSL环境下的Docker安装和配置
- 改进Ollama在WSL环境下的安装方式
- 增加系统依赖项自动检测和安装
- 优化错误处理和状态显示
- 增加彩色输出支持，提升用户体验
- 完善WSL环境检测和适配

## 相关链接

- [Dria官方网站](https://dria.co/)
- [Dria计算节点官方GitHub](https://github.com/firstbatchxyz/dkn-compute-launcher)
- [Ollama官方网站](https://ollama.com/)
- [WSL官方文档](https://learn.microsoft.com/zh-cn/windows/wsl/)
- [本脚本GitHub仓库](https://github.com/fishzone24/dria)

## 防火墙配置

脚本会自动配置以下防火墙规则：

### 必需端口
- TCP 4001：Dria 节点通信端口
- UDP 4001：Dria 节点 P2P 通信端口
- TCP 1337：Dria 节点 API 端口
- TCP 11434：Ollama 服务端口

### 自动配置内容
1. 安装并配置 UFW 防火墙
2. 配置 iptables 规则
3. 自动检测并释放被占用的端口
4. 测试端口可访问性

### 云服务器额外配置
如果您使用云服务器（如阿里云、腾讯云等），还需要在云服务商控制面板中手动开放以下端口：
- TCP 4001
- UDP 4001
- TCP 1337
- TCP 11434

## 故障排除

### 端口问题
如果遇到端口未开放的问题，可以：

1. 运行超级修复工具：
```bash
./dria_auto_install.sh
# 选择选项 F
```

2. 检查端口状态：
```bash
sudo netstat -tulpn | grep -E '4001|1337|11434'
sudo ufw status
```

3. 检查防火墙规则：
```bash
sudo iptables -L -n | grep -E '4001|1337|11434'
```

### 网络连接问题
如果节点状态显示 "CONNECTING" 或无法接收 ping：

1. 检查防火墙配置
2. 确认云服务器安全组设置
3. 检查网络连接：
```bash
ping 8.8.8.8
ping google.com
```

## 更新日志

### v1.0.0
- 初始版本发布
- 支持 WSL 和原生 Linux 环境
- 自动安装和配置功能
- 超级修复工具

### v1.1.0
- 增强防火墙配置功能
- 自动检测和释放被占用端口
- 改进端口测试功能
- 优化网络诊断功能

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request 来帮助改进这个项目。
