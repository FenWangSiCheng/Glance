import SwiftUI

// MARK: - Settings Tab
enum SettingsTab: String, CaseIterable, Identifiable {
    case backlog = "Backlog"
    case calendar = "日历"
    case ai = "AI 模型"
    case redmine = "Redmine"
    case email = "邮件"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .backlog: return "tray.full.fill"
        case .calendar: return "calendar"
        case .ai: return "cpu.fill"
        case .redmine: return "clock.fill"
        case .email: return "envelope.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .backlog: return "Backlog 连接设置"
        case .calendar: return "日历同步设置"
        case .ai: return "AI 模型设置"
        case .redmine: return "Redmine 工时设置"
        case .email: return "邮件日报设置"
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .backlog

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            Divider()

            // Tab content
            TabView(selection: $selectedTab) {
                BacklogSettingsTab(viewModel: viewModel)
                    .tabItem {
                        Label("Backlog", systemImage: "tray.full.fill")
                    }
                    .tag(SettingsTab.backlog)
                    .accessibilityLabel(SettingsTab.backlog.accessibilityLabel)
                
                CalendarSettingsTab(viewModel: viewModel)
                    .tabItem {
                        Label("日历", systemImage: "calendar")
                    }
                    .tag(SettingsTab.calendar)
                    .accessibilityLabel(SettingsTab.calendar.accessibilityLabel)

                AISettingsTab(viewModel: viewModel)
                    .tabItem {
                        Label("AI 模型", systemImage: "cpu.fill")
                    }
                    .tag(SettingsTab.ai)
                    .accessibilityLabel(SettingsTab.ai.accessibilityLabel)

                RedmineSettingsTab(viewModel: viewModel)
                    .tabItem {
                        Label("Redmine", systemImage: "clock.fill")
                    }
                    .tag(SettingsTab.redmine)
                    .accessibilityLabel(SettingsTab.redmine.accessibilityLabel)

                EmailSettingsTab(viewModel: viewModel)
                    .tabItem {
                        Label("邮件", systemImage: "envelope.fill")
                    }
                    .tag(SettingsTab.email)
                    .accessibilityLabel(SettingsTab.email.accessibilityLabel)
            }
            .padding(20)

            Divider()

            // Footer
            footerView
        }
        .frame(width: 520, height: 480)
        .onExitCommand {
            dismiss()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("设置窗口")
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("设置")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(.labelColor))

                Text("配置应用连接和偏好")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabelColor))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.controlBackgroundColor))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("设置")
        .accessibilityAddTraits(.isHeader)
    }

    private var footerView: some View {
        HStack {
            // Configuration status with better design
            HStack(spacing: 8) {
                if viewModel.isConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.green)
                        .accessibilityHidden(true)
                    Text("配置完成")
                        .font(.subheadline)
                        .foregroundStyle(Color(.labelColor))
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.orange)
                        .accessibilityHidden(true)
                    Text("请完成配置")
                        .font(.subheadline)
                        .foregroundStyle(Color(.labelColor))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(viewModel.isConfigured ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.isConfigured ? "配置状态：已完成" : "配置状态：请完成配置")

            Spacer()

            Button("完成") {
                dismiss()
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel("完成设置")
            .accessibilityHint("关闭设置窗口")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Backlog Settings Tab
struct BacklogSettingsTab: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTesting = false
    @State private var testResult: Bool?

    private var standardAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backlog URL")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                    TextField("https://your-space.backlog.jp", text: $viewModel.backlogURL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Backlog URL")
                        .accessibilityHint("输入你的 Backlog 空间 URL")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                    SecureField("输入 Backlog API Key", text: $viewModel.backlogAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Backlog API Key")
                        .accessibilityHint("输入从 Backlog 获取的 API 密钥")
                }
            } header: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "tray.full.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.blue)
                        )

                    Text("Backlog 连接配置")
                        .font(.headline)
                        .foregroundStyle(Color(.labelColor))
                }
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            } footer: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("可在 Backlog 个人设置 → API 中生成 API Key")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabelColor))

                    connectionTestButton
                }
                .padding(.top, 8)
            }
        }
        .formStyle(.grouped)
    }

    private var connectionTestButton: some View {
        HStack(spacing: 12) {
            Button {
                testConnection()
            } label: {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "network")
                            .accessibilityHidden(true)
                    }
                    Text("测试连接")
                }
                .frame(minHeight: 32)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.backlogURL.isEmpty || viewModel.backlogAPIKey.isEmpty || isTesting)
            .accessibilityLabel("测试 Backlog 连接")
            .accessibilityHint(isTesting ? "正在测试中" : "验证 Backlog API 配置是否正确")

            if let result = testResult {
                HStack(spacing: 6) {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(result ? Color.green : Color.red)
                        .accessibilityHidden(true)
                    Text(result ? "连接成功" : "连接失败")
                        .font(.subheadline)
                        .foregroundStyle(result ? Color.green : Color.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(result ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                )
                .transition(.opacity.combined(with: .scale))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(result ? "连接测试成功" : "连接测试失败")
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let result = await viewModel.testBacklogConnection()
            await MainActor.run {
                withAnimation(standardAnimation) {
                    testResult = result
                }
                isTesting = false
            }
        }
    }
}

