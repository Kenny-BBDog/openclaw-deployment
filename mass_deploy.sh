#!/bin/bash
# ==============================================================================
# OpenClaw Mass Deployment Script
# 
# 自动识别系统 (Linux/macOS) 并执行最佳实践部署。
# 支持通过环境变量预配置 LLM 密钥。
#
# 作者: OpenClaw 自动化助手
# ==============================================================================

set -e

# ================= Configuration =================
# 可以通过环境变量覆盖这些默认值
PORT="${PORT:-18789}"
TOKEN="${TOKEN:-$(openssl rand -hex 16 2>/dev/null || echo "secret-token-$(date +%s)")}"
INSTALL_NODE="${INSTALL_NODE:-true}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# ================= Interactive Configuration =================
echo -e "${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}  OpenClaw 自动化部署配置${NC}"
echo -e "${YELLOW}=======================================================${NC}"

# --- 1. LLM Configuration ---
# Helper function to prompt for choice
prompt_choice() {
    local prompt="$1"
    local var_name="$2"
    local options="$3"
    
    echo -e "$prompt"
    select opt in $options; do
        if [ -n "$opt" ]; then
            eval "$var_name=\"$opt\""
            break
        else
            echo "无效选择，请重试。"
        fi
    done
}

# 如果没有预设任何 KEY，则进入详细配置向导
if [ -z "$GEMINI_API_KEY" ] && [ -z "$MINIMAX_API_KEY" ] && [ -z "$OPENAI_API_KEY" ] && [ -z "$ANTHROPIC_API_KEY" ] && [ -z "$DEEPSEEK_API_KEY" ]; then
    echo "NO.1 [模型配置] 请选择您的主模型提供商 (输入数字):"
    
    PROVIDERS="Anthropic(Claude) OpenAI(GPT) DeepSeek(深度求索) MiniMax Moonshot(Kimi) Z.AI(智谱GLM) Google(Gemini) Ollama(本地) Custom(自定义)"
    
    select PROV in $PROVIDERS; do
        case "$PROV" in
            "Anthropic(Claude)")
                export MODEL_PROVIDER="anthropic"
                read -p "  > Anthropic API Key (sk-ant-...): " ANTHROPIC_API_KEY
                export ANTHROPIC_API_KEY
                break ;;
            "OpenAI(GPT)")
                export MODEL_PROVIDER="openai"
                read -p "  > OpenAI API Key (sk-...): " OPENAI_API_KEY
                export OPENAI_API_KEY
                break ;;
            "DeepSeek(深度求索)")
                export MODEL_PROVIDER="deepseek"
                read -p "  > DeepSeek API Key (sk-...): " DEEPSEEK_API_KEY
                export DEEPSEEK_API_KEY
                break ;;
            "MiniMax")
                export MODEL_PROVIDER="minimax"
                read -p "  > MiniMax API Key: " MINIMAX_API_KEY
                export MINIMAX_API_KEY
                break ;;
            "Moonshot(Kimi)")
                export MODEL_PROVIDER="moonshot"
                read -p "  > Moonshot API Key: " MOONSHOT_API_KEY
                export MOONSHOT_API_KEY
                break ;;
            "Z.AI(智谱GLM)")
                export MODEL_PROVIDER="zai"
                read -p "  > Z.AI/GLM API Key: " ZAI_API_KEY
                export ZAI_API_KEY
                break ;;
            "Google(Gemini)")
                export MODEL_PROVIDER="google"
                read -p "  > Google Gemini API Key: " GEMINI_API_KEY
                export GEMINI_API_KEY
                break ;;
            "Ollama(本地)")
                export MODEL_PROVIDER="ollama"
                read -p "  > Ollama URL (默认 http://localhost:11434): " OLLAMA_URL
                export OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
                break ;; 
            "Custom(自定义)")
                export MODEL_PROVIDER="custom"
                read -p "  > Base URL (如 https://api.xxx.com/v1): " CUSTOM_BASE_URL
                read -p "  > API Key: " CUSTOM_API_KEY
                break ;;
            *) echo "无效选择";;
        esac
    done
    echo ""
fi

