---
name: redmine-time-entry
description: 当用户想记录工时、提交工时、log time、submit time entries 到 Redmine 时使用。AI 驱动的工时记录自动化工具，通过自然语言描述工作内容（例如："今天在 VISSEL-848 上工作了 4 小时"）即可提交工时记录。AI 智能匹配任务到 Redmine 项目、问题和活动，生成结构化的工时记录提交。包含可直接使用的 Python 脚本，通过环境变量配置调用 Redmine REST API。
---

# AI 驱动的 Redmine 工时记录

## 设置（仅首次使用）

配置凭证并验证连接：

```bash
export REDMINE_URL="https://redmine.example.com"
export REDMINE_API_KEY="your_api_key_here"
python3 scripts/redmine_api.py test_connection
```

详细配置说明 → [setup-guide.md](references/setup-guide.md)

---

## 核心规则

### 1. 用户输入必须包含三个字段

开始处理前，确认用户提供了：

| 字段 | 是否必需 | 示例 |
|---|---|---|
| 项目名称 | 必需 | "Vissel 保守"、"Vissel 新規" |
| 工作内容 | 必需 | "VISSELAPP-848 backlog 課題開発" |
| 工作时间 | 必需 | "4"、"3.5" |
| 日期 | 可选（默认今天） | "2025-01-15" |

缺少任何必需字段时，向用户询问补充信息，不要猜测。

### 2. 按项目+问题维度生成记录；同项目不同问题必须拆分

每条工时记录绑定一个 `issue_id`，因此合并规则为：
- **同一项目 + 同一 issue → 合并为一条记录**，在描述中列出所有对应的 Backlog 编号
- **同一项目 + 不同 issue → 生成独立记录**，各自带有对应工时
- **不同项目 → 生成独立记录**

```
输入：  VISSEL-839 → issue #1537 (開発), 3h
        VISSEL-840 → issue #1537 (開発), 2h
        VISSEL-841 → issue #1538 (テスト), 3h
        项目均为: 楽天 VisselKobe 保守

输出：  2 条记录
        ├─ 项目: 楽天 VisselKobe 保守, issue #1537, 工时: 5.0h
        │       描述: "VISSEL-839、VISSEL-840 開発"
        └─ 项目: 楽天 VisselKobe 保守, issue #1538, 工时: 3.0h
                描述: "VISSEL-841 テスト"
```

### 3. 提交前必须用户审核；匹配失败不要猜测

- 永远不要未经审核自动提交。
- 如果 AI 返回的 ID 不在已获取的列表中，**立即停止，向用户展示可用选项**。不要静默回退到默认项目。
- 匹配失败的详细处理 → [error-handling.md](references/error-handling.md)

### 4. 提交和日报前需要用户明确确认

- 步骤 3 和步骤 5 的 AI 匹配结果校验通过后自动继续，不逐步确认。所有匹配结果汇总在步骤 6 审核页统一展示。
- **用户必须明确回复"提交"后，才能执行 Redmine 提交（步骤 7）。** 其他任何回复（如"好"、"嗯"、"继续"）均不视为提交确认。
- 如果用户在步骤 6 审核时提出修改意见，修改后必须**重新展示完整记录**，再次等待用户回复"提交"。
- 发送日报（步骤 8）同样需要用户明确确认才能执行，不自动发送。

---

## 工作流程

### 步骤 1：解析并验证用户输入

从自然语言中提取：项目名称、工作内容、工作时间、日期（默认今天）。问题匹配由步骤 4-5 通过 Redmine API 自动完成，无需用户提供。

三个必需字段有任何一个缺失，就先向用户确认补充，然后再继续。

解析后构建结构化任务列表，供步骤 3 代入 AI prompt：

```
- projectName: "Vissel 保守"
  content: "VISSEL-845、VISSEL-847 课题开发"
  hours: 3
  date: "2025-01-15"
- projectName: "kdreams"
  content: "KDREAMS-2143、KDREAMS-2121 课题开发"
  hours: 3
  date: "2025-01-15"
- projectName: "学习"
  content: "openClaw 部署"
  hours: 2
  date: "2025-01-15"
```

### 步骤 2：获取项目和活动类型

两个命令并行执行

```bash
python3 scripts/redmine_api.py fetch_projects
python3 scripts/redmine_api.py fetch_activities
```

### 步骤 3：AI 匹配项目和活动类型

