import AppKit
import SwiftUI

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
        List(selection: destinationSelection) {
            Section("工作区") {
                sidebarRow(
                    title: "待办清单",
                    systemImage: "checklist",
                    count: viewModel.todoItems.count
                )
                .tag(NavigationDestination.todos)

                if viewModel.isRedmineConfigured {
                    sidebarRow(
                        title: "Redmine 工时",
                        systemImage: "clock",
                        count: viewModel.pendingTimeEntries.count
                    )
                    .tag(NavigationDestination.timeEntry)
                }
            }

        }
        .listStyle(.sidebar)
        .navigationTitle("Glance")
        .tint(AppTheme.accent)
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                }
                .labelStyle(.iconOnly)
                .accessibilityHint("配置 Backlog、Redmine、AI 和邮件")
                .help("设置")
            }
        }
    }

    private var destinationSelection: Binding<NavigationDestination?> {
        Binding(
            get: { viewModel.selectedDestination },
            set: { destination in
                if let destination {
                    viewModel.selectedDestination = destination
                }
            }
        )
    }

    private func sidebarRow(title: String, systemImage: String, count: Int) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            if count > 0 {
                Text(count, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(count > 0 ? "\(title)，\(count) 项" : title)
    }

}

// MARK: - Todos Detail View
struct TodosDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editingTodo: TodoItem?
    @State private var editingText: String = ""
    @State private var newTodoText: String = ""
    @State private var showingClearAllConfirmation = false
    @State private var showingHoursInput = false
    @State private var todoToComplete: TodoItem?
    @State private var hoursInput: String = ""
    @FocusState private var isNewTodoFocused: Bool
    @FocusState private var isHoursInputFocused: Bool

    private var standardAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3)
    }

    private var hasCompletedTodos: Bool {
        viewModel.todoItems.contains { $0.isCompleted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                addTodoBar

                if viewModel.isGeneratingTodos || viewModel.isGeneratingTimeEntries {
                    operationStatus
                }

                if viewModel.todoItems.isEmpty && newTodoText.isEmpty {
                    emptyState
                } else {
                    todosList
                }
            }
            .padding(AppTheme.Spacing.large)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.background)
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
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .accessibilityHidden(true)
                        }
                        Text(viewModel.isGeneratingTodos ? "生成中..." : "同步")
                    }
                }
                .disabled(!viewModel.isConfigured || viewModel.isGeneratingTodos)
                .accessibilityLabel("同步票据")
                .accessibilityHint("从 Backlog 获取票据并更新待办清单")
                .help("从 Backlog 同步待办")
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

            // Generate time entries button
            if viewModel.isRedmineConfigured {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task {
                            await viewModel.generateTimeEntriesForCompletedTodos()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if viewModel.isGeneratingTimeEntries {
                                ProgressView()
                                    .controlSize(.small)
                                    .accessibilityHidden(true)
                            } else {
                                Image(systemName: "clock.badge.checkmark")
                                    .accessibilityHidden(true)
                            }
                            Text(viewModel.isGeneratingTimeEntries ? "生成中..." : "生成工时")
                        }
                    }
                    .disabled(
                        !hasCompletedTodos || viewModel.isGeneratingTimeEntries || viewModel.isGeneratingTodos
                    )
                    .accessibilityLabel("生成工时")
                    .accessibilityHint("根据已完成的待办自动生成 Redmine 工时记录")
                    .help("根据已完成的待办生成工时")
                }
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
        .sheet(isPresented: $showingHoursInput) {
            HoursInputSheet(
                todoTitle: todoToComplete?.title ?? "",
                hoursInput: $hoursInput,
                isHoursInputFocused: _isHoursInputFocused,
                onConfirm: {
                    if let todo = todoToComplete,
                        let hours = Double(hoursInput),
                        hours > 0
                    {
                        viewModel.completeTodoWithHours(todo, hours: hours)
                        showingHoursInput = false
                        hoursInput = ""
                        todoToComplete = nil
                    }
                },
                onCancel: {
                    showingHoursInput = false
                    hoursInput = ""
                    todoToComplete = nil
                }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("待办清单视图")
    }

    private var addTodoBar: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 30, height: 30)
                .background(AppTheme.accentSoft, in: Circle())
                .accessibilityHidden(true)

            TextField("写下下一件要做的事…", text: $newTodoText)
                .textFieldStyle(.plain)
                .font(AppTheme.FontStyle.body)
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
                        .font(AppTheme.FontStyle.subheading)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .accessibilityLabel("添加待办")
            }
        }
        .appCard()
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
            subtitle: "在上方输入新待办，或使用工具栏中的「同步」从 Backlog 获取票据"
        )
    }

    private var todosList: some View {
        LazyVStack(spacing: AppTheme.Spacing.small) {
            ForEach(viewModel.todoItems) { item in
                TodoItemRow(
                    item: item,
                    isEditing: editingTodo?.id == item.id,
                    editingText: $editingText,
                    reduceMotion: reduceMotion,
                    onToggle: {
                        if !item.isCompleted {
                            todoToComplete = item
                            hoursInput = ""
                            showingHoursInput = true
                        } else {
                            viewModel.toggleTodoCompletion(item)
                        }
                    },
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
    }

    private var operationStatus: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)

            Text(operationStatusText)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .background(AppTheme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(operationStatusText)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var operationStatusText: String {
        if viewModel.isGeneratingTodos {
            return "正在从 Backlog 同步待办"
        }
        return viewModel.generationProgress.isEmpty
            ? "正在生成工时记录"
            : viewModel.generationProgress
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

    private var standardAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3)
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
            Button {
                withAnimation(standardAnimation) {
                    onToggle()
                }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.isCompleted ? AppTheme.success : AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isCompleted ? "标记为未完成" : "完成待办")
            .accessibilityHint(item.isCompleted ? "恢复此待办" : "输入实际工时并完成此待办")

            if isEditing {
                editingContent
            } else {
                normalContent
            }
        }
        .padding(AppTheme.Spacing.medium)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                .stroke(AppTheme.divider.opacity(item.isCompleted ? 0.45 : 0.8), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
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
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            // First row: title + actions
            HStack(spacing: 8) {
                // Title
                Text(item.title)
                    .font(AppTheme.FontStyle.subheading)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .lineLimit(2)
                    .onTapGesture(count: 2) {
                        onStartEdit()
                    }

                Spacer()

                HStack(spacing: 4) {
                    // Edit button
                    Button {
                        onStartEdit()
                    } label: {
                            Image(systemName: "pencil")
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("编辑待办")
                    .accessibilityLabel("编辑 \(item.title)")

                    // Open link button (only for Backlog todos)
                    if item.source == .backlog, let issueURL = item.issueURL, let url = URL(string: issueURL) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("在浏览器中打开")
                        .accessibilityLabel("在浏览器中打开 \(item.issueKey ?? item.title)")
                    }

                    // Delete button
                    Button {
                        withAnimation(standardAnimation) {
                            onDelete()
                        }
                    } label: {
                            Image(systemName: "trash")
                            .foregroundStyle(AppTheme.danger)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("删除待办")
                    .accessibilityLabel("删除 \(item.title)")
                }
            }

            // Second row: issue key, priority, dates, and actual hours
                HStack(alignment: .center, spacing: AppTheme.Spacing.small) {
                // Issue key/source badge
                issueKeyBadge

                // Priority badge (Backlog only) with dot indicator
                if let priority = item.priority {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(priorityColor(priority))
                            .frame(width: 6, height: 6)

                        Text(priorityLabel(priority))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(priorityColor(priority))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(priorityColor(priority).opacity(0.12))
                    )
                }

                // Milestone badges (Backlog only)
                if let milestones = item.milestoneNames, !milestones.isEmpty {
                    ForEach(milestones, id: \.self) { milestone in
                        Text(milestone)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 4))
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AppTheme.divider, lineWidth: 1)
                            }
                    }
                }

                // Due date (Backlog only)
                if item.source == .backlog, let dueDate = item.dueDate {
                    Label(dueDateLabel(dueDate), systemImage: dueDateSystemImage(dueDate))
                        .font(.caption)
                        .foregroundStyle(dueDateColor(dueDate))
                }

                // Actual hours badge (if completed and has hours)
                if item.isCompleted, let hours = item.actualHours {
                    HStack(spacing: 2) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(String(format: "%.1fh", hours))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(AppTheme.success)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
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
                        .foregroundStyle(AppTheme.accentStrong)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("在浏览器中打开票据")
                .accessibilityLabel("打开票据 \(issueKey)")
            }
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

    // Priority color for unified styling
    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "高", "High":
            return AppTheme.danger
        case "中", "Normal", "Medium":
            return AppTheme.warning
        case "低", "Low":
            return AppTheme.success
        default:
            return Color(.secondaryLabelColor)
        }
    }

    // Priority label text
    private func priorityLabel(_ priority: String) -> String {
        switch priority {
        case "高", "High":
            return "高优先级"
        case "中", "Normal", "Medium":
            return "中优先级"
        case "低", "Low":
            return "低优先级"
        default:
            return priority
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
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func dueDateLabel(_ dateString: String) -> String {
        guard let dueDate = parseDate(dateString) else {
            return "截止：\(dateString)"
        }

        let today = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: dueDate)
        if due < today {
            return "已逾期 · \(formatDate(dateString))"
        }
        if Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0 <= 3 {
            return "即将截止 · \(formatDate(dateString))"
        }
        return "截止：\(formatDate(dateString))"
    }

    private func dueDateSystemImage(_ dateString: String) -> String {
        guard let dueDate = parseDate(dateString) else { return "calendar" }
        let today = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: dueDate)
        let remainingDays = Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0
        return due < today || remainingDays <= 3
            ? "calendar.badge.exclamationmark"
            : "calendar"
    }

    private func dueDateColor(_ dateString: String) -> Color {
        guard let dueDate = parseDate(dateString) else {
            return Color(.secondaryLabelColor)
        }

        let today = Calendar.current.startOfDay(for: Date())
        let due = Calendar.current.startOfDay(for: dueDate)

        if due < today {
            return Color(.systemRed)  // Overdue
        } else if Calendar.current.dateComponents([.day], from: today, to: due).day ?? 0 <= 3 {
            return Color(.systemOrange)  // Due soon (within 3 days)
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
        VStack(spacing: AppTheme.Spacing.large) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: 88, height: 88)

                Image(systemName: icon)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(AppTheme.accent)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(AppTheme.FontStyle.heading)
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(AppTheme.FontStyle.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.Spacing.xLarge)
        .appCard(padding: 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(subtitle)")
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Hours Input Sheet
struct HoursInputSheet: View {
    let todoTitle: String
    @Binding var hoursInput: String
    @FocusState var isHoursInputFocused: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            Text("输入完成工时")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(AppTheme.textPrimary)

            Text(todoTitle)
                .font(.body)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal)

            HStack(spacing: AppTheme.Spacing.small) {
                TextField("工时（小时）", text: $hoursInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .focused($isHoursInputFocused)
                    .onSubmit {
                        onConfirm()
                    }

                Text("小时")
                    .foregroundStyle(AppTheme.textSecondary)
            }

            HStack(spacing: AppTheme.Spacing.small) {
                Spacer()
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("确定") {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(hoursInput.isEmpty || Double(hoursInput) == nil || Double(hoursInput)! <= 0)
            }
        }
        .padding(AppTheme.Spacing.large)
        .frame(width: 400)
        .background(AppTheme.background)
        .onAppear {
            isHoursInputFocused = true
        }
    }
}
