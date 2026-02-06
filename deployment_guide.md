# OpenClaw 自动化部署指南 (Linux/macOS)

本指南旨在帮助管理员快速、批量地在客户端设备（Linux 和 macOS）上部署 OpenClaw 汉化版。

## 部署策略说明

我们采用了混合部署策略，以确保最佳的用户体验和稳定性：

| 平台 | 部署方式 | 理由 |
| :--- | :--- | :--- |
| **Linux (服务器/桌面)** | **Docker** | 环境隔离，依赖最少，官方推荐的服务端运行方式。 |
| **macOS (MacBook/Mac Mini)** | **原生安装 (npm)** | 必须运行在宿主机才能调用 macOS 本地能力（如日历、提醒事项、Apple Notes、iMessage 等），Docker 无法做到这一点。 |

> **注意**：脚本会自动识别操作系统并选择正确的部署方式。

---

## 快速开始

### 1. 准备工作

将 `mass_deploy.sh` 脚本分发到目标机器，或托管在一个内部 HTTP 服务器上。

### 2. 执行部署

**场景 A：最简部署（仅安装，模型留空）**
用户初次登录时需要手动填入 API Key。

```bash
# 执行脚本
bash mass_deploy.sh
```

**场景 B：预设 API Key（完全自动化）**
您可以预先设置环境变量，脚本会自动配置模型。

### 3. 模型配置速查表 (Cheat Sheet)

预设对应的环境变量，脚本会自动完成配置。

#### 🟢 Google Gemini
```bash
export GEMINI_API_KEY="AIzaSy..."
bash mass_deploy.sh
```

#### 🟢 OpenAI (GPT-4o)
```bash
export OPENAI_API_KEY="sk-proj-..."
bash mass_deploy.sh
```

#### 🟢 Anthropic (Claude 3.5 Sonnet)
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
bash mass_deploy.sh
```

#### 🟢 DeepSeek V3 (深度求索)
```bash
export DEEPSEEK_API_KEY="sk-..."
bash mass_deploy.sh
```

#### 🟢 MiniMax (海螺)
```bash
export MINIMAX_API_KEY="eyJ..."
bash mass_deploy.sh
```

#### 🟢 Moonshot (Kimi / 月之暗面)
```bash
export MOONSHOT_API_KEY="sk-..."
bash mass_deploy.sh
```

#### 🟢 Z.AI (智谱清言 GLM-4)
```bash
export ZAI_API_KEY="..."
bash mass_deploy.sh
```

#### 🟢 Ollama (本地私有化)
```bash
# 默认连接 localhost:11434
export MODEL_PROVIDER="ollama"
bash mass_deploy.sh
```

### 4. 其他配置变量
| 变量名 | 描述 | 默认值 |
| :--- | :--- | :--- |
| `TOKEN` | 网关访问令牌 (Gateway Token) | 随机生成 |
| `PORT` | 服务端口 | 18789 |
| `ENABLE_SMTP` | 是否启用邮件 | false |
| `SMTP_HOST` | SMTP 服务器 | (无) |
| `SMTP_USER` | SMTP 账号 | (无) |
| `SMTP_PASS` | SMTP 密码 | (无) |
| `INSTALL_NODE` | (仅 Mac) 是否尝试自动安装 Node.js | true |

---

## 🌩️ 批量分发指南 (Mass Distribution)

如果您有 10 台甚至 100 台服务器，不需要一台台登录。这里有两种推荐方案。

### 方式一：SSH 循环 (适用于 1-20 台机器)
创建一个 `hosts.txt` 文件，每行一个 `IP`。然后运行以下循环命令：

```bash
# 1. 准备您的真实 Key
export MY_KEY="sk-real-openai-key-here"
export SMTP_PASS="real-password"

# 2. 循环分发并执行
for ip in $(cat hosts.txt); do
  echo "Deploying to $ip ..."
  
  # 上传脚本
  scp mass_deploy.sh root@$ip:/tmp/
  
  # 远程执行 (静默模式)
  ssh root@$ip "chmod +x /tmp/mass_deploy.sh && \
                export OPENAI_API_KEY='$MY_KEY' && \
                export ENABLE_SMTP='true' && \
                export SMTP_HOST='smtp.gmail.com' && \
                export SMTP_PORT='587' && \
                export SMTP_USER='bot@mycompany.com' && \
                export SMTP_PASS='$SMTP_PASS' && \
                /tmp/mass_deploy.sh" &
