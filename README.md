cat <<EOF > README.md
# Linux 企业微信 (Fedora 43 适配版)

本项目专为 Fedora 43 设计，解决了 DNF5 环境下的依赖冲突、Docker 安装及 Wine 窗口黑边问题。

## 🚀 快速开始 (Fedora 43)

### 1. 配置系统代理 (推荐)
由于需要拉取约 2GB 的 Docker 镜像，建议先配置 DNF 代理：
\`\`\`bash
sudo bash -c 'echo "proxy=http://10.0.2.2:20122" >> /etc/dnf/dnf.conf'
\`\`\`

### 2. 克隆与启动
无需手动安装 Docker，脚本将自动处理所有依赖：
\`\`\`bash
git clone https://github.com/kissunyeason/linux-wxwork.git
cd linux-wxwork
chmod +x launcher.sh
./launcher.sh
\`\`\`

## 🛠️ 脚本功能说明
- **自动适配 DNF5**：使用 \`addrepo\` 命令配置 Docker 官方源。
- **依赖补全**：自动安装 \`xorg-x11-utils\` 以支持 X11 授权。
- **UI 优化**：自动注入 Registry 补丁，消除 Wine 窗口的厚重黑边。
- **权限自愈**：检测到当前用户不在 Docker 组时，会自动使用 \`sudo\` 执行。

## ⚠️ 注意事项
- **首次启动**：安装 Docker 后，建议重启系统以使免密码权限生效。
- **镜像版本**：目前强制使用 \`zwhy2025/wine-docker:base\` 镜像。
EOF
