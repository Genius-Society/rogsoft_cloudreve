# Cloudreve for asuswrt
[![license](https://img.shields.io/github/license/Genius-Society/rogsoft_cloudreve.svg)](https://github.com/Genius-Society/rogsoft_cloudreve/blob/main/LICENSE)
[![GitHub release](https://img.shields.io/github/release/Genius-Society/rogsoft_cloudreve.svg)](https://github.com/Genius-Society/rogsoft_cloudreve/releases/latest)
[![bilibili](https://img.shields.io/badge/bilibili-BV18ergYRERP-fc8bab.svg)](https://www.bilibili.com/video/BV18ergYRERP)

Cloudreve 网盘的 Koolcenter 软件中心插件版本

![](https://foruda.gitee.com/images/1735299905497917561/45f32785_14243051.png)

## Cloudreve 是什么?
Cloudreve 可以让您快速搭建起公私兼备的网盘系统。Cloudreve 在底层支持不同的云存储平台, 用户在实际使用时无须关心物理存储方式。你可以使用 Cloudreve 搭建个人用网盘、文件分享系统, 亦或是针对大小团体的公有云系统。

## 项目地址
<https://github.com/cloudreve/Cloudreve>

## 官方信息
官方文档: <https://docs.cloudreve.org>

## 软件中心面板展示
![](https://foruda.gitee.com/images/1735376775202607416/239abf62_14243051.png)

## 机型支持
在 asuswrt 为基础的固件上, cloudreve 插件目前仅支持 aarch64 架构的路由器, 具体如下:

- 部分及其未列出, 请根据 CPU 型号和支持软件中心与否自行判断
- 使用 cloudreve 建议配置 1G 及以上的虚拟内存, 特别是小内存的路由器

| 机型             | 内存  | CPU/SOC | 架构  | 核心  |  频率   | 插件支持 |
| :--------------- | :---- | :-----: | :---: | :---: | :-----: | :------: |
| RT-AC86U         | 512MB | BCM4906 | armv8 |   2   | 1.8 GHz |    ✔️     |
| GT-AC2900        | 512MB | BCM4906 | armv8 |   2   | 1.8 GHz |    ✔️     |
| RT-AX92U         | 512MB | BCM4906 | armv8 |   2   | 1.8 GHz |    ✔️     |
| GT-AC5300        | 1GB   | BCM4908 | armv8 |   4   | 1.8 GHz |    ✔️     |
| RT-AX88U         | 1GB   | BCM4908 | armv8 |   4   | 1.8 GHz |    ✔️     |
| GT-AX11000       | 1GB   | BCM4908 | armv8 |   4   | 1.8 GHz |    ✔️     |
| NetGear RAX80    | 1GB   | BCM4908 | armv8 |   4   | 1.8 GHz |    ✔️     |
| RT-AX68U         | 512MB | BCM4906 | armv8 |   2   | 1.8 GHz |    ✔️     |
| RT-AX86U         | 1GB   | BCM4908 | armv8 |   4   | 1.8 GHz |    ✔️     |
| GT-AXE11000      | 1GB   | BCM4908 | armv8 |   4   | 1.8 GHz |    ✔️     |
| ZenWiFi_Pro_XT12 | 1GB   | BCM4912 | armv8 |   4   | 2.0GHz  |    ✔️     |
| GT-AX6000        | 1GB   | BCM4912 | armv8 |   4   | 2.0GHz  |    ✔️     |
| GT-AX11000_PRO   | 1GB   | BCM4912 | armv8 |   4   | 2.0GHz  |    ✔️     |
| RT-AX86U_PRO     | 1GB   | BCM4912 | armv8 |   4   | 2.0GHz  |    ✔️     |
| RAX50            | 512MB | BCM6750 | armv7 |   3   | 1.5 GHz |    ✔️     |
| RAX70            | 512MB | BCM6755 | armv7 |   4   | 1.5 GHz |    ✔️     |
| RT-AX56U         | 512MB | BCM6755 | armv7 |   4   | 1.5 GHz |    ✔️     |
| RT-AX56U_V2      | 256MB | BCM6755 | armv7 |   4   | 1.5 GHz |    ✔️     |
| RT-AX58U         | 512MB | BCM6750 | armv7 |   3   | 1.5 GHz |    ✔️     |
| RT-AX82U         | 512MB | BCM6750 | armv7 |   3   | 1.5 GHz |    ✔️     |
| TUF-AX3000       | 512MB | BCM6750 | armv7 |   3   | 1.5 GHz |    ✔️     |
| TUF-AX5400       | 512MB | BCM6750 | armv7 |   3   | 1.5 GHz |    ✔️     |
| ZenWiFi_XT8      | 512MB | BCM6755 | armv7 |   4   | 1.5 GHz |    ✔️     |
| ZenWiFi_XD4      | 256MB | BCM6755 | armv7 |   4   | 1.5 GHz |    ✔️     |
| TUF-AX3000_V2    | 512MB | BCM6756 | armv7 |   4   | 1.7GHz  |    ✔️     |
| RT-AX57          | 256MB | BCM6756 | armv7 |   4   | 1.7GHz  |    ✔️     |

## Thanks
<https://github.com/everstu/Koolcenter_alist>