done
```

### 方式二：Ansible (适用于 >20 台机器)
这是行业标准做法。创建一个 Ansible Playbook `deploy_openclaw.yml`:

```yaml
- hosts: all
  become: yes
  vars:
    openai_key: "sk-real-key"
  tasks:
    - name: Copy install script
      copy:
        src: mass_deploy.sh
        dest: /root/mass_deploy.sh
        mode: '0755'

    - name: Run install script
      shell: |
        export OPENAI_API_KEY="{{ openai_key }}"
        /root/mass_deploy.sh
      args:
        executable: /bin/bash
```

执行：
```bash
ansible-playbook -i inventory.ini deploy_openclaw.yml
```

### 方式三：GitHub / HTTP 托管（推荐）
将脚本上传到 GitHub 仓库（例如 `your-repo/deploy.sh`），用户只需执行：

```bash
# 自动下载 -> 询问 Key -> 自动安装
curl -fsSL https://raw.githubusercontent.com/your-username/your-repo/main/mass_deploy.sh | bash
```

或者静默安装：
```bash
curl -fsSL .../mass_deploy.sh | GEMINI_API_KEY=xxx bash
```

---

## 部署后验证

安装完成后，脚本会输出访问地址。我们会自动生成 `openclaw_credentials.txt` 文件，您可以将其内容通过邮件发送给用户。

**Linux (Docker):**
- 容器名: `openclaw`
- 数据卷: `openclaw-data`
- 访问: `http://localhost:18789`

**macOS (Native):**
- 后台服务: `ai.openclaw.gateway`
- 配置文件: `~/.openclaw/openclaw.json`
- 访问: `http://localhost:18789`

## 5. 🕹️ 操作手册 & 面板访问 (Operations Manual)

OpenClaw 部署成功仅仅是第一步。以下是完整的日常操作指南。

### 1. 访问控制台 (Dashboard)

部署脚本结束时会输出一个带 Token 的链接，这是您唯一的管理入口。

*   **URL 格式**: `http://<服务器IP>:18789/?token=<YOUR_TOKEN>`
*   **示例**: `http://43.167.x.x:18789/?token=a1b2c3d4...`

> ⚠️ **Token 丢失怎么办？**
> *   **Linux (Docker)**: 运行 `docker exec openclaw openclaw config get gateway.auth.token`
> *   **macOS (Native)**: 运行 `openclaw config get gateway.auth.token` (或查看 `~/.openclaw/config.json`)

### 2. 后期模型配置 (如果不使用环境变量)

如果您在部署时没有设置 Model Key（**场景 A**），OpenClaw 也能启动，但无法回答问题。您可以通过以下两种方式补全配置：

#### 方式 A：通过 Web 面板 (推荐)
1.  打开上述 Dashboard 链接。
2.  点击左下角的 **"Settings" (设置)** 图标。
3.  找到 **"Models" (模型)** 选项卡。
4.  选择您的提供商 (如 OpenAI) 并填入 Key。
5.  点击 "Save"。无需重启。

#### 方式 B：通过命令行 (CLI)
适合无法访问 Web UI 的情况。

**Docker 环境:**
```bash
# 设置模型 (以 DeepSeek 为例)
docker exec openclaw openclaw config set auth.openai.baseURL "https://api.deepseek.com"
docker exec openclaw openclaw config set auth.openai.apiKey "sk-..."
docker exec openclaw openclaw config set agents.defaults.model "openai/deepseek-chat"
```

**Native 环境 (Mac):**
```bash
openclaw config set auth.anthropic.apiKey "sk-ant-..."
openclaw config set agents.defaults.model "anthropic/claude-3-5-sonnet"
```

### 3. 系统维护

#### 查看日志
*   **Docker**: `docker logs -f openclaw`
*   **Mac**: `tail -f ~/.openclaw/logs/gateway.log`

#### 更新版本
```bash
# Docker 自动更新
bash mass_deploy.sh

# Mac 手动更新
npm install -g @qingchencloud/openclaw-zh@latest
openclaw restart
```

## 常见问题

**Q: 部署时一定要选模型吗？**
A: **不需要**。您可以完全留空（脚本中直接回车，或不设置 ENV）。OpenClaw 会以 "空载" 模式启动。您可以稍后在 Web 界面中通过可视化方式填入 Key，这对非技术用户更友好。

**Q: Mac 上提示找不到 Node.js？**
A: 脚本会尝试检查 Node.js。如果没有安装，脚本会建议用户安装（或尝试通过 brew 安装，如果 brew 存在）。

**Q: 为什么 Docker 版不能控制 Mac 日历？**
A: Docker 容器是隔离的，无法与宿主机的 AppleScript/JXA 接口通信。这就是为什么我们在 Mac 上坚持使用原生安装。
