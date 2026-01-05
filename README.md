# Glance

A lightweight macOS productivity app that intelligently transforms Backlog issues and calendar events into actionable todo lists using AI, with built-in Redmine time tracking integration.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 🎯 Smart Task Management
- **One-Click Sync**: Automatically fetch your assigned Backlog issues
- **Calendar Integration**: Sync events from WeChat Work, DingTalk, and other calendar apps
- **AI-Powered Generation**: Intelligently prioritize tasks based on deadlines and importance
- **Persistent Storage**: Todos are saved locally and preserved across sessions
- **Hours Tracking**: Record actual hours spent on each completed todo

### 🔒 Privacy First
- All data stored locally on your Mac
- API keys securely stored in macOS Keychain
- No backend servers, no user accounts required

### 🤖 AI Integration
- **Multi-Model Support**: Works with all OpenAI-compatible APIs
- **Preset Models**: DeepSeek (deepseek-chat, deepseek-reasoner), Kimi (moonshot-v1-8k/32k/128k)
- **Custom Models**: Manually input any model name (gpt-4o, claude-3-5-sonnet, etc.)
- **Smart Matching**: Automatically match tasks to Redmine projects and activities
- **Intelligent Comments**: AI generates appropriate work descriptions for time entries
- **Default Model**: deepseek-chat (recommended for best performance and cost)

### ⏱️ Redmine Integration
- **Auto Time Entry**: Generate Redmine time entries from completed todos
- **Smart Project Matching**: AI automatically matches tasks to correct Redmine projects
- **Activity Detection**: Intelligently infer activity types (development, testing, meeting, etc.)
- **Bulk Operations**: Submit multiple time entries at once
- **Issue Linking**: Optional linking to specific Redmine issues

### 📅 Calendar Support
- Read events from multiple calendars
- Configurable look-ahead period (1-30 days)
- Automatic event-to-todo conversion
- Preserves completion status across syncs

### 📧 Email Reporting
- **Work Summary**: Send daily work reports via email
- **SMTP Support**: Native SMTP integration with SSL/TLS
- **Rich Formatting**: HTML email support with professional templates
- **Configurable**: Set up sender name, recipients, and email content

## Screenshots

*Coming soon*

## Requirements

- macOS 13.0 or later
- Apple Silicon or Intel processor
- Active Backlog account with API access
- OpenAI-compatible API key (DeepSeek, OpenAI, Kimi, etc.)
- (Optional) Redmine account with API access for time tracking
- (Optional) SMTP email account for work reports

## Installation