读取 [ai-matching-prompts.md → 项目和活动匹配](references/ai-matching-prompts.md#项目和活动匹配) 中的提示模板。

将步骤 1 构建的任务列表作为 `{taskList}`、fetch 返回的项目列表作为 `{projectList}`、活动列表作为 `{activityList}` 代入模板，解析 AI 响应为 JSON。

**校验规则：**
- `projectId` 为 null → 停止该任务的后续流程，向用户展示可用项目列表，等待用户选择
- `projectId` 不为 null 但不在项目列表中 → 停止，参阅 [error-handling.md → 匹配失败处理](references/error-handling.md#匹配失败处理)
- `activityId` 同上

校验通过后直接继续步骤 4。匹配结果会在步骤 6 审核页汇总展示。

### 步骤 4：获取匹配项目的问题列表

匹配到多个不同项目时，**并行执行**所有项目的 fetch：

```bash
# 每个匹配到的项目并行执行
python3 scripts/redmine_api.py fetch_issues --project-id <项目ID-1>
python3 scripts/redmine_api.py fetch_issues --project-id <项目ID-2>
```

### 步骤 5：AI 匹配问题

读取 [ai-matching-prompts.md → 问题匹配](references/ai-matching-prompts.md#问题匹配) 中的提示模板。

**按项目分组，同一项目的所有任务合并为一次 AI 调用（效率优化）。** 将步骤 3 匹配结果按 `projectId` 分组，提取每组中各条目的 `content` 字段作为 `{contentList}`、步骤 4 对应项目 `fetch_issues` 返回的问题列表作为 `{issueList}` 代入模板。

**每个 content 匹配到的 issueId 独立处理：**
- 匹配到不同 issue 的任务 → 生成独立工时记录
- 匹配到相同 issue 的任务 → 合并为一条记录，工时累加，描述拼接

校验规则：
- `issueId` 为 null 或不在问题列表中 → 停止，向用户展示该项目的可用问题列表，等待用户选择，参阅 [error-handling.md → 问题匹配失败](references/error-handling.md#问题匹配失败)

校验通过后直接继续步骤 6。匹配结果会在步骤 6 审核页汇总展示。

### 步骤 6：展示完整工时记录供最终审核

汇总所有字段，每个字段标注匹配状态（✅ / ⚠️）。此为提交前的最后一次审核，用户必须明确回复 **"提交"** 才能执行步骤 7。

审核页格式和展示模板 → [error-handling.md → 审核页展示](references/error-handling.md#审核页展示)。

- 某个字段未匹配时标注 ⚠️，并提供可选替代方案，方可允许提交。
- 如果用户在此环节提出修改，修改后**必须重新展示完整记录**，再次等待用户回复"提交"。

### 步骤 7：提交

**仅当用户明确回复"提交"后才执行。** 逐条调用 `submit_time_entry` 命令，用法参阅 [redmine-api.md → submit_time_entry](references/redmine-api.md#submit_time_entry)。

- 成功返回 `{"success": true}`；错误返回 `{"error": "..."}` — 恢复方法参阅 [error-handling.md → 提交错误](references/error-handling.md#提交错误)。
- 同一项目但不同 issue 的记录独立提交。

### 步骤 8：提交成功后发送日报（可选，需用户确认）

**触发条件：** 所有记录提交成功，且 email 环境变量已配置（`EMAIL_USER`、`EMAIL_PASS`、`EMAIL_TO`、`EMAIL_SENDER_NAME` 均存在）。未配置时静默跳过，不报错。

**发送前必须向用户展示日报内容并确认。** 用户回复"发送"后才能执行。执行命令用法参阅 `scripts/send_report.py` — `send --data` 传入本次所有提交记录（JSON 数组）；同一项目多条记录会自动合并（comments 用 ；拼接）。

发送错误的处理 → [error-handling.md → 邮件发送错误](references/error-handling.md#邮件发送错误)。

---

## 参考文档

| 文件 | 何时阅读 |
|---|---|
| [setup-guide.md](references/setup-guide.md) | 首次配置环境变量（含 email）、安全须知、代理配置 |
| [ai-matching-prompts.md](references/ai-matching-prompts.md) | 步骤 3 和步骤 5 构建 AI 提示前 |
| [redmine-api.md](references/redmine-api.md) | 脚本内部实现、分页机制、扩展新命令 |
| [error-handling.md](references/error-handling.md) | 任何匹配失败、提交错误、邮件发送错误或故障排除 |
