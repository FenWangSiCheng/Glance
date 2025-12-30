import SwiftUI
import AppKit

// MARK: - Main View
struct MainView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            TodosDetailView(viewModel: viewModel)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 560)
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .alert("错误", isPresented: $viewModel.showingError) {
            Button("确定", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "发生未知错误")
        }
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "checklist")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("Glance")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            Divider()
                .padding(.horizontal, 16)

            Spacer()

            // Main action button
            VStack(spacing: 16) {
                Button {
                    Task {
                        await viewModel.fetchAndGenerateTodos()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isGeneratingTodos {
                            ProgressView()
                                .scaleEffect(0.8)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "sparkles")
                                .accessibilityHidden(true)
                        }
                        Text(viewModel.isGeneratingTodos ? "生成中..." : "获取票据并生成待办")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isConfigured || viewModel.isGeneratingTodos)
                .accessibilityLabel("获取票据并生成待办清单")
                .accessibilityHint(viewModel.isGeneratingTodos ? "正在生成中" : "从 Backlog 获取票据并使用 AI 生成待办清单")

                if !viewModel.todoItems.isEmpty {
                    Text("\(viewModel.todoItems.count) 项待办")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabelColor))
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            // Footer
            sidebarFooter
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("打开设置")
                .accessibilityHint("配置 Backlog 和 AI API")
                .help("设置")
            }
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 12) {
            Divider()

            if !viewModel.isConfigured {
                configurationWarning
            } else {
                connectionStatus
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var configurationWarning: some View {
        Button {
            viewModel.showingSettings = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(.systemOrange))
                    .accessibilityHidden(true)
                Text("需要配置 API")
                    .font(.caption)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabelColor))
                    .accessibilityHidden(true)
            }
            .padding(10)
            .background(Color(.systemOrange).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("API 配置警告")
        .accessibilityHint("点击打开设置以配置 API")
        .frame(minHeight: 44)
    }

    private var connectionStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(.systemGreen))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text("已连接")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabelColor))
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("连接状态：已连接")
    }
}