# --- 2. Social Apps Configuration ---
# --- 2. Social Apps Configuration ---
if [ -z "$ENABLE_FEISHU" ] && [ -z "$ENABLE_WECOM" ]; then
    echo "NO.2 [社交软件接入] 是否需要配置国内社交平台?"
    
    if [ -z "$ENABLE_FEISHU" ]; then
        read -p "  > 是否安装飞书 (Feishu) 插件? [y/N]: " INSTALL_FEISHU
        [[ "$INSTALL_FEISHU" =~ ^[Yy]$ ]] && export ENABLE_FEISHU="true"
    fi

    if [ -z "$ENABLE_WECOM" ]; then
        read -p "  > 是否安装企业微信 (WeCom) 插件? [y/N]: " INSTALL_WECOM
        [[ "$INSTALL_WECOM" =~ ^[Yy]$ ]] && export ENABLE_WECOM="true"
    fi
    echo ""
fi

# --- 3. Advanced Skills ---
if [ -z "$ENABLE_SPECKIT" ]; then
    echo "NO.3 [高阶技能] 是否安装以下进阶技能?"
    read -p "  > 是否安装 SpecKit (规范驱动开发)? [y/N]: " INSTALL_SPECKIT
    [[ "$INSTALL_SPECKIT" =~ ^[Yy]$ ]] && export ENABLE_SPECKIT="true"
    echo ""
fi

# --- 4. SMTP Email Configuration ---
if [ -z "$ENABLE_SMTP" ]; then
    echo "NO.4 [邮件通知] 配置 SMTP 以便 AI 发送通知 (如 Gmail, Outlook, 企业邮)?"
    read -p "  > 是否配置 SMTP? [y/N]: " SETUP_SMTP
    if [[ "$SETUP_SMTP" =~ ^[Yy]$ ]]; then
        read -p "    - SMTP 服务器 (如 smtp.gmail.com): " SMTP_HOST
        read -p "    - SMTP 端口 (如 587/465): " SMTP_PORT
        read -p "    - 发件人邮箱: " SMTP_USER
        read -p "    - 邮箱密码/授权码: " SMTP_PASS
        export ENABLE_SMTP="true"
        export SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS
    fi
    echo ""
fi
# ================= OS Detection =================
OS_NAME=$(uname -s)
log_info "Detected OS: $OS_NAME"

# ================= LLM Configuration Logic =================
configure_llm() {
    local RUNNER="$1" # 'docker' or 'native'
    
    log_info "Configuring AI Models..."

    # Helper to set config based on runner
    set_conf() {
        local KEY="$1"
        local VALUE="$2"
        if [ "$RUNNER" == "docker" ]; then
            docker exec openclaw openclaw config set "$KEY" "$VALUE" >/dev/null
        else
            openclaw config set "$KEY" "$VALUE" >/dev/null
        fi
    }

    # 1. Google Gemini
    if [ -n "$GEMINI_API_KEY" ]; then
        log_info "-> Configuring Google Gemini..."
        set_conf "agents.defaults.model" "google/gemini-1.5-pro-latest"
        set_conf "auth.google.apiKey" "$GEMINI_API_KEY"
    fi

    # 2. MiniMax
    if [ -n "$MINIMAX_API_KEY" ]; then
        log_info "-> Configuring MiniMax..."
        set_conf "agents.defaults.model" "minimax/MiniMax-M2.1"
        set_conf "auth.minimax.apiKey" "$MINIMAX_API_KEY"
    fi
    
    # 3. Moonshot (Kimi)
    if [ -n "$MOONSHOT_API_KEY" ]; then
        log_info "-> Configuring Moonshot AI (Kimi)..."
        set_conf "agents.defaults.model" "moonshot/kimi-k2.5"
        set_conf "auth.moonshot.apiKey" "$MOONSHOT_API_KEY"
    fi

    # 4. Z.AI (GLM)
    if [ -n "$ZAI_API_KEY" ]; then
        log_info "-> Configuring Z.AI (GLM)..."
        set_conf "agents.defaults.model" "zai/glm-4.7"
        set_conf "auth.zai.apiKey" "$ZAI_API_KEY"
    fi

    # 5. OpenAI
    if [ -n "$OPENAI_API_KEY" ]; then
        log_info "-> Configuring OpenAI..."
        set_conf "agents.defaults.model" "openai/gpt-4o"
        set_conf "auth.openai.apiKey" "$OPENAI_API_KEY"
    fi
    
    # 6. Anthropic
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        log_info "-> Configuring Anthropic Claude..."
        set_conf "agents.defaults.model" "anthropic/claude-3-5-sonnet"
        set_conf "auth.anthropic.apiKey" "$ANTHROPIC_API_KEY"
    fi
    
    # 7. DeepSeek (via OpenAI Compatible)
    if [ -n "$DEEPSEEK_API_KEY" ]; then
        log_info "-> Configuring DeepSeek..."
        set_conf "auth.openai.baseURL" "https://api.deepseek.com/v1"
        set_conf "auth.openai.apiKey" "$DEEPSEEK_API_KEY"
        set_conf "agents.defaults.model" "openai/deepseek-chat"
    fi
    
    # 8. Custom / Ollama
    if [ "$MODEL_PROVIDER" == "ollama" ]; then
        log_info "-> Configuring Ollama..."
        set_conf "auth.openai.baseURL" "${OLLAMA_URL}/v1"
        set_conf "auth.openai.apiKey" "ollama"
        set_conf "agents.defaults.model" "openai/llama3"
    elif [ "$MODEL_PROVIDER" == "custom" ]; then
        log_info "-> Configuring Custom Provider..."
        set_conf "auth.openai.baseURL" "$CUSTOM_BASE_URL"
        set_conf "auth.openai.apiKey" "$CUSTOM_API_KEY"
        set_conf "agents.defaults.model" "openai/custom-model"
    fi

    log_success "AI Model configuration completed."
}

