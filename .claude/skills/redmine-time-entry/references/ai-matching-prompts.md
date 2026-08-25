# AI 匹配提示模板

---

## 项目和活动匹配

**输入：** 任务列表（含用户指定的项目名称） + 项目列表 + 活动列表
**输出：** 包含 projectId、activityId、comments 的 JSON

### 提示模板

```
你是一个工时记录助手。将任务匹配到 Redmine 项目和活动类型，生成工时记录。

## 待匹配的任务列表
{taskList}

## 可用的 Redmine 项目（必须从这些项目中选择）
{projectList}

## 可用的活动类型（必须从这些类型中选择）
{activityList}

## 匹配规则
1. **项目匹配优先级**（按顺序）：
   a) 优先使用任务中用户指定的 projectName，在项目列表中搜索最接近的匹配
   b) 如果 projectName 无法匹配，尝试从 content 中提取编号前缀（如 VISSEL-845 → VISSEL），在项目列表中搜索包含该前缀的项目
   c) 以上均无法匹配时，返回 projectId: null，并在 reason 中说明原因

2. **活动类型匹配**：
   - 从任务的 content 推断活动类型（开发/设计/测试/会议/学习等）
   - 在活动列表中选择最接近的类型
   - 无法确定时返回 activityId: null，并在 reason 中说明原因

3. **生成工作描述**：
   - 简洁描述（50 字符以内）
   - 引用 content 中的关键信息（如编号）

## 返回 JSON 格式（只返回 JSON，不要其他文本）
{
  "entries": [
    {
      "projectName": "用户指定的项目名称",
      "content": "原始工作内容",
      "projectId": 123,
      "matchedProjectName": "匹配到的项目名称",
      "activityId": 8,
      "matchedActivityName": "匹配到的活动名称",
      "comments": "工作描述",
      "reason": null
    }
  ]
}

## ⚠️ 严格要求
- **projectId 必须是项目列表中的有效 ID**，不能编造；无法匹配时必须返回 null
- **activityId 必须是活动列表中的有效 ID**，不能编造；无法匹配时必须返回 null
- 不要自行假设默认项目或活动，匹配不确定时返回 null
```

### 格式示例

**{taskList}** — 逐条列出，示例：
```
- projectName: "Vissel 保守"
  content: "VISSEL-845 课题开发"
  hours: 3
```

**{projectList} / {activityList}** — 逐行列出，格式为 `ID:42 Name:楽天 VisselKobe 保守`。

**响应** — 返回 `entries` 数组，每条包含 `projectId`、`activityId`、`comments`、`reason`（匹配成功时为 null）。未匹配的 ID 字段返回 null。

### ID 校验

AI 响应使用前**必须**校验：
- `projectId` 为 null → 停止，向用户展示可用项目列表，参阅 [error-handling.md → 项目匹配失败](error-handling.md#项目匹配失败)
- `projectId` 不为 null 但不在项目列表中 → 同上
- `activityId` 同上规则

---

## 问题匹配

**输入：** 同一项目下的多条任务内容 + 该项目的问题列表
**输出：** 每条任务匹配到的 issueId 的 JSON（无法匹配时返回 null）

### 提示模板

```
将以下任务匹配到最相关的 Redmine 问题。

## 待匹配的工作内容
{contentList}

## 可用问题列表
{issueList}

## 匹配规则
- 根据任务的工作性质（开发/测试/设计等）匹配到对应分类的问题
- 任务 content 中的编号（如 VISSEL-845）是外部系统编号，不需要在问题列表中查找，只用于参考工作性质
- 如果无法根据工作性质确定匹配的问题，返回 issueId: null，并在 reason 中说明原因
- 必须从上述问题列表中选择有效的 ID，不能编造

## 返回 JSON 格式（只返回 JSON，不要其他文本）
{
  "matches": [
    {
      "content": "原始任务内容",
      "issueId": 1537,
      "issueSubject": "开发",
      "reason": null
    }
  ]
}
```

### 格式示例

**{contentList}** — 逐条列出，示例：
```
- content: "VISSEL-845 课题开发"
```

**{issueList}** — 逐行列出，格式为 `ID:1537 标题:开发`。

**响应** — 返回 `matches` 数组，每条包含 `content`、`issueId`、`issueSubject`、`reason`（匹配成功时为 null）。未匹配时 issueId 返回 null。

### ID 校验

- `issueId` 为 null 或不在问题列表中 → 停止，向用户展示可用问题列表，参阅 [error-handling.md → 问题匹配失败](error-handling.md#问题匹配失败)