// MARK: - Todos Detail View
struct TodosDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var editingTodo: TodoItem?
    @State private var editingText: String = ""
    @State private var newTodoText: String = ""
    @FocusState private var isNewTodoFocused: Bool

    /// 根据 Reduce Motion 设置选择动画
    private var standardAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 新增待办输入框
            addTodoBar

            if viewModel.todoItems.isEmpty && newTodoText.isEmpty {
                emptyState
            } else {
                todosList
            }
        }
        .navigationTitle("待办清单")
        .overlay {
            if viewModel.isGeneratingTodos {
                generatingOverlay
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("待办清单视图")
    }

    private var addTodoBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.title2)
                .foregroundStyle(Color(.tertiaryLabelColor))
                .accessibilityHidden(true)

            TextField("添加新待办...", text: $newTodoText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isNewTodoFocused)
                .onSubmit {
                    addNewTodo()
                }
                .accessibilityLabel("新待办输入框")
                .accessibilityHint("输入待办内容后按回车添加")

            if !newTodoText.isEmpty {
                Button {
                    addNewTodo()
                } label: {
                    Text("添加")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("添加待办")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
    }

    private func addNewTodo() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation(standardAnimation) {
            viewModel.addTodo(title: trimmed)
        }
        newTodoText = ""
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "checklist",
            title: "暂无待办事项",
            subtitle: "点击左侧「获取票据并生成待办」按钮开始"
        )
    }

    private var todosList: some View {
        List {
            ForEach(viewModel.todoItems) { item in
                TodoItemRow(
                    item: item,
                    isEditing: editingTodo?.id == item.id,
                    editingText: $editingText,
                    reduceMotion: reduceMotion,
                    onToggle: { viewModel.toggleTodoCompletion(item) },
                    onDelete: { viewModel.deleteTodo(item) },
                    onStartEdit: {
                        editingTodo = item
                        editingText = item.title
                    },
                    onSaveEdit: {
                        viewModel.updateTodoTitle(item, newTitle: editingText)
                        editingTodo = nil
                    },
                    onCancelEdit: {
                        editingTodo = nil
                    }
                )
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var generatingOverlay: some View {
        ZStack {
            Color(.windowBackgroundColor).opacity(reduceTransparency ? 1.0 : 0.7)

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .accessibilityHidden(true)
                Text("正在获取票据并生成待办...")
                    .font(.headline)
                    .foregroundStyle(Color(.labelColor))
                Text("请稍候")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabelColor))
            }
            .padding(32)
            .background(
                reduceTransparency
                    ? AnyShapeStyle(Color(.windowBackgroundColor))
                    : AnyShapeStyle(.regularMaterial),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .shadow(
                color: reduceTransparency ? .clear : Color(.shadowColor).opacity(0.2),
                radius: reduceTransparency ? 0 : 16,
                x: 0,
                y: reduceTransparency ? 0 : 8
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在生成待办清单，请稍候")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Todo Item Row
struct TodoItemRow: View {
    let item: TodoItem
    let isEditing: Bool
    @Binding var editingText: String
    let reduceMotion: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onStartEdit: () -> Void
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void

    @State private var isHovering = false

    /// 根据 Reduce Motion 设置选择动画
    private var standardAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                withAnimation(standardAnimation) {
                    onToggle()
                }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? Color(.systemGreen) : Color(.secondaryLabelColor))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            if isEditing {
                editingContent
            } else {
                normalContent
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title)，\(sourceDescription)")
        .accessibilityValue(item.isCompleted ? "已完成" : "未完成")
        .accessibilityHint("双击切换完成状态")
        .accessibilityAddTraits(item.isCompleted ? [.isSelected] : [])
    }
    
    private var sourceDescription: String {
        switch item.source {
        case .backlog:
            return "来自 \(item.issueKey ?? "")"
        case .calendar:
            return "来自日历"
        case .custom:
            return "自定义待办"
        }
    }

    private var editingContent: some View {
        HStack(spacing: 8) {
            TextField("编辑待办", text: $editingText, onCommit: onSaveEdit)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("编辑待办事项")

            Button("保存", action: onSaveEdit)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("保存修改")

            Button("取消", action: onCancelEdit)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("取消编辑")
        }
    }

    private var normalContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // First row: title + actions
            HStack(spacing: 8) {
                // Title
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? Color(.secondaryLabelColor) : Color(.labelColor))
                    .lineLimit(2)
                    .onTapGesture(count: 2) {
                        onStartEdit()
                    }

                Spacer()

                // Actions - always reserve space, control visibility with opacity
                HStack(spacing: 8) {
                    // Edit button
                    Button {
                        onStartEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(Color(.secondaryLabelColor))
                            .frame(minWidth: 28, minHeight: 28)
                    }
                    .buttonStyle(.plain)
                    .help("编辑待办")
                    .accessibilityLabel("编辑此待办事项")

                    // Open link button (only for Backlog todos)
                    if item.source == .backlog, let issueURL = item.issueURL, let url = URL(string: issueURL) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(Color(.secondaryLabelColor))
                                .frame(minWidth: 28, minHeight: 28)
                        }
                        .buttonStyle(.plain)
                        .help("在浏览器中打开")
                        .accessibilityLabel("在浏览器中打开")
                    }

                    // Delete button
                    Button {
                        withAnimation(standardAnimation) {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color(.systemRed).opacity(0.8))
                            .frame(minWidth: 28, minHeight: 28)
                    }
                    .buttonStyle(.plain)
                    .help("删除待办")
                    .accessibilityLabel("删除此待办事项")
                }
                .opacity(isHovering ? 1 : 0)
            }

            // Second row: issueKey + priority + dates OR calendar time + location
            HStack(alignment: .center, spacing: 8) {
                // Issue key/Calendar badge
                issueKeyBadge

                // Priority badge (Backlog only)
                if let priority = item.priority {
                    Text("优先级: \(priority)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(priorityTextColor(priority))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityBackgroundColor(priority), in: RoundedRectangle(cornerRadius: 4))
                }

                // Date info (Backlog)
                if item.source == .backlog {
                    if let startDate = item.startDate {
                        Text("开始: \(formatDate(startDate))")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabelColor))
                    }

                    if let dueDate = item.dueDate {
                        Text("截止: \(formatDate(dueDate))")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabelColor))
                    }
                }
                
                // Time and location info (Calendar)
                if item.source == .calendar {
                    if let startTime = item.eventStartTime, let endTime = item.eventEndTime {
                        Text("\(formatTime(startTime))-\(formatTime(endTime))")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabelColor))
                    }
                    
                    if let location = item.eventLocation, !location.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(location)
                                .font(.caption)
                        }
                        .foregroundStyle(Color(.secondaryLabelColor))
                    }
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var issueKeyBadge: some View {
        switch item.source {
        case .backlog:
            if let issueKey = item.issueKey, let issueURL = item.issueURL, let url = URL(string: issueURL) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tray.full.fill")
                            .font(.caption2)
                        Text(issueKey)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("在浏览器中打开票据")
                .accessibilityLabel("打开票据 \(issueKey)")
            }
        case .calendar:
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text("日历")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
        case .custom:
            HStack(spacing: 4) {
                Image(systemName: "square.and.pencil")
                    .font(.caption2)
                Text("自定义")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(Color(.secondaryLabelColor))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.separatorColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    // iOS-style priority text colors
    private func priorityTextColor(_ priority: String) -> Color {
        switch priority {
        case "高", "High":
            return Color(.systemRed)
        case "中", "Normal", "Medium":
            return Color(.secondaryLabelColor)
        case "低", "Low":
            return Color(.systemGreen)
        default:
            return Color(.secondaryLabelColor)
        }
    }

    // iOS-style priority background colors
    private func priorityBackgroundColor(_ priority: String) -> Color {
        switch priority {
        case "高", "High":
            return Color(.systemRed).opacity(0.1)
        case "中", "Normal", "Medium":
            return Color(.separatorColor).opacity(0.3)
        case "低", "Low":
            return Color(.systemGreen).opacity(0.1)
        default:
            return Color(.separatorColor).opacity(0.3)
        }
    }

    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO 8601 format first (e.g., "2025-12-30T00:00:00Z")
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Fallback to simple date format (e.g., "2025-12-30")
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        return simpleFormatter.date(from: dateString)
    }

    private func formatDate(_ dateString: String) -> String {
        guard let date = parseDate(dateString) else { return dateString }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MM/dd"
        return outputFormatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dueDateColor(_ dateString: String) -> Color {
        guard let dueDate = parseDate(dateString) else {
            return Color(.secondaryLabelColor)
        }

        let today = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: dueDate)

        if due < today {
            return Color(.systemRed) // Overdue
        } else if Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0 <= 3 {
            return Color(.systemOrange) // Due soon (within 3 days)
        } else {
            return Color(.secondaryLabelColor)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color(.tertiaryLabelColor))
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .foregroundStyle(Color(.secondaryLabelColor))

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color(.tertiaryLabelColor))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(subtitle)")
    }
}
