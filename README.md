# Glance

A lightweight macOS productivity app that intelligently transforms Backlog issues and calendar events into actionable todo lists using AI.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 🎯 Smart Task Management
- **One-Click Sync**: Automatically fetch your assigned Backlog issues
- **Calendar Integration**: Sync events from WeChat Work, DingTalk, and other calendar apps
- **AI-Powered Sorting**: Intelligently prioritize tasks based on deadlines and importance
- **Persistent Storage**: Todos are saved locally and preserved across sessions

### 🔒 Privacy First
- All data stored locally on your Mac
- API keys securely stored in macOS Keychain
- No backend servers, no user accounts required

### 🤖 AI Integration
- **Multi-Model Support**: Works with all OpenAI-compatible APIs
- **Preset Models**: DeepSeek (deepseek-chat, deepseek-reasoner), Kimi (moonshot-v1-8k/32k/128k)
- **Custom Models**: Manually input any model name (gpt-4o, claude-3-5-sonnet, etc.)
- **Smart Matching**: Automatically match tasks to Redmine projects and activities
- **Default Model**: deepseek-chat (recommended for best performance and cost)

### 📅 Calendar Support
- Read events from multiple calendars
- Configurable look-ahead period (1-30 days)
- Automatic event-to-todo conversion
- Preserves completion status across syncs

## Screenshots

*Coming soon*

## Requirements

- macOS 13.0 or later
- Apple Silicon or Intel processor
- Active Backlog account with API access
- OpenAI-compatible API key (DeepSeek, OpenAI, etc.)

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
2. Enter your Backlog information:
   - **Backlog URL**: Your Backlog space URL (e.g., `https://your-space.backlog.jp/`)
   - **API Key**: Generate from Backlog → Personal Settings → API

### 2. Configure AI Service
1. In Settings, navigate to the AI Model section
2. Enter your API details:
   - **API Key**: Your AI service API key
   - **Base URL**: API endpoint (default: `https://api.deepseek.com`)
     - DeepSeek: `https://api.deepseek.com`
     - Kimi: `https://api.moonshot.cn/v1`
     - OpenAI: `https://api.openai.com/v1`
   - **Model**: Choose from preset models or enter custom model name
     - Preset: deepseek-chat, deepseek-reasoner, moonshot-v1-8k/32k/128k
     - Custom: gpt-4o, claude-3-5-sonnet, or any OpenAI-compatible model

Supports all OpenAI SDK compatible APIs. See [AI_MODELS.md](AI_MODELS.md) for details.

### 3. Enable Calendar (Optional)
1. In Settings, enable "Calendar Integration"
2. Grant calendar access when prompted
3. Select which calendars to sync
4. Set look-ahead period (default: 7 days)

## Usage

### Basic Workflow
1. **Fetch Issues**: Click the refresh button in the main view
2. **AI Processing**: The app automatically fetches Backlog issues and calendar events
3. **Smart Sorting**: AI analyzes and generates prioritized subtasks
4. **Get to Work**: Check off tasks as you complete them

### Task Management
- **Complete**: Click checkbox to mark as done
- **Edit**: Double-click task title to edit
- **Delete**: Right-click and select delete
- **Add Custom**: Use the "+" button to add manual tasks

### Todo Sources
Glance manages three types of todos:
- **📋 Backlog Tasks**: Generated from Backlog issues
- **📅 Calendar Events**: Synced from your calendars
- **✏️ Custom Tasks**: Manually added by you

## Project Structure

```
Glance/
├── GlanceApp.swift              # App entry point
├── Models/
│   ├── BacklogIssue.swift       # Backlog issue data model
│   ├── CalendarEvent.swift      # Calendar event data model
│   └── TodoItem.swift           # Todo item with source tracking
├── Services/
│   ├── AIService.swift          # AI integration (DeepSeek/OpenAI)
│   ├── BacklogService.swift    # Backlog API client
│   └── CalendarService.swift   # macOS Calendar integration
├── ViewModels/
│   └── AppViewModel.swift       # Main app state and logic
├── Views/
│   ├── MainView.swift           # Main todo list interface
│   └── SettingsView.swift       # Settings and configuration
└── Utils/
    └── KeychainHelper.swift     # Secure API key storage
```

## Architecture

### Data Flow
```
Backlog API ─┐
             ├─> BacklogService ──┐
Calendar    ─┤                    ├─> AppViewModel ─> Views
             └─> CalendarService ─┘       │
                                          │
                     AIService <──────────┘
                         │
                    DeepSeek API
```

### Key Components

- **AppViewModel**: Central state management and business logic
- **BacklogService**: Handles Backlog API communication
- **CalendarService**: Integrates with macOS EventKit
- **AIService**: Generates intelligent task breakdowns
- **KeychainHelper**: Secure credential storage

## Configuration Files

- **Info.plist**: Calendar permission descriptions
- **Glance.entitlements**: App sandbox and permissions
- **project.pbxproj**: Xcode project configuration

## API Integration

### Backlog API
- Fetches assigned issues with status filtering
- Supports custom Backlog space URLs
- Automatic retry and error handling

### AI Service (Multi-Model Support)
- **OpenAI-Compatible**: Works with any OpenAI SDK compatible API
- **Preset Models**: 5 commonly used models (DeepSeek, Kimi)
- **Custom Models**: Manually input any model name for flexibility
- **Default Model**: deepseek-chat (best performance/cost ratio)
- **Easy Switching**: Change models and endpoints without code modifications
- **Smart Matching**: Automatically match tasks to projects and activities

### Calendar (EventKit)
- Full calendar access on macOS 14+
- Multi-calendar support
- Configurable date range
- Preserves event metadata

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

### Calendar Not Syncing
- Grant calendar permissions in System Settings
- Go to: System Settings → Privacy & Security → Calendars
- Add Glance to allowed apps
- Restart the app after granting permissions

### AI Generation Fails
- Verify API key is correct
- Check API endpoint URL
- Ensure you have API credits/quota
- Review console logs for specific errors

## Roadmap

- [ ] Dark mode optimization
- [ ] Task time tracking
- [ ] Export functionality
- [ ] Keyboard shortcuts
- [ ] Task templates
- [ ] Multiple Backlog space support
- [ ] Notification system

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
- [DeepSeek](https://www.deepseek.com/) for powerful and cost-effective AI models
- [Moonshot AI](https://www.moonshot.cn/) for Kimi's excellent Chinese language support
- [OpenAI](https://openai.com/) for GPT models
- [Anthropic](https://www.anthropic.com/) for Claude models
- Apple's SwiftUI and EventKit frameworks

## Contact

- GitHub: [@FenWangSiCheng](https://github.com/FenWangSiCheng)
- Repository: [Glance](https://github.com/FenWangSiCheng/Glance)

---

Made with ❤️ for productive developers

