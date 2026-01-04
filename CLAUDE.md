# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run

This is a native macOS SwiftUI application. Open `Glance.xcodeproj` in Xcode to build and run.

- **Build**: Cmd+B in Xcode, or `xcodebuild -project Glance.xcodeproj -scheme Glance build`
- **Run**: Cmd+R in Xcode
- **Target**: macOS 13.0+, supports both Apple Silicon and Intel

## Architecture

Glance is a Mac productivity app that fetches Backlog issues and calendar events, uses AI (DeepSeek) to generate prioritized todo lists, and can submit time entries to Redmine.

### Core Data Flow

```
User clicks "获取票据并生成待办"
    → AppViewModel.fetchAndGenerateTodos()
        → BacklogService.fetchMyIssues()
        → CalendarService.fetchEvents() (if enabled)
        → AIService.generateTodoList() - AI sorts issues by priority/dates
        → mergeTodoItems() - preserves custom todos and completion states
```

### Time Entry Generation Flow

```
User clicks "生成工时记录"
    → AppViewModel.generateTimeEntriesForCompletedTodos()
        → RedmineService.fetchProjects/Trackers/Activities()
        → AIService.matchProjectsTrackersAndActivities() - matches todos to Redmine entities
        → AIService.matchIssue() - for each todo, finds best matching issue
        → Creates PendingTimeEntry objects for review before submission
```

### Key Components

- **AppViewModel** (`ViewModels/AppViewModel.swift`): Central state manager using `@MainActor`. Singleton pattern (`shared`). Handles:
  - API configuration persistence (UserDefaults + Keychain)
  - Todo CRUD with automatic persistence
  - Orchestrates fetch→generate flows for both todos and time entries
  - Navigation state (`NavigationDestination`)

- **BacklogService** (`Services/BacklogService.swift`): Actor for Backlog API. Extracts host from full URL, fetches current user via `/users/myself`, then fetches assigned issues with status filters.

- **AIService** (`Services/AIService.swift`): Actor for DeepSeek/OpenAI-compatible API. Two main functions:
  - `generateTodoList()` - prioritizes Backlog issues considering calendar events
  - `matchProjectsTrackersAndActivities()` / `matchIssue()` - matches todos to Redmine entities for time entry generation

- **RedmineService** (`Services/RedmineService.swift`): Actor for Redmine REST API. Fetches projects, trackers, activities, issues, and submits time entries.

- **CalendarService** (`Services/CalendarService.swift`): Actor wrapping EventKit. Handles macOS 13/14+ authorization differences (`requestAccess` vs `requestFullAccessToEvents`).

- **TodoItem** (`Models/TodoItem.swift`): Three sources via `TodoSource` enum:
  - `.backlog` - with issueKey, issueURL, priority, dates, milestones
  - `.calendar` - with eventId, start/end times, location
  - `.custom` - user-created

### Storage

- **UserDefaults**: Backlog URL, Redmine URL, AI base URL, selected model, calendar settings, todo items (JSON encoded)
- **Keychain**: API keys stored via `KeychainHelper` (service: `com.glance.app`) - separate keys for Backlog, OpenAI, Redmine

### UI Structure

- NavigationSplitView with sidebar containing navigation to todos or time entry views
- Settings presented as sheet
- Two main destinations: `.todos` (MainView) and `.timeEntry` (RedmineTimeEntryView)

## Code Style

- **Comments must be in English only**
- Services use Swift `actor` for thread safety
- AppViewModel uses `@MainActor` for UI-safe state updates