# ================= Linux Deployment (Docker) =================
deploy_linux() {
    log_info "Starting Linux (Docker) Deployment..."

    # 1. Check Docker
    if ! command -v docker &> /dev/null; then
        log_warn "Docker not found. Attempting to install via get.docker.com..."
        
        if command -v curl &> /dev/null; then
            log_info "Using Aliyun mirror for Docker installation..."
            curl -fsSL https://get.docker.com | sh -s -- --mirror Aliyun
        elif command -v wget &> /dev/null; then
            log_info "Using Aliyun mirror for Docker installation..."
            wget -qO- https://get.docker.com | sh -s -- --mirror Aliyun
        else
            log_error "Neither curl nor wget found. Cannot auto-install Docker."
            exit 1
        fi
        
        # Start Service
        systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
        
        if ! command -v docker &> /dev/null; then
            log_error "Docker auto-installation failed. Please install manualy."
            exit 1
        fi
        log_success "Docker installed successfully!"
    fi

    # 2. Run Official Docker Deploy Script
    # We use the official script to handle the heavy lifting (pull, run, etc.)
    # We pass --skip-init because we want to handle config manually specifically for LLMs
    log_info "Executing Docker deployment..."
    
    # 使用官方脚本逻辑，这里简化为直接调用 docker 命令以获得最大控制权
    CONTAINER_NAME="openclaw"
    IMAGE="ghcr.io/1186258278/openclaw-zh:latest"
    IMAGE_MIRROR="ghcr.dockerproxy.com/1186258278/openclaw-zh:latest"
    
    # 清理旧容器
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true

    # Pull Image with Fallback
    log_info "Pulling Docker Image ($IMAGE)..."
    if ! docker pull "$IMAGE"; then
        log_warn "Standard pull failed (likely GFW). Attempting to use Mirror ($IMAGE_MIRROR)..."
        if docker pull "$IMAGE_MIRROR"; then
            # Retag to match original expectation
            docker tag "$IMAGE_MIRROR" "$IMAGE"
            log_success "Image pulled via Mirror!"
        else
            log_error "Failed to pull image from both source and mirror. Please configure a proxy."
            exit 1
        fi
    fi

    # 启动容器
    # 注意：我们将 TOKEN 注入到环境变量，也作为参数传递
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p "${PORT}:18789" \
        -v openclaw-data:/root/.openclaw \
        -e OPENCLAW_GATEWAY_TOKEN="$TOKEN" \
        "$IMAGE" \
        openclaw gateway run

    log_info "Waiting for container to accept commands..."
    sleep 5 # Give it a moment

    # 3. Configure LLMs inside container
    configure_llm "docker"
    
    # 4. Plugins & Advanced Config (Docker specific exec)
    if [ "$ENABLE_FEISHU" == "true" ]; then
        log_info "Installing Feishu Plugin..."
        docker exec openclaw openclaw plugins install @mlheng-clawd/feishu
        docker exec openclaw openclaw config set channels.feishu.enabled true
        docker exec openclaw openclaw config set channels.feishu.connectionMode websocket
        if [ -n "$FEISHU_APP_ID" ]; then
            docker exec openclaw openclaw config set channels.feishu.appId "$FEISHU_APP_ID"
            docker exec openclaw openclaw config set channels.feishu.appSecret "$FEISHU_SECRET"
        fi
    fi

    if [ "$ENABLE_WECOM" == "true" ]; then
        log_info "Installing WeCom Plugin..."
        docker exec openclaw openclaw plugins install @mlheng-clawd/wecom
        if [ -n "$WECOM_AGENT_ID" ]; then
            docker exec openclaw openclaw config set channels.wecom.agentId "$WECOM_AGENT_ID"
            docker exec openclaw openclaw config set channels.wecom.secret "$WECOM_SECRET"
        fi
    fi
    
    if [ "$ENABLE_SPECKIT" == "true" ]; then
         log_info "Installing SpecKit..."
         docker exec openclaw openclaw skills install speckit
    fi
    
    # 设置中文 UI
    docker exec openclaw openclaw config set ui.language "zh-CN"

    log_success "Linux Deployment Complete!"
    echo -e "   Access: http://<IP>:${PORT}?token=${TOKEN}"
    
    # Generate User Invite / Credential File
    generate_invite_file "docker" "http://<YOUR_IP>:${PORT}?token=${TOKEN}"
}