// MARK: - AI Settings Tab
struct AISettingsTab: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTesting = false
    @State private var testResult: Bool?
    @State private var customModel: String = ""
    @State private var isUsingCustomModel: Bool = false

    private var standardAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                    SecureField("输入 AI API Key", text: $viewModel.openAIAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("AI API Key")
                        .accessibilityHint("输入你的 AI 服务 API 密钥")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                    TextField("https://api.deepseek.com", text: $viewModel.openAIBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("API Base URL")
                        .accessibilityHint("API 服务器地址")
                    Text("支持所有兼容 OpenAI SDK 的 API")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabelColor))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("模型选择")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                    
                    Picker("", selection: Binding(
                        get: {
                            if AppViewModel.availableModels.contains(viewModel.selectedModel) {
                                return viewModel.selectedModel
                            } else {
                                return "custom"
                            }
                        },
                        set: { newValue in
                            if newValue == "custom" {
                                isUsingCustomModel = true
                                if !customModel.isEmpty {
                                    viewModel.selectedModel = customModel
                                }
                            } else {
                                isUsingCustomModel = false
                                viewModel.selectedModel = newValue
                            }
                        }
                    )) {
                        ForEach(AppViewModel.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                        Text("Custom...").tag("custom")
                    }
                    .pickerStyle(.radioGroup)
                    .accessibilityLabel("选择 AI 模型")
                    
                    if isUsingCustomModel || !AppViewModel.availableModels.contains(viewModel.selectedModel) {
                        TextField("输入自定义模型名", text: Binding(
                            get: {
                                if AppViewModel.availableModels.contains(viewModel.selectedModel) {
                                    return customModel
                                } else {
                                    return viewModel.selectedModel
                                }
                            },
                            set: { newValue in
                                customModel = newValue
                                if !newValue.isEmpty {
                                    viewModel.selectedModel = newValue
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("自定义模型名")
                    }
                }
            } header: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.blue)
                        )

                    Text("AI 模型配置")
                        .font(.headline)
                        .foregroundStyle(Color(.labelColor))
                }
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    connectionTestButton
                }
                .padding(.top, 8)
            }
        }
        .formStyle(.grouped)
    }

    private var connectionTestButton: some View {
        HStack(spacing: 12) {
            Button {
                testConnection()
            } label: {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "network")
                            .accessibilityHidden(true)
                    }
                    Text("测试连接")
                }
                .frame(minHeight: 32)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.openAIAPIKey.isEmpty || isTesting)
            .accessibilityLabel("测试 AI 连接")
            .accessibilityHint(isTesting ? "正在测试中" : "验证 AI API 配置是否正确")

            if let result = testResult {
                HStack(spacing: 6) {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(result ? Color.green : Color.red)
                        .accessibilityHidden(true)
                    Text(result ? "连接成功" : "连接失败")
                        .font(.subheadline)
                        .foregroundStyle(result ? Color.green : Color.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(result ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                )
                .transition(.opacity.combined(with: .scale))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(result ? "连接测试成功" : "连接测试失败")
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let result = await viewModel.testOpenAIConnection()
            await MainActor.run {
                withAnimation(standardAnimation) {
                    testResult = result
                }
                isTesting = false
            }
        }
    }
}

