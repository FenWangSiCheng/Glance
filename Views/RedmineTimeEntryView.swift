import SwiftUI

struct RedmineTimeEntryView: View {
    @ObservedObject var viewModel: AppViewModel

    // Form state
    @State private var selectedDate = Date()
    @State private var selectedProject: RedmineProject?
    @State private var selectedIssue: RedmineIssue?
    @State private var selectedActivity: RedmineActivity?
    @State private var hours: String = ""
    @State private var comments: String = ""

    // Data state
    @State private var projects: [RedmineProject] = []
    @State private var issues: [RedmineIssue] = []
    @State private var activities: [RedmineActivity] = []

    // Loading state
    @State private var isLoadingProjects = false
    @State private var isLoadingIssues = false
    @State private var isLoadingActivities = false
    @State private var isSubmitting = false

    // Error state
    @State private var errorMessage: String?
    @State private var showingError = false

    // Submit result
    @State private var submitResult: (success: Int, failed: Int)?
    @State private var showingResult = false
    @State private var emailSendResult: EmailSendResult?
    @State private var submittedEntries: [PendingTimeEntry] = []

    // Confirmation dialogs
    @State private var showingClearConfirmation = false
    @State private var showingSubmitConfirmation = false
    
    // Editing state
    @State private var editingEntryId: UUID?
    @State private var editDate = Date()
    @State private var editProject: RedmineProject?
    @State private var editIssue: RedmineIssue?
    @State private var editActivity: RedmineActivity?
    @State private var editHours: String = ""
    @State private var editComments: String = ""
    @State private var editIssues: [RedmineIssue] = []
    @State private var isLoadingEditIssues = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var canAddEntry: Bool {
        selectedProject != nil &&
        selectedIssue != nil &&
        selectedActivity != nil &&
        !hours.isEmpty &&
        Double(hours) != nil &&
        !comments.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                formSection
                pendingListSection
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Redmine 工时")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSubmitConfirmation = true
                } label: {
                    HStack(spacing: 6) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .accessibilityHidden(true)
                        }
                        Text("提交全部")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.pendingTimeEntries.isEmpty || isSubmitting)
                .accessibilityLabel("提交全部工时")
                .accessibilityHint("提交所有待提交的工时记录到 Redmine")
            }
        }
        .onAppear {
            loadInitialData()
        }
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .alert("提交结果", isPresented: $showingResult) {
            Button("确定", role: .cancel) {}
        } message: {
            if let result = submitResult {
                if result.failed == 0 {
                    if let emailResult = emailSendResult {
                        if emailResult.success {
                            Text("成功提交 \(result.success) 条工时记录\n日报邮件已发送")
                        } else {
                            Text("成功提交 \(result.success) 条工时记录\n日报发送失败: \(emailResult.message ?? "未知错误")")
                        }
                    } else {
                        Text("成功提交 \(result.success) 条工时记录")
                    }
                } else {
                    Text("成功: \(result.success) 条，失败: \(result.failed) 条\n失败的记录已保留在列表中")
                }
            }
        }
        .confirmationDialog(
            "确定要清空所有工时记录吗？",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空所有", role: .destructive) {
                viewModel.clearPendingTimeEntries()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销")
        }
        .confirmationDialog(
            "确定要提交全部工时记录吗？",
            isPresented: $showingSubmitConfirmation,
            titleVisibility: .visible
        ) {
            Button("提交全部") {
                submitAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将提交 \(viewModel.pendingTimeEntries.count) 条工时记录到 Redmine")
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        Form {
            Section {
                // Date picker
                LabeledContent("日期") {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                }

                // Project picker
                LabeledContent("项目") {
                    if isLoadingProjects {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Picker("", selection: $selectedProject) {
                            Text("选择项目").tag(nil as RedmineProject?)
                            ForEach(projects) { project in
                                Text(project.name).tag(project as RedmineProject?)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: selectedProject) { _ in
                            selectedIssue = nil
                            issues = []
                            // Load issues for the selected project
                            if let project = selectedProject {
                                loadIssuesByProject(projectId: project.id)
                            }
                        }
                    }
                }

                // Issue picker (tracker is auto-matched from issue)
                LabeledContent("任务") {
                    if isLoadingIssues {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Picker("", selection: $selectedIssue) {
                            Text("选择任务").tag(nil as RedmineIssue?)
                            ForEach(issues) { issue in
                                Text(issue.displayTitle).tag(issue as RedmineIssue?)
                            }
                        }
                        .labelsHidden()
                        .disabled(selectedProject == nil)
                    }
                }

                // Activity picker
                LabeledContent("活动类型") {
                    if isLoadingActivities {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Picker("", selection: $selectedActivity) {
                            Text("选择活动类型").tag(nil as RedmineActivity?)
                            ForEach(activities) { activity in
                                Text(activity.name).tag(activity as RedmineActivity?)
                            }
                        }
                        .labelsHidden()
                    }
                }

                // Hours input
                LabeledContent("工时(h)") {
                    TextField("例如:2.5", text: $hours,)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        
                }

                // Comments input
                LabeledContent("描述") {
                    VStack(alignment: .trailing, spacing: 4) {
                        TextEditor(text: $comments)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(width: 200, height: 56)
                            .background(Color(.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(.separatorColor), lineWidth: 1)
                            )
                            .onChange(of: comments) { newValue in
                                if newValue.count > 20 {
                                    comments = String(newValue.prefix(20))
                                }
                            }
                            .accessibilityLabel("工时描述")
                            .accessibilityHint("输入工作内容描述，最多20字")
                        Text("\(comments.count)/20")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabelColor))
                    }
                }
            } footer: {
                HStack {
                    Spacer()
                    Button {
                        addToList()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .accessibilityHidden(true)
                            Text("添加到列表")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(!canAddEntry)
                    .accessibilityLabel("添加到列表")
                    .accessibilityHint("将当前工时记录添加到待提交列表")
                }
                .padding(.top, 8)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Pending List Section

    private var pendingListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("待提交列表 (\(viewModel.pendingTimeEntries.count)条)")
                    .font(.headline)
                    .foregroundStyle(Color(.labelColor))
                Spacer()
                if !viewModel.pendingTimeEntries.isEmpty {
                    Button {
                        showingClearConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .accessibilityHidden(true)
                            Text("清空")
                        }
                        .foregroundStyle(Color(.systemRed))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空列表")
                    .accessibilityHint("删除所有待提交的工时记录")
                }
            }

            if viewModel.pendingTimeEntries.isEmpty {
                Text("暂无待提交的工时记录")
                    .font(.subheadline)
                    .foregroundStyle(Color(.tertiaryLabelColor))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.pendingTimeEntries) { entry in
                        pendingEntryRow(entry)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func pendingEntryRow(_ entry: PendingTimeEntry) -> some View {
        VStack(spacing: 0) {
            if editingEntryId == entry.id {
                editingEntryView(entry)
            } else {
                displayEntryView(entry)
            }
        }
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(editingEntryId == entry.id ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    private func displayEntryView(_ entry: PendingTimeEntry) -> some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                Text("工时记录")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.secondaryLabelColor))
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        startEditing(entry)
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(Color.accentColor)
                            .frame(minWidth: 32, minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("编辑")
                    
                    Button {
                        viewModel.removePendingTimeEntry(id: entry.id)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color(.systemRed))
                            .frame(minWidth: 32, minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Content
            VStack(spacing: 10) {
                infoRow(label: "日期", value: entry.timeEntry.spentOn)
                infoRow(label: "项目", value: entry.projectName)
                infoRow(label: "任务", value: "#\(entry.issueId) \(entry.issueSubject)")
                infoRow(label: "活动类型", value: entry.activityName)
                infoRow(label: "工时(h)", value: entry.timeEntry.hours)
                infoRow(label: "描述", value: entry.timeEntry.comments)
            }
            .padding(12)
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabelColor))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color(.labelColor))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func editingEntryView(_ entry: PendingTimeEntry) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("编辑工时记录")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        cancelEditing()
                    } label: {
                        Text("取消")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabelColor))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        saveEditing(entry)
                    } label: {
                        Text("保存")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSaveEdit)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Editing form
            VStack(spacing: 12) {
                // Date
                HStack {
                    Text("日期")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                        .frame(width: 70, alignment: .leading)
                    DatePicker("", selection: $editDate, displayedComponents: .date)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Project
                HStack {
                    Text("项目")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                        .frame(width: 70, alignment: .leading)
                    Picker("", selection: $editProject) {
                        Text("选择项目").tag(nil as RedmineProject?)
                        ForEach(projects) { project in
                            Text(project.name).tag(project as RedmineProject?)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: editProject) { _ in
                        editIssue = nil
                        editIssues = []
                        // Load issues for the selected project
                        if let project = editProject {
                            loadEditIssuesByProject(projectId: project.id)
                        }
                    }
                }
                
                // Issue (tracker is auto-matched from issue)
                HStack {
                    Text("任务")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                        .frame(width: 70, alignment: .leading)
                    if isLoadingEditIssues {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Picker("", selection: $editIssue) {
                            Text("选择任务").tag(nil as RedmineIssue?)
                            ForEach(editIssues) { issue in
                                Text(issue.displayTitle).tag(issue as RedmineIssue?)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(editProject == nil)
                    }
                }
                
                // Activity
                HStack {
                    Text("活动类型")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                        .frame(width: 70, alignment: .leading)
                    Picker("", selection: $editActivity) {
                        Text("选择活动类型").tag(nil as RedmineActivity?)
                        ForEach(activities) { activity in
                            Text(activity.name).tag(activity as RedmineActivity?)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Hours
                HStack {
                    Text("工时(h)")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                        .frame(width: 70, alignment: .leading)
                    TextField("例如:2.5", text: $editHours)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Comments
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("描述")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabelColor))
                            .frame(width: 70, alignment: .leading)
                        Spacer()
                        Text("\(editComments.count)/20")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabelColor))
                    }
                    TextEditor(text: $editComments)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(height: 60)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(.separatorColor), lineWidth: 1)
                        )
                        .onChange(of: editComments) { newValue in
                            if newValue.count > 20 {
                                editComments = String(newValue.prefix(20))
                            }
                        }
                }
            }
            .padding(12)
        }
    }
    
    private var canSaveEdit: Bool {
        editProject != nil &&
        editIssue != nil &&
        editActivity != nil &&
        !editHours.isEmpty &&
        Double(editHours) != nil &&
        !editComments.isEmpty
    }
    
    private func startEditing(_ entry: PendingTimeEntry) {
        editingEntryId = entry.id
        
        // Parse date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        editDate = formatter.date(from: entry.timeEntry.spentOn) ?? Date()
        
        // Set project
        editProject = projects.first { $0.id == entry.timeEntry.projectId }
        
        // Set activity
        editActivity = activities.first { $0.id == entry.timeEntry.activityId }
        
        // Set hours and comments
        editHours = entry.timeEntry.hours
        editComments = entry.timeEntry.comments
        
        // Load issues for the project
        if let project = editProject {
            loadEditIssuesByProject(projectId: project.id)
            // Set issue after issues are loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                editIssue = editIssues.first { $0.id == entry.issueId }
            }
        }
    }
    
    private func cancelEditing() {
        editingEntryId = nil
        editDate = Date()
        editProject = nil
        editIssue = nil
        editActivity = nil
        editHours = ""
        editComments = ""
        editIssues = []
    }
    
    private func saveEditing(_ entry: PendingTimeEntry) {
        guard let project = editProject,
              let issue = editIssue,
              let activity = editActivity else {
            return
        }
        
        let updatedTimeEntry = RedmineTimeEntry(
            projectId: project.id,
            issueId: issue.id,
            activityId: activity.id,
            spentOn: dateFormatter.string(from: editDate),
            hours: editHours,
            comments: editComments
        )
        
        let updatedEntry = PendingTimeEntry(
            id: entry.id,
            timeEntry: updatedTimeEntry,
            projectName: project.name,
            issueSubject: issue.subject,
            issueId: issue.id,
            activityName: activity.name
        )
        
        viewModel.updatePendingTimeEntry(updatedEntry)
        cancelEditing()
    }
    
    private func loadEditIssuesByProject(projectId: Int) {
        isLoadingEditIssues = true
        
        Task {
            do {
                let fetchedIssues = try await viewModel.fetchRedmineIssues(projectId: projectId)
                await MainActor.run {
                    editIssues = fetchedIssues
                    isLoadingEditIssues = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoadingEditIssues = false
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() {
        // Use cached data if available
        if !viewModel.cachedRedmineProjects.isEmpty {
            projects = viewModel.cachedRedmineProjects
            activities = viewModel.cachedRedmineActivities
            return
        }
        
        isLoadingProjects = true
        isLoadingActivities = true

        Task {
            do {
                try await viewModel.loadRedmineInitialDataIfNeeded()
                
                await MainActor.run {
                    projects = viewModel.cachedRedmineProjects
                    activities = viewModel.cachedRedmineActivities
                    isLoadingProjects = false
                    isLoadingActivities = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoadingProjects = false
                    isLoadingActivities = false
                }
            }
        }
    }

    private func loadIssuesByProject(projectId: Int) {
        isLoadingIssues = true

        Task {
            do {
                let fetchedIssues = try await viewModel.fetchRedmineIssues(projectId: projectId)
                await MainActor.run {
                    issues = fetchedIssues
                    isLoadingIssues = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoadingIssues = false
                }
            }
        }
    }

    // MARK: - Actions

    private func addToList() {
        guard let project = selectedProject,
              let issue = selectedIssue,
              let activity = selectedActivity else {
            return
        }

        let timeEntry = RedmineTimeEntry(
            projectId: project.id,
            issueId: issue.id,
            activityId: activity.id,
            spentOn: dateFormatter.string(from: selectedDate),
            hours: hours,
            comments: comments
        )

        let pendingEntry = PendingTimeEntry(
            timeEntry: timeEntry,
            projectName: project.name,
            issueSubject: issue.subject,
            issueId: issue.id,
            activityName: activity.name
        )

        viewModel.addPendingTimeEntry(pendingEntry)

        // Reset form (keep project and activity selections)
        hours = ""
        comments = ""
        selectedIssue = nil
    }

    private func submitAll() {
        isSubmitting = true
        emailSendResult = nil

        // Save entries before submission for email report
        let entriesToSubmit = viewModel.pendingTimeEntries

        Task {
            let result = await viewModel.submitAllPendingTimeEntries()

            // If all succeeded and email is configured, send daily report
            var emailResult: EmailSendResult?
            if result.failed == 0 && result.success > 0 && viewModel.isEmailConfigured {
                emailResult = await viewModel.sendDailyReport(for: entriesToSubmit)
            }

            await MainActor.run {
                submitResult = result
                emailSendResult = emailResult
                submittedEntries = entriesToSubmit
                showingResult = true
                isSubmitting = false

                // Don't clear the list or navigate away after successful submission
            }
        }
    }
}