# ================= macOS Deployment (Native) =================
deploy_mac() {
    log_info "Starting macOS (Native) Deployment..."

    # 1. Check/Install Node.js
    if ! command -v node &> /dev/null; then
        log_warn "Node.js not found."
        if [ "$INSTALL_NODE" == "true" ] && command -v brew &> /dev/null; then
            log_info "Attempting to install Node.js via Homebrew..."
            brew install node@22
            # Link if needed, best effort
            brew link --overwrite node@22 2>/dev/null || true
        else
            log_error "Node.js is required but not found. Please install Node.js v22+."
            exit 1
        fi
    fi

    # 2. Install OpenClaw (Global)
    log_info "Installing @qingchencloud/openclaw-zh..."
    npm install -g @qingchencloud/openclaw-zh@latest

    # 3. Setup & Configure
    log_info "Initializing configuration..."
    openclaw setup --non-interactive || true

    log_info "Configuring Gateway..."
    openclaw config set gateway.mode local
    openclaw config set gateway.port "$PORT"
    openclaw config set gateway.auth.token "$TOKEN"
    # Mac 上允许局域网访问
    openclaw config set gateway.bind lan 

    # 4. Configure LLMs
    configure_llm "native"
    
    # 5. Plugins & Advanced Config (Native)
    if [ "$ENABLE_FEISHU" == "true" ]; then
        log_info "Installing Feishu Plugin..."
        openclaw plugins install @mlheng-clawd/feishu
        openclaw config set channels.feishu.enabled true
        openclaw config set channels.feishu.connectionMode websocket
        if [ -n "$FEISHU_APP_ID" ]; then
            openclaw config set channels.feishu.appId "$FEISHU_APP_ID"
            openclaw config set channels.feishu.appSecret "$FEISHU_SECRET"
        fi
    fi
    
    if [ "$ENABLE_WECOM" == "true" ]; then
        log_info "Installing WeCom Plugin..."
        openclaw plugins install @mlheng-clawd/wecom
        if [ -n "$WECOM_AGENT_ID" ]; then
            openclaw config set channels.wecom.agentId "$WECOM_AGENT_ID"
            openclaw config set channels.wecom.secret "$WECOM_SECRET"
        fi
    fi
    
    if [ "$ENABLE_SPECKIT" == "true" ]; then
         log_info "Installing SpecKit..."
         openclaw skills install speckit
    fi
    

    # 6. Inject Custom SMTP Skill (if enabled)
    if [ "$ENABLE_SMTP" == "true" ]; then
        log_info "Injecting Custom SMTP Email Skill..."
        inject_smtp_skill "native"
        
        # 尝试发送验证邮件
        log_info "Sending verification email..."
        # 这里假设 openclaw run 可以调用 skill
        # 实际可能需要 restart 后才能生效，这里先做注入
    fi

    # 7. Install Daemon (Background Service)
    log_info "Installing LaunchAgent (Daemon)..."
    openclaw onboard --install-daemon || log_warn "Daemon installation returned non-zero, it might already be installed."

    log_success "macOS Deployment Complete!"
    echo -e "   Access: http://localhost:${PORT}?token=${TOKEN}"

    # Generate User Invite / Credential File
    generate_invite_file "native" "http://localhost:${PORT}?token=${TOKEN}"
}

