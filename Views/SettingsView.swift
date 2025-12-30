import SwiftUI

// MARK: - Settings Tab
enum SettingsTab: String, CaseIterable, Identifiable {
    case backlog = "Backlog"
    case calendar = "日历"
    case ai = "AI 模型"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .backlog: return "tray.full.fill"
        case .calendar: return "calendar"
        case .ai: return "cpu.fill"
        }
    }

    /// VoiceOver 描述
    var accessibilityLabel: String {
        switch self {
        case .backlog: return "Backlog 连接设置"
        case .calendar: return "日历同步设置"
        case .ai: return "AI 模型设置"
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
            }
            .padding(20)

            Divider()

            // Footer
            footerView
        }
        .frame(width: 520, height: 480)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("设置窗口")
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .foregroundStyle(Color(.secondaryLabelColor))
                .accessibilityHidden(true)
            Text("设置")
                .font(.headline)
                .foregroundStyle(Color(.labelColor))
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("设置")
        .accessibilityAddTraits(.isHeader)
    }

    private var footerView: some View {
        HStack {
            // Configuration status
            HStack(spacing: 8) {
                if viewModel.isConfigured {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(.systemGreen))
                        .accessibilityHidden(true)
                    Text("配置完成")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabelColor))
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color(.systemOrange))
                        .accessibilityHidden(true)
                    Text("请完成配置")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabelColor))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.isConfigured ? "配置状态：已完成" : "配置状态：请完成配置")

            Spacer()

            Button("完成") {
                dismiss()
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("完成设置")
            .accessibilityHint("关闭设置窗口")
        }
        .padding()
    }
}

// MARK: - Backlog Settings Tab
struct BacklogSettingsTab: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTesting = false
    @State private var testResult: Bool?

    /// 根据 Reduce Motion 设置选择动画
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
                    Image(systemName: "tray.full.fill")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
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
                HStack(spacing: 4) {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result ? Color(.systemGreen) : Color(.systemRed))
                        .accessibilityHidden(true)
                    Text(result ? "连接成功" : "连接失败")
                        .font(.caption)
                        .foregroundStyle(result ? Color(.systemGreen) : Color(.systemRed))
                }
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

    /// 根据 Reduce Motion 设置选择动画
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
                    SecureField("输入 DeepSeek API Key", text: $viewModel.openAIAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("DeepSeek API Key")
                        .accessibilityHint("输入你的 DeepSeek API 密钥")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                    TextField("https://api.deepseek.com", text: $viewModel.openAIBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("API Base URL")
                        .accessibilityHint("API 服务器地址")
                    Text("默认使用 DeepSeek 官方 API，可更换为兼容的 API")
                        .font(.caption)
                        .foregroundStyle(Color(.tertiaryLabelColor))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("模型选择")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabelColor))
                    Picker("", selection: $viewModel.selectedModel) {
                        ForEach(AppViewModel.availableModels, id: \.self) { model in
                            HStack {
                                modelIcon(for: model)
                                Text(modelDisplayName(model))
                            }
                            .tag(model)
                            .accessibilityLabel(modelDisplayName(model))
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .accessibilityLabel("选择 AI 模型")
                }
            } header: {
                HStack(spacing: 8) {
                    Image(systemName: "cpu.fill")
                        .foregroundStyle(Color(.systemPurple))
                        .accessibilityHidden(true)
                    Text("DeepSeek AI 配置")
                        .font(.headline)
                        .foregroundStyle(Color(.labelColor))
                }
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            } footer: {
                connectionTestButton
                    .padding(.top, 8)
            }
        }
        .formStyle(.grouped)
    }

    private func modelIcon(for model: String) -> some View {
        Group {
            switch model {
            case "deepseek-chat":
                Image(systemName: "bubble.left.fill")
                    .foregroundStyle(Color.accentColor)
            case "deepseek-reasoner":
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Color(.systemPurple))
            default:
                Image(systemName: "cpu")
                    .foregroundStyle(Color(.secondaryLabelColor))
            }
        }
        .accessibilityHidden(true)
    }

    private func modelDisplayName(_ model: String) -> String {
        switch model {
        case "deepseek-chat":
            return "DeepSeek Chat（快速）"
        case "deepseek-reasoner":
            return "DeepSeek Reasoner（推理增强）"
        default:
            return model
        }
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
            .accessibilityHint(isTesting ? "正在测试中" : "验证 DeepSeek API 配置是否正确")

            if let result = testResult {
                HStack(spacing: 4) {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result ? Color(.systemGreen) : Color(.systemRed))
                        .accessibilityHidden(true)
                    Text(result ? "连接成功" : "连接失败")
                        .font(.caption)
                        .foregroundStyle(result ? Color(.systemGreen) : Color(.systemRed))
                }
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
    @State private var availableCalendars: [String: String] = [:] // ID -> Name
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    /// 根据 Reduce Motion 设置选择动画
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
                    Image(systemName: "calendar")
                        .foregroundStyle(Color(.systemOrange))
                        .accessibilityHidden(true)
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
            let calendars = await service.fetchCalendars()
            await MainActor.run {
                availableCalendars = Dictionary(uniqueKeysWithValues: calendars.map { ($0.calendarIdentifier, $0.title) })
            }
        }
    }
}
