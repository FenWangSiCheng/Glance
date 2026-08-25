# 错误处理与故障排除

本文档汇总所有匹配失败、提交错误和脚本故障的处理方法。

---

## 匹配失败处理

AI 匹配后，**必须**将返回的 ID 对照已获取列表进行校验。校验失败时遵循以下流程：

1. **立即停止处理** — 不要继续后续步骤
2. **明确告知失败原因** — 说明哪个字段匹配失败及原因
3. **列出可用选项** — 展示可选的项目/活动/问题
4. **等待用户响应** — 让用户提供正确信息或取消
5. **不要使用默认值** — 除非用户明确同意

### 项目匹配失败

**情况 1：找不到匹配的项目**
```
抱歉，在 Redmine 中找不到与 'Vissel' 相关的项目。
可用的项目列表：
- 楽天 VisselKobe 保守 (ID: 42)
- 楽天 VisselKobe 新規案件 (ID: 43)
- 非生産 (ID: 99)

请确认项目名称或从上述列表中选择一个。
```

**情况 2：AI 返回的 ID 不在列表中（幻觉生成）**
```
AI 匹配失败：返回的项目 ID (999) 不存在于系统中。

可用的项目列表：
- 楽天 VisselKobe 保守 (ID: 42)
- 楽天 VisselKobe 新規案件 (ID: 43)
- 非生産 (ID: 99)

请从上述列表中选择或提供更准确的项目名称。
```

**情况 3：匹配置信度过低（多个候选项目）**
```
根据描述 'XXX'，无法确定具体项目。
相似的项目有：
- 楽天 VisselKobe 保守 (ID: 42)
- 楽天 VisselKobe 新規案件 (ID: 43)

请明确指定是哪个项目。
```

### 问题匹配失败

**情况：AI 返回的 issueId 不在项目问题列表中（幻觉生成）**
```
AI 匹配失败：返回的问题 ID (999) 不存在于项目 'RNV01_楽天 VisselKobe 保守' 中。

该项目当前的问题列表：
- #1537: 开发
- #1538: design
- #1539: 测试
- #1540: 工程管理

请从上述列表中选择对应的问题。
```

问题匹配失败时用户可选：
- 从列表中选择现有问题
- 取消操作

---

## 审核页展示

### 正常审核（全部匹配成功）

```
📋 待审核的工时记录（请确认无误后回复"提交"）

--- 记录 1/3 ---
日期：    2025-01-15
项目：    楽天 VisselKobe 保守 (ID: 42)  ✅
任务：    #1537 開発                      ✅
活动：    開発 (ID: 9)                   ✅
工时：    5.0h
描述：    [VISSEL-839][VISSEL-840] 課題開発

--- 记录 2/3 ---
日期：    2025-01-15
项目：    楽天 VisselKobe 保守 (ID: 42)  ✅
任务：    #1538 テスト                    ✅
活动：    テスト (ID: 10)                ✅
工时：    3.0h
描述：    [VISSEL-841] テスト

--- 记录 3/3 ---
日期：    2025-01-15
项目：    楽天 KDreams 准委任 (ID: 44)   ✅
任务：    #2200 開発                      ✅
活动：    開発 (ID: 9)                   ✅
工时：    4.0h
描述：    [KDREAMS-2143] 課題開発

请回复 "提交" 确认提交，或告知需要修改的内容。
```

> 注意：记录 1 和记录 2 同属项目 42，但匹配到不同 issue，因此作为独立记录分别提交。

---

### 部分匹配成功

某些字段匹配失败时，标注 ⚠️ 并提供替代方案：

```
📋 生成的工时记录（需要确认）：

日期：    2025-01-15
项目：    楽天 VisselKobe 保守 (ID: 42) ✅
任务：    未找到匹配的问题 ⚠️
活动：    開発 (ID: 9) ✅
工时：    4.0h
描述：    完成 backlog 課題開発

⚠️ 注意：AI 匹配返回的问题 ID 无效
建议：从项目问题列表中手动选择对应问题

[编辑后提交 / 取消]
```