// MARK: - Calendar Settings Tab
struct CalendarSettingsTab: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var availableCalendars: [String: String] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var standardAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3)
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("启用日历同步", isOn: $viewModel.calendarEnabled)
                    .accessibilityLabel("启用日历同步")
                    .accessibilityHint("开启后将同步系统日历事件到待办列表")
                    .onChange(of: viewModel.calendarEnabled) { newValue in
                        if newValue && !viewModel.calendarAccessGranted {
                            Task {
                                await viewModel.requestCalendarAccess()
                                if viewModel.calendarAccessGranted {
                                    loadCalendars()
                                }
                            }
                        }
                    }
                
                if viewModel.calendarEnabled {
                    if viewModel.calendarAccessGranted {
                        // Calendar selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("选择日历")
                                .font(.subheadline)
                                .foregroundStyle(Color(.secondaryLabelColor))
                            
                            if availableCalendars.isEmpty {
                                Text("未找到可用日历")
                                    .font(.caption)
                                    .foregroundStyle(Color(.tertiaryLabelColor))
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(availableCalendars.keys.sorted()), id: \.self) { calendarId in
                                        Toggle(availableCalendars[calendarId] ?? calendarId, isOn: Binding(
                                            get: { viewModel.selectedCalendarIds.contains(calendarId) },
                                            set: { isSelected in
                                                if isSelected {
                                                    if !viewModel.selectedCalendarIds.contains(calendarId) {
                                                        viewModel.selectedCalendarIds.append(calendarId)
                                                    }
                                                } else {
                                                    viewModel.selectedCalendarIds.removeAll { $0 == calendarId }
                                                }
                                            }
                                        ))
                                        .accessibilityLabel("日历: \(availableCalendars[calendarId] ?? calendarId)")
                                    }
                                }
                            }
                            
                            Text("不选择任何日历将同步所有日历的今天事件")
                                .font(.caption)
                                .foregroundStyle(Color(.tertiaryLabelColor))
                        }
                    } else {
                        // Permission request
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color(.systemOrange))
                                    .accessibilityHidden(true)
                                Text("需要日历访问权限")
                                    .font(.subheadline)
                                    .foregroundStyle(Color(.labelColor))
                            }
                            
                            Text("Glance 需要访问您的日历以获取企业微信等应用同步的日程")
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabelColor))
                            
                            HStack(spacing: 12) {
                                Button {
                                    Task {
                                        await viewModel.requestCalendarAccess()
                                        if viewModel.calendarAccessGranted {
                                            loadCalendars()
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock.open.fill")
                                            .accessibilityHidden(true)
                                        Text("授权访问日历")
                                    }
                                    .frame(minHeight: 32)
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityLabel("授权访问日历")
                                .accessibilityHint("点击以请求日历访问权限")
                                
                                Button {
                                    viewModel.openSystemPrivacySettings()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "gearshape.fill")
                                            .accessibilityHidden(true)
                                        Text("打开系统设置")
                                    }
                                    .frame(minHeight: 32)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("打开系统设置")
                                .accessibilityHint("在系统设置中手动授予日历权限")
                            }
                        }
                    }
                }
            } header: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.orange)
                        )

                    Text("日历同步配置")
                        .font(.headline)
                        .foregroundStyle(Color(.labelColor))
                }
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("开启后，将从系统日历中读取事件并添加到待办列表")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabelColor))
                    
                    Text("适用于企业微信、钉钉等应用同步到 Mac 日历的会议")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabelColor))
                }
                .padding(.top, 8)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if viewModel.calendarEnabled && viewModel.calendarAccessGranted {
                loadCalendars()
            }
        }
    }
    
    private func loadCalendars() {
        Task {
            let service = CalendarService()
            let calendars = await service.fetchCalendarInfo()
            await MainActor.run {
                availableCalendars = Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0.title) })
            }
        }
    }
}

// MARK: - Redmine Settings Tab
struct RedmineSettingsTab: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTesting = false
    @State private var testResult: Bool?

    private var standardAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Redmine URL")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                    TextField("https://your-redmine.com/redmine", text: $viewModel.redmineURL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Redmine URL")
                        .accessibilityHint("输入 Redmine 服务器地址")
                        .onChange(of: viewModel.redmineURL) { _ in
                            viewModel.clearRedmineCache()
                        }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                    SecureField("输入 Redmine API Key", text: $viewModel.redmineAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Redmine API Key")
                        .accessibilityHint("输入从 Redmine 获取的 API 密钥")
                        .onChange(of: viewModel.redmineAPIKey) { _ in
                            viewModel.clearRedmineCache()
                        }
                }
            } header: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.cyan)
                        )

                    Text("Redmine 工时配置")
                        .font(.headline)
                        .foregroundStyle(Color(.labelColor))
                }
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            } footer: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("可在 Redmine 个人设置 → API 访问密钥中获取 API Key")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabelColor))

                    connectionTestButton
                }
                .padding(.top, 8)
            }
        }
        .formStyle(.grouped)
    }

    private var connectionTestButton: some View {
        HStack(spacing: 12) {
            Button {
                testConnection()
            } label: {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "network")
                            .accessibilityHidden(true)
                    }
                    Text("测试连接")
                }
                .frame(minHeight: 32)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.redmineURL.isEmpty || viewModel.redmineAPIKey.isEmpty || isTesting)
            .accessibilityLabel("测试 Redmine 连接")
            .accessibilityHint(isTesting ? "正在测试中" : "验证 Redmine API 配置是否正确")

            if let result = testResult {
                HStack(spacing: 6) {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(result ? Color.green : Color.red)
                        .accessibilityHidden(true)
                    Text(result ? "连接成功" : "连接失败")
                        .font(.subheadline)
                        .foregroundStyle(result ? Color.green : Color.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(result ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                )
                .transition(.opacity.combined(with: .scale))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(result ? "连接测试成功" : "连接测试失败")
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let result = await viewModel.testRedmineConnection()
            await MainActor.run {
                withAnimation(standardAnimation) {
                    testResult = result
                }
                isTesting = false
            }
        }
    }
}