### Option 1: Download Release (Recommended)
1. Download the latest `.dmg` from [Releases](https://github.com/FenWangSiCheng/Glance/releases)
2. Open the `.dmg` file
3. Drag Glance to your Applications folder
4. Launch Glance from Applications

### Option 2: Build from Source
1. Clone the repository:
```bash
git clone git@github.com:FenWangSiCheng/Glance.git
cd Glance
```

2. Open `Glance.xcodeproj` in Xcode

3. Build and run (⌘+R)

## Setup

### 1. Configure Backlog
1. Open Settings (⚙️ icon in the toolbar)
2. Navigate to the **Backlog** tab
3. Enter your Backlog information:
   - **Backlog URL**: Your Backlog space URL (e.g., `https://your-space.backlog.jp/`)
   - **API Key**: Generate from Backlog → Personal Settings → API
4. Click **Test Connection** to verify
5. Save your settings

### 2. Configure AI Service
1. In Settings, navigate to the **AI Model** tab
2. Enter your API details:
   - **API Key**: Your AI service API key
   - **Base URL**: API endpoint (default: `https://api.deepseek.com`)
     - DeepSeek: `https://api.deepseek.com`
     - Kimi: `https://api.moonshot.cn/v1`
     - OpenAI: `https://api.openai.com/v1`
   - **Model**: Choose from preset models or enter custom model name
     - Preset: deepseek-chat, deepseek-reasoner, moonshot-v1-8k/32k/128k
     - Custom: gpt-4o, claude-3-5-sonnet, or any OpenAI-compatible model
3. Click **Test Connection** to verify
4. Save your settings

Supports all OpenAI SDK compatible APIs.

### 3. Configure Redmine (Optional)
1. In Settings, navigate to the **Redmine** tab
2. Enter your Redmine information:
   - **Redmine URL**: Your Redmine server URL (e.g., `https://redmine.example.com`)
   - **API Key**: Generate from Redmine → My Account → API access key
3. Click **Test Connection** to verify
4. Save your settings

With Redmine configured, you can:
- Generate time entries from completed todos
- Auto-match tasks to Redmine projects and issues
- Bulk submit time entries

### 4. Configure Email (Optional)
1. In Settings, navigate to the **Email** tab
2. Enter your SMTP configuration:
   - **SMTP Server**: Your mail server (e.g., `smtp.gmail.com`)
   - **Port**: SMTP port (default: 465 for SSL)
   - **Email Address**: Your email address
   - **Password**: App-specific password (for Gmail, generate from Google Account settings)
   - **Sender Name**: Display name for sent emails
   - **Use SSL**: Enable for secure connection (recommended)
3. Click **Test Connection** to verify
4. Save your settings

With Email configured, you can send daily work summaries directly from the app.

### 5. Enable Calendar (Optional)
1. In Settings, navigate to the **Calendar** tab
2. Enable "Calendar Integration"
3. Grant calendar access when prompted by macOS
4. Select which calendars to sync
5. Set look-ahead period (default: 7 days)
6. Save your settings

## Usage

### Basic Workflow
1. **Sync Tasks**: Click the "同步" (Sync) button in the toolbar
2. **AI Processing**: The app automatically fetches Backlog issues and calendar events
3. **Review Todos**: Check the generated todo list in the main view
4. **Track Hours**: When completing a todo, enter actual hours spent
5. **Generate Time Entries**: Click "生成工时" (Generate Time Entries) to create Redmine time entries
6. **Submit to Redmine**: Review and submit time entries from the Redmine Time Entry view

### Task Management

#### Adding and Editing Todos
- **Add New Todo**: Type in the input field at the top and press Enter
- **Complete Todo**: Click the checkbox (you'll be prompted to enter hours)
- **Edit Todo**: Double-click the task title or click the pencil icon
- **Delete Todo**: Click the trash icon when hovering over a task
- **Open in Browser**: Click the issue key badge or the open link icon (Backlog todos only)

#### Todo Sources
Glance manages three types of todos:
- **📋 Backlog Tasks**: Generated from Backlog issues with issue key, priority, and due date
- **📅 Calendar Events**: Synced from your calendars with time and location
- **✏️ Custom Tasks**: Manually added by you

### Redmine Time Entry Workflow

1. **Complete Todos**: Mark todos as done and enter actual hours spent
2. **Generate Time Entries**: Click "生成工时" button in the toolbar
   - AI automatically matches todos to Redmine projects
   - AI infers appropriate activity types (development, testing, meeting, etc.)
   - AI generates work descriptions based on todo content
3. **Review Entries**: Switch to "Redmine 工时" view in the sidebar
   - Review auto-matched projects and activities
   - Edit project, activity, or comments if needed
   - Optionally link to specific Redmine issues
   - Adjust spent hours if needed
4. **Submit**: Click "提交工时" to submit selected time entries to Redmine
5. **Send Report** (Optional): Click "发送邮件报告" to email a summary of your work

### Email Reporting

After submitting time entries to Redmine, you can send a work summary via email:
1. Ensure Email is configured in Settings
2. Click "发送邮件报告" in the Redmine Time Entry view
3. The app will send an HTML-formatted email with:
   - Summary of completed tasks
   - Total hours spent
   - Breakdown by project
   - Individual time entries with descriptions

## Project Structure

```
Glance/
├── GlanceApp.swift                   # App entry point
├── Models/
│   ├── BacklogIssue.swift            # Backlog issue data model
│   ├── CalendarEvent.swift           # Calendar event data model
│   ├── TodoItem.swift                # Todo item with source tracking and hours
│   ├── RedmineModels.swift           # Redmine project, issue, activity, time entry models
│   └── EmailModels.swift             # Email configuration models
├── Services/
│   ├── AIService.swift               # AI integration with project/issue matching
│   ├── BacklogService.swift          # Backlog API client
│   ├── CalendarService.swift         # macOS Calendar integration
│   ├── RedmineService.swift          # Redmine API client with time entry submission
│   └── EmailService.swift            # Native SMTP email service
├── ViewModels/
│   └── AppViewModel.swift            # Main app state and business logic
├── Views/
│   ├── MainView.swift                # Main todo list interface with hours input
│   ├── RedmineTimeEntryView.swift    # Redmine time entry management
│   └── SettingsView.swift            # Multi-tab settings (Backlog, AI, Redmine, Email, Calendar)
└── Utils/
    └── KeychainHelper.swift          # Secure API key storage
```

## Architecture

### Data Flow
```
Backlog API ─┐
             ├─> BacklogService ──┐
Calendar    ─┤                    │
             └─> CalendarService ─┤
                                  │
                                  ├─> AppViewModel ─> Views (MainView, RedmineTimeEntryView)
                                  │        │
Redmine API <────────────────────┤        │
         │                        │        │
         └─> RedmineService       │        │
                                  │        │
                     AIService <──┴────────┘
                         │
                    AI API (DeepSeek/OpenAI/etc.)
                         │
                         └─> Project/Issue Matching
                         └─> Activity Inference
                         └─> Work Description Generation
```

### Key Components

- **AppViewModel**: Central state management and business logic
  - Todo lifecycle management
  - Time entry generation workflow
  - Integration coordination between services
- **BacklogService**: Handles Backlog API communication
  - Fetch assigned issues
  - Issue metadata retrieval
- **CalendarService**: Integrates with macOS EventKit
  - Read calendar events
  - Multi-calendar support
- **RedmineService**: Redmine API client
  - Fetch projects, issues, and activities
  - Submit time entries
  - Batch operations support
- **AIService**: Intelligent automation powered by OpenAI-compatible APIs
  - Match todos to Redmine projects based on issue keys and milestones
  - Infer activity types from todo content
  - Generate appropriate work descriptions
  - Match todos to specific Redmine issues
- **EmailService**: Native SMTP implementation
  - Send work summary emails
  - HTML email formatting
  - SSL/TLS support
- **KeychainHelper**: Secure credential storage

## Configuration Files

- **Info.plist**: Calendar permission descriptions
- **Glance.entitlements**: App sandbox and permissions
- **project.pbxproj**: Xcode project configuration

## API Integration

### Backlog API
- **Features**:
  - Fetch assigned issues with status filtering
  - Support for custom Backlog space URLs
  - Automatic retry and error handling
  - Issue metadata extraction (key, priority, milestones, due date)
- **Authentication**: API Key-based
- **Endpoints Used**:
  - `/api/v2/users/myself` - Get current user info
  - `/api/v2/issues` - Fetch issues

### AI Service (Multi-Model Support)
- **OpenAI-Compatible**: Works with any OpenAI SDK compatible API
- **Preset Models**: 
  - DeepSeek: deepseek-chat, deepseek-reasoner
  - Kimi: moonshot-v1-8k, moonshot-v1-32k, moonshot-v1-128k
- **Custom Models**: Manually input any model name (gpt-4o, claude-3-5-sonnet, etc.)
- **Default Model**: deepseek-chat (best performance/cost ratio)
- **Easy Switching**: Change models and endpoints without code modifications
- **Smart Features**:
  - **Project Matching**: Analyzes issue keys and milestones to match correct Redmine projects
  - **Activity Inference**: Determines activity type from todo content (development, testing, meeting, learning, etc.)
  - **Work Description**: Generates concise, professional work descriptions
  - **Issue Linking**: Matches todos to specific Redmine issues when applicable
- **Intelligent Fallback**: Uses default project (非生産) and activity (内部-学習) when unable to match

### Redmine API
- **Features**:
  - Fetch all active projects with pagination
  - Fetch project issues
  - Fetch time entry activities
  - Submit time entries with batch support
  - Connection testing
- **Authentication**: API Key via X-Redmine-API-Key header
- **Endpoints Used**:
  - `/users/current.json` - Verify connection
  - `/projects.json` - List projects
  - `/issues.json` - List project issues
  - `/enumerations/time_entry_activities.json` - List activities
  - `/time_entries.json` - Submit time entries

### Email (SMTP)
- **Features**:
  - Native SMTP implementation using Network framework
  - SSL/TLS support
  - AUTH LOGIN authentication
  - HTML and plain text email support
  - UTF-8 subject and body encoding
  - Connection testing
- **Supported Providers**: Gmail, Outlook, custom SMTP servers
- **Default Ports**: 465 (SSL), 587 (TLS)

### Calendar (EventKit)
- **Features**:
  - Full calendar access on macOS 14+
  - Multi-calendar support
  - Configurable date range (1-30 days)
  - Event metadata preservation (time, location)
  - All-day event support
- **Permissions**: Requires calendar access permission from user

## Tips and Best Practices

### For Accurate Time Tracking
1. **Complete todos promptly**: Mark tasks as done right after completion while hours are fresh in mind
2. **Be honest with hours**: Enter actual hours spent, not estimated time
3. **Break down large tasks**: Split big tasks into smaller todos for more accurate tracking
4. **Review before submission**: Double-check generated time entries before submitting to Redmine

### For Better AI Matching
1. **Use clear issue keys**: Ensure Backlog issues have proper project prefixes (e.g., `PROJ-123`)
2. **Add milestones**: Include milestone information in Backlog issues for better project matching
3. **Write descriptive titles**: Clear todo titles help AI generate better work descriptions
4. **Add context**: Use todo descriptions for additional context when needed

### For Email Reports
1. **Gmail users**: Generate an App-specific password from Google Account settings
2. **Outlook users**: Use regular password with `smtp-mail.outlook.com` on port 587
3. **Test first**: Always test connection before relying on email reports
4. **Schedule wisely**: Send reports at end of day for daily summaries

### Workflow Optimization
1. **Morning routine**: Sync todos at start of day to see all your tasks
2. **Throughout the day**: Complete todos and track hours as you work
3. **End of day**: Generate and submit time entries to Redmine
4. **Send report**: Email work summary to team or manager
5. **Next day**: Sync again for new issues and calendar events

## Development

### Prerequisites
- Xcode 15.0 or later
- Swift 5.9 or later
- macOS 13.0 SDK

### Building
```bash
# Open in Xcode
open Glance.xcodeproj

# Or build from command line
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release
```

### Testing
- Unit tests: Coming soon
- Integration tests: Coming soon

## Privacy & Security

- **Local Storage**: All todos and settings stored on your Mac
- **Keychain**: API keys encrypted in macOS Keychain
- **No Tracking**: No analytics, no telemetry
- **Sandbox**: App runs in macOS sandbox for security

## Troubleshooting

### Backlog Connection Issues
- Verify your Backlog URL format (include `https://`)
- Check API key validity in Backlog settings
- Ensure you have active issues assigned to you
- Use the "Test Connection" button in Settings to verify

### Redmine Connection Issues
- Verify your Redmine URL format (include `https://`)
- Check API key validity in Redmine account settings
- Ensure your account has permissions to:
  - View projects
  - View issues
  - Log time entries
- Use the "Test Connection" button in Settings to verify

### Calendar Not Syncing
- Grant calendar permissions in System Settings
- Go to: System Settings → Privacy & Security → Calendars
- Add Glance to allowed apps
- Restart the app after granting permissions
- Ensure selected calendars have events in the configured date range

### AI Generation Fails
- Verify API key is correct
- Check API endpoint URL (include full URL with protocol)
- Ensure you have API credits/quota remaining
- Try a different model if current one is unavailable
- Use the "Test Connection" button to verify AI service
- Review console logs for specific errors

### Time Entry Generation Issues
- Ensure Redmine is properly configured
- Check that completed todos have valid hours recorded
- Verify that Redmine projects and activities are accessible
- AI matching requires valid Backlog issue keys (e.g., PROJ-123) for best results
- If project matching fails, entries will use default project (非生産)

### Email Sending Fails
- Verify SMTP server and port settings
- For Gmail:
  - Enable 2-factor authentication
  - Generate an App-specific password
  - Use `smtp.gmail.com` port `465` with SSL
- For Outlook:
  - Use `smtp-mail.outlook.com` port `587` with TLS
- Check firewall settings
- Use the "Test Connection" button to verify
- Review error messages for authentication or connection issues

## Roadmap

### Completed ✅
- [x] Basic todo management
- [x] Backlog integration
- [x] Calendar integration
- [x] AI-powered todo generation
- [x] Redmine integration with time tracking
- [x] AI-powered project and activity matching
- [x] Email reporting with SMTP
- [x] Hours tracking for completed todos
- [x] Batch time entry submission

### Planned 🚧
- [ ] Dark mode optimization
- [ ] Export functionality (CSV, Markdown)
- [ ] Keyboard shortcuts
- [ ] Task templates
- [ ] Multiple Backlog space support
- [ ] Notification system
- [ ] Time entry editing after submission
- [ ] Advanced filtering and search
- [ ] Statistics and analytics dashboard
- [ ] Custom AI prompts
- [ ] Webhook support for real-time updates

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Backlog](https://backlog.com/) for their excellent project management platform
- [Redmine](https://www.redmine.org/) for the open-source project management system
- [DeepSeek](https://www.deepseek.com/) for powerful and cost-effective AI models
- [Moonshot AI](https://www.moonshot.cn/) for Kimi's excellent Chinese language support
- [OpenAI](https://openai.com/) for GPT models and the OpenAI API standard
- [Anthropic](https://www.anthropic.com/) for Claude models
- Apple's SwiftUI, EventKit, and Network frameworks

## Contact

- GitHub: [@FenWangSiCheng](https://github.com/FenWangSiCheng)
- Repository: [Glance](https://github.com/FenWangSiCheng/Glance)

---

Made with ❤️ for productive developers

