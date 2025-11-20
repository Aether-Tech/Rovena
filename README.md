# Rovena

Personal AI Workspace for macOS with support for multiple AIs (OpenAI, Anthropic, Gemini).

<p align="center">
  <img src="Rovena1.png" alt="Rovena Logo" width="200"/>
</p>

## 📥 Quick Installation

### Option 1: DMG Installer (Recommended)

1. Download the [Rovena-Installer.dmg](Rovena-Installer.dmg) file.
2. Open the DMG file.
3. Drag **Rovena.app** to the **Applications** folder.
4. Open Rovena from the Applications folder.
5. If macOS blocks it, go to **System Settings** → **Privacy & Security** → **Open Anyway**.

### Option 2: Build from Source

```bash
git clone https://github.com/1Verona/Rovena.git
cd Rovena
./build_and_run.sh
```

## ✨ Features

- 🤖 **AI Chat**: Support for GPT-4o, GPT-3.5, Claude, and Gemini Pro.
- 🎨 **Infinite Canvas**: Collaborative drawing board with professional tools.
  - Pan tool (hand icon) to navigate the board.
  - Tools: Selection, Brush, Rectangle, Circle, Text.
  - Text editing by clicking on elements.
  - Automatic persistence of all drawings.
- 📁 **Smart History**: All conversations saved with configurable retention.
- 🖼️ **Media Gallery**: 
  - Highlighted view (fullscreen).
  - Image download.
  - Manual deletion of images.
- 🔐 **Firebase Authentication**: Secure login with email/password.
- 🌓 **Theme System**: 
  - 2 professional themes: Terminal (Cyber) and Corporate.
  - Light/Dark mode for each theme.
- 📷 **DALL-E 3**: Image generation with the `/image` command.
- 📎 **Smart Attachments**: Upload images, PDFs, and text files.
- ✅ **Task Management**: Complete to-do system.

## 🎯 Getting Started

### 1. Create Account

The first time you open Rovena:
1. Click on **"CREATE_NEW_UPLINK >>"**.
2. Enter a valid email and password (minimum 6 characters).
3. Click on **"INITIALIZE_USER"**.

### 2. Configure API Keys

After logging in:
1. Go to **Config** (Settings).
2. Add your API keys:
   - **OPENAI_API_KEY**: For GPT and DALL-E ([Get Key](https://platform.openai.com/api-keys))
   - **ANTHROPIC_API_KEY**: For Claude ([Get Key](https://console.anthropic.com/))
   - **GEMINI_API_KEY**: For Gemini ([Get Key](https://makersuite.google.com/app/apikey))

### 3. Start Using

- **Home**: Quickly start a new conversation.
- **Chat**: Talk to the AI, use `/image` to generate images.
- **Schematics**: Draw diagrams and schemes.
- **Archives**: Access old conversations and image gallery.
- **Tasks**: Organize your tasks.

## 🛠️ Development

### Requirements

- macOS 14.0 or higher
- Swift 5.9+
- Xcode 15+ (optional)

### Build

```bash
# Build and run
./build_and_run.sh

# Build only
swift build

# Create DMG for distribution
./create_dmg.sh
```

### Project Structure

```
Rovena/
├── Sources/
│   ├── App/
│   │   ├── VeroChatApp.swift       # Entry point
│   │   ├── ContentView.swift       # Main navigation
│   │   ├── DesignSystem.swift      # Theme system
│   │   └── GoogleService-Info.plist
│   ├── Models/
│   │   ├── ChatMessage.swift
│   │   ├── ChatSession.swift
│   │   ├── CanvasElement.swift
│   │   └── ToDoItem.swift
│   ├── Services/
│   │   ├── AIService.swift         # OpenAI/Gemini
│   │   ├── AuthManager.swift       # Firebase Auth (REST API)
│   │   ├── HistoryService.swift    # Local persistence
│   │   ├── CanvasService.swift     # Canvas persistence
│   │   ├── ToDoService.swift       # Task management
│   │   └── SettingsManager.swift   # Preferences
│   └── Views/
│       ├── HomeView.swift          # Dashboard
│       ├── ChatView.swift          # Chat interface
│       ├── CanvasView.swift        # Infinite canvas
│       ├── HistoryView.swift       # Archives & Media
│       ├── ToDoView.swift          # Task list
│       ├── SettingsView.swift      # Settings
│       ├── LoginView.swift         # Authentication
│       └── ProfileView.swift       # User profile
├── Package.swift
├── build_and_run.sh                # Automatic Build & Run
├── create_dmg.sh                   # Create installer
├── Rovena.entitlements             # App permissions
├── Rovena-Installer.dmg            # 📦 Ready-to-use installer
└── README.md
```

## 🎨 Available Themes

### Terminal (Cyber)
- **Dark**: Pure black with white accents.
- **Light**: Light gray (95%) with black text.
- Minimalist and futuristic aesthetic.

### Corporate
- **Dark**: Professional dark blue.
- **Light**: Clean white.
- Modern corporate look.

## 🚀 Advanced Features

### AI Chat
- Model selection (GPT-3.5, GPT-4, GPT-4o, Gemini Pro).
- Conversation history with configurable TTL (1-3650 days).
- Image upload for analysis (GPT-4 Vision).
- Attach PDFs and text files as context.
- Command `/image [prompt]` to generate images with DALL-E 3.

### Canvas (Schematics)
- Infinite canvas with pan (hand tool).
- Professional drawing tools.
- Inline text editing.
- Adaptive grid.
- Auto-save for all elements.
- Custom color picker.

### Archives
- **LOGS**: Complete list of sessions.
  - Retention and expiration info.
  - Manual deletion via button or context menu.
- **MEDIA**: Generated image gallery.
  - Fullscreen preview.
  - Hover controls (download/delete).
  - Organization by date.

## 🔧 Configuration

### Supported API Keys
- OpenAI (GPT-3.5, GPT-4, GPT-4o, DALL-E 3)
- Anthropic (Claude)
- Google (Gemini Pro)
- Custom Endpoints (for compatible APIs)

### Preferences
- Visual Theme (Terminal/Corporate/Retro)
- Light/Dark Mode
- All preferences are saved locally

## 📝 Useful Commands

### In Chat
- `/image [description]` - Generates an image with DALL-E 3.
- Drag files to attach to context.
- Enter to send, Shift+Enter for new line.

### In Canvas
- **Hand Tool**: Click and drag to navigate.
- **Selection**: Click on text to edit.
- **Text**: Click to position, then click again to edit.
- **Other tools**: Drag to draw.

## 📄 License

MIT License

## 🙏 Credits

Developed by Verona

---

**⭐ If you liked Rovena, consider giving a star to the repository!**
