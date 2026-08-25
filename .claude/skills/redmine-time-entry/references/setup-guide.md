# 配置指南

## 前提条件

- Python 3.6+
- Redmine 实例访问权限及 API Key

## 获取 Redmine API Key

1. 登录 Redmine → **我的账户**（右上角）
2. 在 **API 访问密钥** 区域点击 **显示**
3. 复制 API Key（格式如：`a1b2c3d4e5f6...`）

## 配置环境变量

添加到 shell 配置文件（`~/.zshrc` 或 `~/.bashrc`），然后执行 `source` 使配置生效：

```bash
export REDMINE_URL="https://redmine.example.com"
export REDMINE_API_KEY="your_api_key_here"
```

**验证配置：**
```bash
python3 scripts/redmine_api.py test_connection
```

预期返回当前用户信息。如报错，检查：
- 环境变量是否已设置：`echo $REDMINE_URL $REDMINE_API_KEY`
- API Key 是否正确
- URL 末尾不带斜杠
- 是否能访问 Redmine 服务器

---

## Email 日报配置（可选）

工时提交成功后可自动发送日报邮件。添加以下环境变量：

```bash
export EMAIL_USER="your-email@company.com"   # 发件人邮箱
export EMAIL_PASS="client-specific-password" # 客户端专用密码
export EMAIL_TO="recipient@company.com"      # 收件人，多个用逗号分隔（不带空格）
export EMAIL_SENDER_NAME="张三"              # 日报签名
```

> SMTP 默认配置为企业微信 `smtp.exmail.qq.com:465`（SSL）。非企业微信邮箱时可通过 `SMTP_HOST` / `SMTP_PORT` 环境变量覆盖。

**获取客户端专用密码：** 企业微信邮箱 → 设置 → 安全登录 → 生成客户端专用密码。

**验证 SMTP：**
```bash
python3 scripts/send_report.py test
```

> 四个 email 变量任一缺失时，日报步骤会静默跳过，不影响工时提交流程。

---

## 安全须知

- 不要将 `.env` 文件提交到 Git（添加到 `.gitignore`）
- 定期在 Redmine → 我的账户 重置 API Key
- API Key 建议仅开放项目/问题读取权限和工时记录写入权限

---

## 使用代理

公司内网环境时，可能需要配置代理：

```bash
export HTTP_PROXY="http://proxy.example.com:8080"
export HTTPS_PROXY="http://proxy.example.com:8080"
```