// MARK: - Email Settings Tab
struct EmailSettingsTab: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTesting = false
    @State private var testResult: Bool?
    @State private var showAdvanced = false

    private var standardAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3)
    }

    var body: some View {
        Form {
            Section {
                Toggle("启用日报邮件", isOn: $viewModel.emailEnabled)
                    .accessibilityLabel("启用日报邮件")
                    .accessibilityHint("开启后，工时提交成功时自动发送日报邮件")

                if viewModel.emailEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("姓名")
                                .font(.subheadline)
                                .foregroundStyle(Color(.secondaryLabelColor))
                            Spacer()
                            if viewModel.redmineUser != nil {
                                Text("已从 Redmine 自动填充")
                                    .font(.caption)
                                    .foregroundStyle(Color(.systemGreen))
                            }
                        }
                        TextField("张三", text: $viewModel.emailUserName)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("姓名")
                            .accessibilityHint("用于日报邮件中的署名")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("发件人邮箱")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabelColor))
                        TextField("your-email@company.com", text: $viewModel.senderEmail)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("发件人邮箱")
                            .accessibilityHint("输入腾讯企业邮箱地址")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("客户端专用密码")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabelColor))
                        SecureField("输入客户端专用密码", text: $viewModel.emailPassword)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("客户端专用密码")
                            .accessibilityHint("在腾讯企业邮箱设置中生成的客户端专用密码")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("收件人邮箱")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabelColor))
                        TextField("recipient@company.com", text: $viewModel.recipientEmails)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("收件人邮箱")
                            .accessibilityHint("输入收件人邮箱，多个邮箱用逗号分隔")
                        Text("多个收件人请用逗号分隔")
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabelColor))
                    }

                    DisclosureGroup("高级设置", isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SMTP 服务器")
                                    .font(.subheadline)
                                    .foregroundStyle(Color(.secondaryLabelColor))
                                TextField("smtp.exmail.qq.com", text: $viewModel.smtpHost)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("SMTP 服务器地址")
                            }

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("端口")
                                        .font(.subheadline)
                                        .foregroundStyle(Color(.secondaryLabelColor))
                                    TextField("465", text: $viewModel.smtpPort)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .accessibilityLabel("SMTP 端口")
                                }

                                Toggle("使用 SSL", isOn: $viewModel.emailUseSSL)
                                    .accessibilityLabel("使用 SSL 加密")
                            }
                        }
                        .padding(.top, 8)
                    }
                    .accessibilityLabel("高级 SMTP 设置")
                }
            } header: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.blue)
                        )

                    Text("邮件日报配置")
                        .font(.headline)
                        .foregroundStyle(Color(.labelColor))
                }
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            } footer: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("工时提交成功后，自动发送日报到指定邮箱")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabelColor))

                    Text("客户端专用密码请在腾讯企业邮箱 → 设置 → 邮箱绑定 → 安全登录 中生成")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabelColor))

                    if viewModel.emailEnabled {
                        connectionTestButton
                    }
                }
                .padding(.top, 8)
            }
        }
        .formStyle(.grouped)
    }

    private var connectionTestButton: some View {
        HStack(spacing: 12) {
            Button {
                testConnection()
            } label: {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "network")
                            .accessibilityHidden(true)
                    }
                    Text("测试连接")
                }
                .frame(minHeight: 32)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.senderEmail.isEmpty || viewModel.emailPassword.isEmpty || isTesting)
            .accessibilityLabel("测试邮件连接")
            .accessibilityHint(isTesting ? "正在测试中" : "验证 SMTP 配置是否正确")

            if let result = testResult {
                HStack(spacing: 6) {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(result ? Color.green : Color.red)
                        .accessibilityHidden(true)
                    Text(result ? "连接成功" : "连接失败")
                        .font(.subheadline)
                        .foregroundStyle(result ? Color.green : Color.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(result ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                )
                .transition(.opacity.combined(with: .scale))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(result ? "连接测试成功" : "连接测试失败")
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let result = await viewModel.testEmailConnection()
            await MainActor.run {
                withAnimation(standardAnimation) {
                    testResult = result
                }
                isTesting = false
            }
        }
    }
}
