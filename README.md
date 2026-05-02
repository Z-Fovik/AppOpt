# AppOpt - 小米17Pro Max 自动线程优化模块

[![GitHub Release](https://img.shields.io/badge/version-v8-blue)](https://github.com/Z-Fovik/AppOpt/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Android](https://img.shields.io/badge/Android-14%2B-brightgreen)]()
[![Magisk](https://img.shields.io/badge/Magisk-20.4%2B-orange)]()
[![KernelSU](https://img.shields.io/badge/KernelSU-supported-purple)]()

一款针对小米 17 Pro Max（骁龙 8 至尊版 SM8850）深度优化的 Magisk/KernelSU 模块，通过智能 CPU 线程绑定策略，为每个应用分配最优核心，实现性能与功耗的完美平衡。

---

## 核心特性

- **450+ 应用线程优化规则** — 覆盖社交、游戏、视频、购物、金融、出行等 20+ 类别
- **6+2 架构适配** — 针对骁龙 8 至尊版（SM8850）CPU0-5 性能核 + CPU6-7 超大核的专属调度
- **双游戏引擎模板** — 同时支持 Unity 引擎（UnityMain）和 UE/自研引擎（GameThread）的手游
- **Web 可视化管理** — 手机浏览器直接管理规则，支持批量配置、一键备份恢复
- **自动规则生成** — 内置 4 个 Shell 工具，一键为任意应用生成线程优化规则
- **开机即生效** — 无需手动操作，重启手机自动加载优化策略

## 架构适配

| CPU 核心 | 编号 | 最高频率 | 定位 |
|---------|------|---------|------|
| 性能核（Performance） | CPU 0-5 | 3.62 GHz | 应用主线程 / 通用计算 |
| 超大核（Prime） | CPU 6-7 | 4.6 GHz | 游戏主线程 / UI渲染 |

## 线程分配策略

### 普通 APP 规则

| 线程类型 | 核心绑定 | 说明 |
|---------|---------|------|
| 主线程 / 渲染 / 解码 | 3-5 | 性能核，保证流畅 |
| binder / IO 交互 | 0-2 | 性能核，低延迟 IPC |
| 默认兜底 | 0-2 | 性能核，均衡分配 |

### 游戏规则 — 有 UnityMain

| 线程类型 | 核心绑定 | 说明 |
|---------|---------|------|
| UnityMain / Unity 渲染 | 6-7 | 超大核，满血输出 |
| NativeThread | 3-5 | 性能核，负载均衡 |
| Job.Worker | 3-5 | 计算密集型线程 |
| 默认兜底 | 0-5 | 全核可用 |

### 游戏规则 — 无 UnityMain（UE / 自研引擎）

| 线程类型 | 核心绑定 | 说明 |
|---------|---------|------|
| Render Thread / GameThread / MainThread | 6-7 | 超大核，满血输出 |
| *Thread（通用线程） | 6-7 | 优先超大核 |
| NativeThread | 3-5 | 性能核，负载均衡 |
| 默认兜底 | 0-5 | 全核可用 |

## 安装方法

1. 下载 `AppOpt-v8.zip`
2. 通过 Magisk / KernelSU 管理器刷入模块
3. 重启手机
4. 模块自动生效

## 内置工具

刷入后在 `/data/adb/modules/AppOpt/` 目录下可找到以下工具（需 ROOT 权限执行）：

| 工具 | 功能 |
|------|------|
| `【自动规则生成工具】.sh` | 交互式生成单个/批量 APP 或游戏规则 |
| `【模块生效校验工具】.sh` | 检查主程序运行状态、ROOT 权限、配置文件完整性 |
| `【自动获取包名生成规则工具】.sh` | 扫描手机已安装应用，自动分类生成规则 |
| `【线程占用检测工具】.sh` | 120 秒实时监控前台应用线程 CPU 占用率，推荐核心绑定 |

## Web 管理界面

模块内置 Web 管理界面，支持在手机浏览器中可视化管理所有线程规则：

- 查看所有已配置应用和规则
- 批量添加/删除/修改规则
- 直接编辑配置文件
- 一键备份与恢复
- 查看模块运行状态和设备 CPU 信息

## 项目结构

```
AppOpt/
├── META-INF/                  # Magisk 刷入配置
├── bin/                       # 多架构二进制文件
│   ├── arm64-v8a/AppOpt
│   ├── armeabi-v7a/AppOpt
│   ├── x86/AppOpt
│   └── x86_64/AppOpt
├── webroot/
│   └── index.html             # Web 管理界面
├── applist.conf               # 线程优化规则配置文件
├── customize.sh               # 安装脚本 + 工具部署
├── module.prop                # 模块元信息
├── service.sh                 # 开机自启服务
└── uninstall.sh               # 卸载清理脚本
```

## 配置文件说明

`applist.conf` 采用以下格式：

```
包名{线程匹配规则}=核心编号范围
```

示例：
```
# 微信
com.tencent.mm{com.tencent.mm}=3-5
com.tencent.mm{Thread-*}=3-5
com.tencent.mm{binder:*}=0-1
com.tencent.mm=0-1
```

- `Thread-*` / `Thread*` — 通用工作线程
- `binder:*` — IPC 交互线程
- `MediaCodec_*` / `VDecod2-*` — 解码线程
- `{UnityMain}` — Unity 游戏主线程
- `=0-2` — 绑定到 CPU 0-2（性能核）

## 已适配应用（450+）

<details>
<summary>点击展开查看全部分类</summary>

**社交/通讯** — 微信、QQ、TIM、微博、小红书、知乎、脉脉、Soul、即刻、Telegram、WhatsApp、Discord、Twitter(X)、Instagram、Facebook 等

**短视频** — 抖音、快手、微视、西瓜视频、TikTok 等

**长视频** — B站、爱奇艺、优酷、腾讯视频、芒果TV、虎牙、斗鱼、Twitch 等

**音乐** — QQ音乐、网易云音乐、酷狗、酷我、喜马拉雅、汽水音乐、Apple Music、Spotify、Tidal 等

**购物** — 淘宝、京东、拼多多、闲鱼、天猫、得物、唯品会、Temu、Amazon、Lazada 等

**外卖/生活** — 美团、饿了么、大众点评、美团外卖、美团买药 等

**出行/导航** — 滴滴、高德地图、百度地图、曹操出行、T3出行、哈啰、嘀嗒出行、Uber、Grab、Booking 等

**金融/银行** — 支付宝、云闪付、各主要银行APP、雪球、同花顺、东方财富、币安、OKX 等

**AI 工具** — ChatGPT、Claude、DeepSeek、Kimi、文心一言、通义千问、讯飞星火、Perplexity、Gemini 等

**游戏（国内）** — 王者荣耀、和平精英、原神、崩坏3/星铁/绝区零、鸣潮、战双、明日方舟、第五人格、金铲铲、LOL手游、CF、DNF、暗区突围、三角洲行动 等

**游戏（海外）** — PUBG、COD、Fortnite、Roblox、Minecraft、Nikke、BA、Epic7、皇室战争、部落冲突、荒野乱斗、Apex Legends 等

**阅读** — 微信读书、起点读书、番茄小说、多看、Kindle 等

**工具** — Chrome、Edge、Firefox、QQ浏览器、夸克、WPS、百度网盘、迅雷、MT管理器、Google Play、Steam 等

</details>

## 适配说明

- **目标设备**：小米 17 Pro Max（骁龙 8 至尊版 SM8850）
- **目标系统**：Android 14+，Magisk 20.4+ 或 KernelSU
- **CPU 架构**：6+2 全大核（CPU0-5 性能核 3.62GHz + CPU6-7 超大核 4.6GHz）
- **兼容架构**：arm64-v8a、armeabi-v7a、x86、x86_64

> 其他骁龙 8 至尊版机型理论上兼容，但核心频率分布不同，可能需要调整规则中的核心编号。

## 更新日志

### v8 (2026-05-02)
- 修复 Job.worker 大小写匹配问题
- 新增 Web 可视化管理界面
- 新增 4 个内置 Shell 工具
- 规则覆盖扩展至 450+ 应用
- 全面适配骁龙 8 至尊版 6+2 架构

## License

MIT License

## 致谢

- [Magisk](https://github.com/topjohnwu/Magisk) — Systemless root framework
- [KernelSU](https://github.com/tiann/KernelSU) — Kernel-based root solution
