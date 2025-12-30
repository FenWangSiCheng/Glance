# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run

This is a native macOS SwiftUI application. Open `Glance.xcodeproj` in Xcode to build and run.

- **Build**: Cmd+B in Xcode, or `xcodebuild -project Glance.xcodeproj -scheme Glance build`
- **Run**: Cmd+R in Xcode
- **Target**: macOS 13.0+, supports both Apple Silicon and Intel

## Architecture

Glance is a lightweight Mac app that fetches Backlog issues and uses AI (DeepSeek) to generate prioritized todo lists.

### Data Flow

```
User clicks "获取票据并生成待办"
    → AppViewModel.fetchAndGenerateTodos()
        → BacklogService.fetchMyIssues() - fetches issues assigned to current user
        → AIService.generateTodoList() - AI sorts issues by priority/dates
        → mergeTodoItems() - preserves custom todos and completion states
```

### Key Components

- **AppViewModel** (`ViewModels/AppViewModel.swift`): Central state manager using `@MainActor`. Handles API configuration, todo persistence via UserDefaults, and orchestrates the fetch→generate flow.

- **BacklogService** (`Services/BacklogService.swift`): Actor for Backlog API. Extracts host from full URL, fetches current user via `/users/myself`, then fetches assigned issues with status filters (open/in-progress/resolved).

- **AIService** (`Services/AIService.swift`): Actor for DeepSeek API. Sends issues to AI for prioritization, parses JSON response with task ordering. Default endpoint is `api.deepseek.com`.

- **TodoItem** (`Models/TodoItem.swift`): Two sources - `.backlog` (with issueKey/issueURL) or `.custom` (user-created). Merge logic preserves completion states across refreshes.

### Storage

- **UserDefaults**: Backlog URL, AI base URL, selected model, todo items (JSON encoded)
- **Keychain**: API keys stored via `KeychainHelper` (service: `com.glance.app`)

### UI Structure

NavigationSplitView with sidebar (action button, connection status) and detail (todo list). Settings presented as sheet.

## Code Style

- **Comments must be in English only**