### 完全匹配失败

```
❌ 无法生成工时记录

以下信息匹配失败：
- 项目: 找不到与 'Vissel' 相关的项目 ❌

可用项目列表：
- 楽天 VisselKobe 保守 (ID: 42)
- 楽天 VisselKobe 新規案件 (ID: 43)

请提供正确的项目名称后重试。
```

---

## 提交错误

`submit_time_entry` 返回错误时的恢复方法：

| 错误 | 原因 | 处理方法 |
|---|---|---|
| `HTTP 422: Hours is not a number` | `hours` 字段格式错误 | 确保是小数字符串，如 `"4.0"`，不能用逗号或整数 |
| `HTTP 422: Issue not found` | `issue_id` 不存在或不属于该项目 | 先用 `fetch_issues` 确认问题存在，或移除 `issue_id` 字段 |
| `HTTP 401: Unauthorized` | API Key 无效或已过期 | 在 Redmine 重新生成 API Key，更新环境变量 |
| `HTTP 403: Forbidden` | 用户权限不足 | 联系 Redmine 管理员授权 |
| `HTTP 404: Not Found` | URL 配置错误 | 检查 `REDMINE_URL`（不要带末尾斜杠） |

`spent_on` 必须是 `yyyy-MM-dd`；`hours` 必须是小数字符串（如 `"2.5"`），不能是整数或使用逗号。

---

## 邮件发送错误

`send_report.py` 返回错误时的处理方法：

| 错误 | 原因 | 处理方法 |
|---|---|---|
| `Missing required environment variables` | 必需的 email 环境变量未设置 | 设置 `EMAIL_USER`、`EMAIL_PASS`、`EMAIL_TO`、`EMAIL_SENDER_NAME`，参阅 [setup-guide.md → Email 配置](setup-guide.md#email-daily-report-configuration-optional) |
| `SMTP认证失败` | 密码错误或客户端专用密码已失效 | 在企业微信邮箱 → 设置 → 安全登录 重新生成客户端专用密码，更新 `EMAIL_PASS` |
| `连接 SMTP 服务器失败` | 网络不通或 SMTP 端点不可达 | 检查网络连通性；如在公司内网，确认是否需要代理 |
| `发送失败` | 收件人地址无效或服务器拒绝 | 检查 `EMAIL_TO` 格式（多个收件人用逗号分隔，不带空格） |
| `JSON解析错误` | `--data` 传入的数据格式不对 | 确认 `--data` 是合法的 JSON 数组 |

**注意：** 步骤 8 仅在 email 环境变量全部配置时才执行。任一缺失时静默跳过，不影响工时提交结果。

---

## 脚本故障排除

### 脚本文件找不到

**错误：** `python3: can't open file 'scripts/redmine_api.py'`

**解决：** 使用绝对路径：
```bash
python3 /path/to/skills/redmine-time-entry/scripts/redmine_api.py
```

### 环境变量未设置

**错误：** `REDMINE_URL not configured`

**解决：**
```bash
export REDMINE_URL="https://redmine.example.com"
export REDMINE_API_KEY="your_key"
```

### 无效的 JSON 响应

**错误：** `json.JSONDecodeError: Expecting value`

**原因：** Redmine 返回了非 JSON 响应（如 HTML 错误页面），通常是 URL 配置有误。

**解决：**
1. 直接运行脚本查看原始输出
2. 用 curl 手动验证：`curl -H "X-Redmine-API-Key: YOUR_KEY" https://redmine.example.com/users/current.json`
3. 如果 Redmine 在子路径，确保 URL 包含子路径

### 网络连接失败

**错误：** `Network error: Connection refused`

**原因：** Redmine 服务器不可达、需要 VPN、防火墙拦截。

**解决：** 检查服务器状态、网络连通性、是否需要代理（参阅 [setup-guide.md → 代理配置](setup-guide.md#使用代理)）。
