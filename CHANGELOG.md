# Changelog

本文档遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 规范。

## [v2.0.0] - 2026-01-10

### Added
- 多应用支持：从单一应用（企业微信）升级为支持数百款 Windows 应用
- 应用管理功能：`./tools/app.sh` 支持安装、卸载、搜索、列出应用
- 统一运行接口：`./tools/run.sh <应用名>` 统一运行所有应用
- 应用映射表：`mapping.json` 配置文件管理应用信息
- 运行时 Wine 安装：Wine 环境在首次运行时自动安装
- 公共函数库：`tools/functions.bash` 统一管理公共函数
- 环境依赖检查：`tools/setup.sh` 自动检查和安装系统依赖

### Changed
- **架构重构**：从单体脚本（523 行）重构为模块化设计
  - `tools/run_wxwork.sh`: 523 行 → 8 行（兼容性脚本）
  - 新增 `tools/app.sh`、`tools/run.sh`、`tools/functions.bash`、`tools/setup.sh`
- **Wine 安装策略**：从构建时安装改为运行时安装
  - 镜像构建时间：~400秒 → ~100秒（减少 75%）
  - 镜像体积：~2.5GB → ~2.0GB（减少 500MB）

### Removed
- `env/install_wine.sh` → 重命名为 `env/install_spark_store.sh`
- `env/install_wxwork.sh` → 功能迁移到运行时安装
- `env/setup_env.sh` → 功能整合到 `tools/setup.sh`
- Dockerfile 中的 Wine 安装步骤

### Fixed
- 修复构建时 Wine 安装可能失败的问题（改为运行时安装）
- 简化错误处理逻辑，移除冗余的异常检查
- 修复代码重复问题，提取公共函数到 `functions.bash`
- 修复 `create_wrapper` 函数中重复的 `chmod` 调用

### Technical Improvements
- 代码优化：移除重复的软件源配置检查和文件复制逻辑
- 错误处理：利用 `set -e` 简化错误处理，统一日志函数
- 模块化设计：功能职责清晰，易于维护和扩展
- 配置管理：从硬编码改为 JSON 配置文件

---

## [v1.0.0] - 2025

### Added
- 基于 Docker 的企业微信运行环境
- 自动配置 Docker 环境和镜像源
- 自动构建 Wine Docker 镜像
- 一键运行企业微信

---
