<p align="center">
  <img src="AppIcon_1024.png" width="128" alt="SocialPreviewMaker">
</p>

<h1 align="center">SocialPreviewMaker</h1>

<p align="center">
  <b>中文</b> | <a href="#english">English</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2012%2B-black" alt="platform">
  <img src="https://img.shields.io/badge/arch-Intel%20%7C%20Apple%20Silicon-blue" alt="arch">
  <img src="https://img.shields.io/badge/engine-SwiftUI-orange" alt="engine">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="license">
</p>

---

## ✨ 简介

**SocialPreviewMaker** 是一款 macOS 原生的社交预览图生成工具，可将 App 的 README / 项目信息一键转成 1280×640 社交预览图（类似 GitHub 仓库卡片），**零依赖、开箱即用**——纯 SwiftUI / AppKit 渲染，拖入「应用程序」即可。

### 🚀 功能特性

- **🎨 图标自动采色**：拖入 App 图标即提取主色，背景渐变与描边一键匹配。
- **📐 双语 README 解析**：识别 `# 英文 / 中文` 结构，自动拆分名称 / 副标题 / 标语 / 功能胶囊。
- **🖼 所见即所得**：编辑区全量显示文字，画布按宽度约束不溢出。
- **📦 零依赖单 App**：纯系统字体，拖入即用，首启无需任何脚本。
- **🔲 胶囊自动换行**：功能标签每行 3 个自动换行，宽度可调。
- **💾 一键导出**：1280×640 PNG，深色背景、雾蓝描边。

### 📦 安装

1. 从 [Releases](../../releases) 下载 `12-SocialPreviewMaker-1.4.10-universal.dmg`
2. 打开 DMG，将 **SocialPreviewMaker** 拖入「应用程序」
3. 首次打开若被 Gatekeeper 拦截：**右键点击 App → 打开 → 打开**（仅需一次）

> 💡 纯原生渲染，无外部依赖。

### 📱 使用要求

| 项目 | 要求 |
|---|---|
| 系统 | macOS 12.0 及以上 |
| 架构 | Intel 与 Apple Silicon 通用（arm64 + x86_64） |
| 依赖 | 无，纯系统字体与框架 |

### ⚠️ 常见问题

- **打开提示「无法验证开发者」**：右键 App → 打开 → 打开，仅需一次；或终端执行 `xattr -dr com.apple.quarantine /Applications/SocialPreviewMaker.app`。
- **导出图片空白**：确认已拖入 App 图标或填写了应用名称。
- **胶囊显示不全**：编辑区全量显示，画布按宽度截断以保证布局稳定。

---

## ✨ Intro (English)

**SocialPreviewMaker** is a native macOS social-preview image generator that turns an App's README / project info into a 1280×640 social preview image. **Zero dependencies, zero setup** — pure SwiftUI / AppKit rendering, drag into /Applications and use immediately.

### Features

- **Auto color from icon**: drop an App icon and extract its dominant color for background gradient and stroke.
- **Bilingual README parsing**: detects `# English / 中文` structure, auto-splits name / subtitle / tagline / feature pills.
- **WYSIWYG editor**: full text in the editor; canvas truncates by width to avoid overflow.
- **Zero-dependency single App**: pure system fonts, drag-and-use, no scripts on first launch.
- **Auto-wrapping pills**: feature tags wrap 3 per row, width adjustable.
- **One-click export**: 1280×640 PNG, dark background, mist-blue stroke.

### Install

1. Download `12-SocialPreviewMaker-1.4.10-universal.dmg` from [Releases](../../releases)
2. Open the DMG and drag **SocialPreviewMaker** into /Applications
3. If Gatekeeper blocks the first launch: **right-click the app → Open → Open** (once only)

### Requirements

| Item | Requirement |
|---|---|
| System | macOS 12.0 or later |
| Architecture | Universal for Intel & Apple Silicon (arm64 + x86_64) |
| Dependencies | None, pure system fonts and frameworks |

### FAQ

- **"Cannot verify developer" on open**: right-click the app → Open → Open (once); or run `xattr -dr com.apple.quarantine /Applications/SocialPreviewMaker.app`.
- **Blank exported image**: make sure you dropped an App icon or filled in the app name.
- **Pills cut off**: the editor shows full text; the canvas truncates by width to keep layout stable.

---

## 📄 License

- This project is licensed under the **MIT License** — Copyright (c) 2026 banqiu. See [LICENSE](LICENSE).

## 🙏 Credits

- Built with SwiftUI / AppKit / CoreText on macOS.
