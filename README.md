# 🦞 OpenClaw 自动化部署套件

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)]()

> 一行命令，全自动部署开源 AI 助手 [OpenClaw](https://github.com/openclaw-ai/openclaw) 汉化版。
> 支持国内网络环境，内置 Docker 自动安装 + 镜像加速 + 多模型配置。

---

## ✨ 功能特性

- **🖥 跨平台**: 自动识别 Linux (Docker) 和 macOS (Native) 并选择最佳部署方案
- **🌐 国内友好**: 内置阿里云 Docker 镜像 + ghcr 代理，轻松穿越 GFW
- **🤖 多模型支持**: 支持 OpenAI, Claude, Gemini, DeepSeek, Kimi, MiniMax, GLM 等主流大模型
- **📧 邮件通知**: 可选配置 SMTP，让 AI 主动发送邮件
- **🚀 批量分发**: 支持 SSH 循环 / Ansible / HTTP 远程部署
- **📝 凭证生成**: 自动生成 `openclaw_credentials.txt`，方便发送给用户

---

## 🚀 快速开始

### 方式一：一行命令安装 (推荐)

```bash
curl -fsSL https://raw.githubusercontent.com/Kenny-BBDog/openclaw-deployment/main/mass_deploy.sh | bash
```

脚本会交互式询问您的模型 Key，然后自动完成安装。

### 方式二：静默安装 (CI/CD 友好)

```bash
# 预设 OpenAI Key
export OPENAI_API_KEY="sk-proj-..."
curl -fsSL .../mass_deploy.sh | bash
```

### 方式三：手动下载执行

```bash
git clone https://github.com/Kenny-BBDog/openclaw-deployment.git
cd openclaw-deployment
chmod +x mass_deploy.sh
./mass_deploy.sh
```

---

## 🧠 模型配置速查表

预设对应的环境变量，脚本会自动完成配置。

| 提供商 | 环境变量 | 示例 |
| :--- | :--- | :--- |
| **OpenAI (GPT-4o)** | `OPENAI_API_KEY` | `sk-proj-...` |
| **Anthropic (Claude)** | `ANTHROPIC_API_KEY` | `sk-ant-...` |
| **Google (Gemini)** | `GEMINI_API_KEY` | `AIzaSy...` |
| **DeepSeek (深度求索)** | `DEEPSEEK_API_KEY` | `sk-...` |
| **MiniMax (海螺)** | `MINIMAX_API_KEY` | `eyJ...` |
| **Moonshot (Kimi)** | `MOONSHOT_API_KEY` | `sk-...` |
| **Z.AI (智谱 GLM)** | `ZAI_API_KEY` | `...` |
| **Ollama (本地)** | `MODEL_PROVIDER=ollama` | - |

### 示例：部署 DeepSeek

```bash
export DEEPSEEK_API_KEY="sk-your-deepseek-key"
bash mass_deploy.sh
```

### 示例：部署 Claude

```bash
export ANTHROPIC_API_KEY="sk-ant-your-key"
bash mass_deploy.sh
```

---

## ⚙️ 其他配置变量

| 变量名 | 描述 | 默认值 |
| :--- | :--- | :--- |
| `TOKEN` | 网关访问令牌 | 随机生成 |
| `PORT` | 服务端口 | `18789` |
| `ENABLE_SMTP` | 是否启用邮件功能 | `false` |
| `SMTP_HOST` | SMTP 服务器 | - |
| `SMTP_USER` | SMTP 账号 | - |
| `SMTP_PASS` | SMTP 密码 | - |
| `ENABLE_FEISHU` | 是否安装飞书插件 | `false` |
| `ENABLE_WECOM` | 是否安装企业微信插件 | `false` |

---

## 🌩️ 批量分发 (Mass Distribution)

### 方式一：SSH 循环 (1-20 台机器)

创建 `hosts.txt`，每行一个 IP：

```bash
for ip in $(cat hosts.txt); do
  scp mass_deploy.sh root@$ip:/tmp/
  ssh root@$ip "export OPENAI_API_KEY='sk-...' && bash /tmp/mass_deploy.sh" &
done
```

### 方式二：Ansible (20+ 台机器)

```yaml
# deploy_openclaw.yml
- hosts: all
  become: yes
  vars:
    openai_key: "sk-real-key"
  tasks:
    - name: Copy script
      copy:
        src: mass_deploy.sh
        dest: /root/mass_deploy.sh
        mode: '0755'
    - name: Run script
      shell: |
        export OPENAI_API_KEY="{{ openai_key }}"
        /root/mass_deploy.sh
```

执行：`ansible-playbook -i inventory.ini deploy_openclaw.yml`

---

## 🕹️ 操作手册

### 访问控制台 (Dashboard)

部署成功后，脚本会输出带 Token 的访问链接：

```
http://<服务器IP>:18789/?token=<YOUR_TOKEN>
```

> **Token 丢失怎么办？**
> - Docker: `docker exec openclaw openclaw config get gateway.auth.token`
> - Mac: `openclaw config get gateway.auth.token`

### 后期配置模型 (如果部署时留空)

#### 通过 Web 面板

1. 打开 Dashboard
2. 点击左下角 **Settings** 图标
3. 选择 **Models** 选项卡
4. 填入您的 API Key，点击 Save

#### 通过命令行

```bash
# Docker 环境
docker exec openclaw openclaw config set auth.openai.apiKey "sk-..."
docker exec openclaw openclaw config set agents.defaults.model "openai/gpt-4o"

# macOS 环境
openclaw config set auth.anthropic.apiKey "sk-ant-..."
openclaw config set agents.defaults.model "anthropic/claude-3-5-sonnet"
```

### 系统维护

```bash
# 查看日志
docker logs -f openclaw          # Docker
tail -f ~/.openclaw/logs/*.log   # Mac

# 更新版本
bash mass_deploy.sh              # Docker (重新运行脚本即可)
npm install -g @qingchencloud/openclaw-zh@latest && openclaw restart  # Mac
```

---

## ❓ 常见问题

<details>
<summary><b>Q: 部署时一定要选模型吗？</b></summary>

**不需要**。您可以完全留空（脚本中直接回车）。OpenClaw 会以"空载"模式启动。稍后可在 Web 界面中填入 Key。
</details>

<details>
<summary><b>Q: 为什么 Docker 版不能控制 Mac 日历？</b></summary>

Docker 容器是隔离的，无法调用 macOS 的 AppleScript/JXA 接口。因此 Mac 必须使用原生安装。
</details>

<details>
<summary><b>Q: 国内服务器拉取镜像超时？</b></summary>

脚本已内置自动切换逻辑：如果 `ghcr.io` 拉取失败，会自动使用 `ghcr.dockerproxy.com` 镜像源。
</details>

<details>
<summary><b>Q: 如何完全卸载？</b></summary>

```bash
# Docker
docker stop openclaw && docker rm openclaw
docker volume rm openclaw-data

# Mac
npm uninstall -g @qingchencloud/openclaw-zh
rm -rf ~/.openclaw
```
</details>

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

## 🙏 致谢

- [OpenClaw](https://github.com/openclaw-ai/openclaw) - 开源 AI 助手
- [青辰云](https://github.com/qingchencloud) - 汉化版维护者
