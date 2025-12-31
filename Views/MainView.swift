import SwiftUI
import AppKit

// MARK: - Main View
struct MainView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            detailView
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

    @ViewBuilder
    private var detailView: some View {
        switch viewModel.selectedDestination {
        case .todos:
            TodosDetailView(viewModel: viewModel)
        case .timeEntry:
            RedmineTimeEntryView(viewModel: viewModel)
        }
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Glance")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 32)
                .padding(.bottom, 24)

            Divider()
                .padding(.horizontal, 16)

            // Navigation List
            VStack(spacing: 4) {
                NavigationRow(
                    icon: "checklist",
                    title: "待办清单",
                    badge: viewModel.todoItems.isEmpty ? nil : "\(viewModel.todoItems.count)",
                    isSelected: viewModel.selectedDestination == .todos
                ) {
                    viewModel.selectedDestination = .todos
                }

                if viewModel.isRedmineConfigured {
                    NavigationRow(
                        icon: "clock.fill",
                        title: "Redmine 工时",
                        badge: viewModel.pendingTimeEntries.isEmpty ? nil : "\(viewModel.pendingTimeEntries.count)",
                        badgeColor: Color(.systemOrange),
                        isSelected: viewModel.selectedDestination == .timeEntry
                    ) {
                        viewModel.selectedDestination = .timeEntry
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)

            Spacer()

            // Footer
            sidebarFooter
        }
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
            // Use checkmark icon instead of plain circle for colorblind accessibility
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Color(.systemGreen))
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
    @State private var showingClearAllConfirmation = false
    @FocusState private var isNewTodoFocused: Bool

    private var standardAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3)
    }

    var body: some View {
        VStack(spacing: 0) {
            addTodoBar

            if viewModel.todoItems.isEmpty && newTodoText.isEmpty {
                emptyState
            } else {
                todosList
            }
        }
        .navigationTitle("待办清单")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await viewModel.fetchAndGenerateTodos()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isGeneratingTodos {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "sparkles")
                                .accessibilityHidden(true)
                        }
                        Text(viewModel.isGeneratingTodos ? "生成中..." : "同步")
                    }
                }
                .disabled(!viewModel.isConfigured || viewModel.isGeneratingTodos)
                .accessibilityLabel("同步票据")
                .accessibilityHint("从 Backlog 获取票据并使用 AI 生成待办清单")
                .help("同步票据并生成待办")
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showingClearAllConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .accessibilityHidden(true)
                }
                .disabled(viewModel.todoItems.isEmpty)
                .accessibilityLabel("清空所有待办")
                .accessibilityHint("删除所有待办事项")
                .help("清空所有待办")
            }
        }
        .confirmationDialog(
            "确定要清空所有待办吗？",
            isPresented: $showingClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空所有", role: .destructive) {
                withAnimation(standardAnimation) {
                    viewModel.clearAllTodos()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销")
        }
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
            subtitle: "点击右上角「同步」按钮获取票据"
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

    private var standardAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Checkbox
            Button {
                withAnimation(standardAnimation) {
                    onToggle()
                }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? Color(.systemGreen) : Color(.secondaryLabelColor))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 24)
            .accessibilityHidden(true)

            if isEditing {
                editingContent
            } else {
                normalContent
            }
        }
        .padding(.vertical, 8)
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
        VStack(alignment: .leading, spacing: 2) {
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
                HStack(spacing: 4) {
                    // Edit button
                    Button {
                        onStartEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(Color(.secondaryLabelColor))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
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
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
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
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
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

                // Due date (Backlog only)
                if item.source == .backlog, let dueDate = item.dueDate {
                    Text("截止: \(formatDate(dueDate))")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabelColor))
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
                    Text(issueKey)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("在浏览器中打开票据")
                .accessibilityLabel("打开票据 \(issueKey)")
            }
        case .calendar:
            Text("日历")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
        case .custom:
            Text("自定义")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color(.secondaryLabelColor))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.secondaryLabelColor).opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
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
        outputFormatter.dateFormat = "yyyy/MM/dd"
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
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color(.tertiaryLabelColor))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(subtitle)")
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Navigation Row
struct NavigationRow: View {
    let icon: String
    let title: String
    var badge: String? = nil
    var badgeColor: Color = Color(.systemBlue)
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.secondaryLabelColor))
                    .frame(width: 20)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.body)
                    .foregroundStyle(isSelected ? Color(.labelColor) : Color(.secondaryLabelColor))

                Spacer()

                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor, in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(badge.map { "\($0) 项" } ?? "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