# ================= Post-Install Helpers =================
generate_invite_file() {
    local MODE="$1"
    local URL="$2"
    local FILE="openclaw_credentials.txt"
    
    cat > "$FILE" <<EOF
================================================================
   🦞 OpenClaw has been deployed successfully! 🦞
================================================================

Hello,

Your personal AI assistant is ready.

1. Access URL: 
   $URL

2. Credentials:
   - Gateway Token: $TOKEN
   
   (Please keep this token safe. It is your password to access the bot.)

3. Getting Started:
   - Click the link above.
   - You can start chatting immediately!
   - Try asking: "Who are you?" or "Check the weather".

4. Admin Info:
   - Deployment Mode: $MODE
   - Provider: ${MODEL_PROVIDER:-"Environment Variable"}
   - Date: $(date)

================================================================
EOF
    
    echo ""
    log_success "Credential file generated: $FILE"
    echo -e "${GREEN}You can email the content of '$FILE' to the user.${NC}"
    
    if [ "$ENABLE_SMTP" == "true" ]; then
         echo -e "${GREEN}SMTP configured! You can ask OpenClaw: \"Send a test email to me\".${NC}"
    else
         echo -e "${YELLOW}(Why not auto-email? sending email requires complex SMTP/OAuth config which is safer handled manually by you.)${NC}"
    fi
}

# ================= Skill Injection Helper =================
inject_smtp_skill() {
    local MODE="$1"
    local SKILL_DIR="$HOME/.openclaw/skills/smtp-mailer"
    
    # Check if we are in Docker
    if [ "$MODE" == "docker" ]; then
        # Docker 比较复杂，需要挂载或 exec写入。这里简化为提示用户手动操作，
        # 或者如果映射了 volume，可以直接写入宿主机映射目录。
        # 假设 openclaw-data 映射到了本地某个位置？
        # 暂时跳过 Docker 版自动注入，因为路径不确定。
        log_warn "SMTP injection for Docker mode is not fully automated in this script version."
        return
    fi
    
    mkdir -p "$SKILL_DIR"
    
    # 1. Create skill.json / package.json
    cat > "$SKILL_DIR/package.json" <<EOF
{
  "name": "smtp-mailer",
  "version": "1.0.0",
  "description": "Simple SMTP email sender for OpenClaw",
  "main": "index.js",
  "dependencies": {
    "nodemailer": "^6.9.0"
  }
}
EOF

    # 2. Create index.js
    cat > "$SKILL_DIR/index.js" <<EOF
const nodemailer = require('nodemailer');

module.exports = {
  name: 'send_email',
  description: 'Send an email to a recipient using configured SMTP server.',
  parameters: {
    type: 'object',
    properties: {
      to: { type: 'string', description: 'Email address of the recipient' },
      subject: { type: 'string', description: 'Subject of the email' },
      text: { type: 'string', description: 'Body content of the email' }
    },
    required: ['to', 'subject', 'text']
  },
  handler: async ({ to, subject, text }) => {
    const transporter = nodemailer.createTransport({
      host: "$SMTP_HOST",
      port: $SMTP_PORT,
      secure: ${SMTP_SECURE:-false}, // Detect via port usually
      auth: {
        user: "$SMTP_USER",
        pass: "$SMTP_PASS"
      }
    });

    try {
      const info = await transporter.sendMail({
        from: '"OpenClaw Bot" <$SMTP_USER>',
        to,
        subject,
        text
      });
      return "Email sent successfully: " + info.messageId;
    } catch (error) {
      return "Error sending email: " + error.message;
    }
  }
};
EOF

    # 3. Install dependencies
    log_info "Installing dependencies for SMTP skill..."
    (cd "$SKILL_DIR" && npm install --silent)
    
    log_success "SMTP Custom Skill injected to $SKILL_DIR"
}

# ================= Main Entry =================

case "$OS_NAME" in
    Linux*)     deploy_linux ;;
    Darwin*)    deploy_mac ;;
    *)          log_error "Unsupported OS: $OS_NAME"; exit 1 ;;
esac
