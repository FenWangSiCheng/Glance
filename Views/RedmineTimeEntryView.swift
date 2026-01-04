import SwiftUI

struct RedmineTimeEntryView: View {
    @ObservedObject var viewModel: AppViewModel

    // Form state
    @State private var selectedDate = Date()
    @State private var selectedProject: RedmineProject?
    @State private var selectedTracker: RedmineTracker?
    @State private var selectedIssue: RedmineIssue?
    @State private var selectedActivity: RedmineActivity?
    @State private var hours: String = ""
    @State private var comments: String = ""

    // Data state
    @State private var projects: [RedmineProject] = []
    @State private var trackers: [RedmineTracker] = []
    @State private var issues: [RedmineIssue] = []
    @State private var activities: [RedmineActivity] = []

    // Loading state
    @State private var isLoadingProjects = false
    @State private var isLoadingTrackers = false
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

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var canAddEntry: Bool {
        selectedProject != nil &&
        selectedTracker != nil &&
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
                    submitAll()
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
                            selectedTracker = nil
                            selectedIssue = nil
                            issues = []
                        }
                    }
                }

                // Tracker picker
                LabeledContent("跟踪器") {
                    if isLoadingTrackers {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Picker("", selection: $selectedTracker) {
                            Text("选择跟踪器").tag(nil as RedmineTracker?)
                            ForEach(trackers) { tracker in
                                Text(tracker.name).tag(tracker as RedmineTracker?)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: selectedTracker) { _ in
                            selectedIssue = nil
                            issues = []
                            if let project = selectedProject, let tracker = selectedTracker {
                                loadIssues(projectId: project.id, trackerId: tracker.id)
                            }
                        }
                    }
                }

                // Issue picker
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
                        .disabled(selectedTracker == nil)
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
                        viewModel.clearPendingTimeEntries()
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
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.displaySummary)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(.labelColor))
                Text(entry.issueSubject)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabelColor))
                    .lineLimit(1)
                Text(entry.timeEntry.comments)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabelColor))
                    .lineLimit(2)
            }
            Spacer()
            Button {
                viewModel.removePendingTimeEntry(id: entry.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Color(.systemRed))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除")
            .accessibilityHint("删除此工时记录")
        }
        .padding(12)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Data Loading

    private func loadInitialData() {
        // Use cached data if available
        if !viewModel.cachedRedmineProjects.isEmpty {
            projects = viewModel.cachedRedmineProjects
            trackers = viewModel.cachedRedmineTrackers
            activities = viewModel.cachedRedmineActivities
            return
        }
        
        isLoadingProjects = true
        isLoadingTrackers = true
        isLoadingActivities = true

        Task {
            do {
                try await viewModel.loadRedmineInitialDataIfNeeded()
                
                await MainActor.run {
                    projects = viewModel.cachedRedmineProjects
                    trackers = viewModel.cachedRedmineTrackers
                    activities = viewModel.cachedRedmineActivities
                    isLoadingProjects = false
                    isLoadingTrackers = false
                    isLoadingActivities = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLoadingProjects = false
                    isLoadingTrackers = false
                    isLoadingActivities = false
                }
            }
        }
    }

    private func loadIssues(projectId: Int, trackerId: Int) {
        isLoadingIssues = true

        Task {
            do {
                let fetchedIssues = try await viewModel.fetchRedmineIssues(projectId: projectId, trackerId: trackerId)
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

        // Reset form (keep project, tracker, activity selections)
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

                if result.failed == 0 && result.success > 0 {
                    // All submitted successfully, navigate back to todos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        viewModel.selectedDestination = .todos
                    }
                }
            }
        }
    }
}
