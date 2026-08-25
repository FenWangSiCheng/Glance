# Redmine API 脚本命令参考

`scripts/redmine_api.py` — 基于标准库的 Redmine REST API 客户端，无需第三方依赖。所有输出为 JSON，错误输出到 stderr（格式：`{"error": "..."}`）。

**所需环境变量：**
- `REDMINE_URL` — Redmine 实例地址（末尾斜杠自动移除）
- `REDMINE_API_KEY` — 通过 `X-Redmine-API-Key` 头发送

---

## test_connection

验证凭证并获取当前用户信息。

```bash
python3 scripts/redmine_api.py test_connection
```

**端点：** `GET /users/current.json`

**响应：**
```json
{"user": {"id": 1, "login": "admin", "firstname": "太郎", "lastname": "山田", "mail": "admin@example.com"}}
```

---

## fetch_projects

获取所有活跃项目。自动分页（每页 100 条），过滤已归档项目（`status == 5`），按名称排序。

```bash
python3 scripts/redmine_api.py fetch_projects
```

**端点：** `GET /projects.json?limit=100&offset=0`（自动递增 offset 直至获取全部）

**响应：**
```json
[{"id": 42, "name": "楽天 VisselKobe 保守", "identifier": "vissel-maintenance", "status": 1}]
```

---

## fetch_issues

获取指定项目的问题列表（最多 100 条）。

```bash
python3 scripts/redmine_api.py fetch_issues --project-id <PROJECT_ID>
```

**端点：** `GET /issues.json?project_id={PROJECT_ID}&limit=100`

**响应：**
```json
[{"id": 848, "subject": "ログイン機能開発", "project": {"id": 42, "name": "楽天 VisselKobe 保守"}, "tracker": {"id": 2, "name": "Feature"}, "status": {"id": 1, "name": "New"}}]
```

---

## fetch_activities

获取所有可用的工时活动类型。

```bash
python3 scripts/redmine_api.py fetch_activities
```

**端点：** `GET /enumerations/time_entry_activities.json`

**响应：**
```json
[{"id": 9, "name": "開発", "is_default": true}, {"id": 10, "name": "テスト"}, {"id": 11, "name": "会議"}, {"id": 12, "name": "設計"}]
```

---

## submit_time_entry

提交一条工时记录。多条记录需逐条调用。

```bash
python3 scripts/redmine_api.py submit_time_entry --data '{
  "project_id": 42,
  "issue_id": 848,
  "activity_id": 9,
  "spent_on": "2025-01-15",
  "hours": "4.0",
  "comments": "完成登录功能开发"
}'
```

**端点：** `POST /time_entries.json`（成功返回 HTTP 201）

**字段验证：**

| 字段 | 类型 | 要求 |
|---|---|---|
| project_id | int | 必须是存在的项目 ID |
| issue_id | int | 必须属于对应项目 |
| activity_id | int | 必须是活动列表中的有效 ID |
| spent_on | string | `yyyy-MM-dd` 格式 |
| hours | string | 小数字符串，如 `"4.0"`；不能是整数或用逗号 |
| comments | string | 工作描述 |

**成功响应：** `{"success": true, "message": "Time entry submitted"}`

提交错误的恢复方法 → [error-handling.md → 提交错误](error-handling.md#提交错误)
