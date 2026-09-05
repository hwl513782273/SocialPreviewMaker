import SwiftUI
import UniformTypeIdentifiers

// MARK: - 可选字体（全部 macOS 内置，保持零依赖）

struct FontOption: Identifiable {
    let id: String
    let label: String
    let ps: String?          // PostScript 名，nil = 系统字体
    let weight: NSFont.Weight
}

private let titleFonts: [FontOption] = [
    .init(id: "hn-light", label: "Helvetica Neue · Light", ps: "HelveticaNeue-Light", weight: .light),
    .init(id: "hn-reg",   label: "Helvetica Neue · Regular", ps: "HelveticaNeue", weight: .regular),
    .init(id: "hn-med",   label: "Helvetica Neue · Medium", ps: "HelveticaNeue-Medium", weight: .medium),
    .init(id: "hn-bold",  label: "Helvetica Neue · Bold", ps: "HelveticaNeue-Bold", weight: .bold),
    .init(id: "pf-semi",  label: "PingFang SC · Semibold", ps: "PingFangSC-Semibold", weight: .semibold),
    .init(id: "pf-med",   label: "PingFang SC · Medium", ps: "PingFangSC-Medium", weight: .medium),
    .init(id: "arial",    label: "Arial", ps: "ArialMT", weight: .regular),
    .init(id: "georgia",  label: "Georgia", ps: "Georgia", weight: .regular),
    .init(id: "sys",      label: "系统字体（默认）", ps: nil, weight: .regular),
]

private let bodyFonts: [FontOption] = [
    .init(id: "pf-reg",   label: "PingFang SC · Regular", ps: "PingFangSC-Regular", weight: .regular),
    .init(id: "pf-med",   label: "PingFang SC · Medium", ps: "PingFangSC-Medium", weight: .medium),
    .init(id: "pf-semi",  label: "PingFang SC · Semibold", ps: "PingFangSC-Semibold", weight: .semibold),
    .init(id: "hn-reg",   label: "Helvetica Neue · Regular", ps: "HelveticaNeue", weight: .regular),
    .init(id: "arial",    label: "Arial", ps: "ArialMT", weight: .regular),
    .init(id: "georgia",  label: "Georgia", ps: "Georgia", weight: .regular),
    .init(id: "sys-reg",  label: "系统字体 · Regular", ps: nil, weight: .regular),
    .init(id: "sys-med",  label: "系统字体 · Medium", ps: nil, weight: .medium),
]

struct ContentView: View {
    @State private var name = "示例应用"
    @State private var subtitle = "占位副标题"
    @State private var tagline = "把 README 一键转成 1280×640 社交预览图"
    @State private var tagList: [String] = ["拖入图标", "自动采色", "实时预览"]
    @State private var iconNS: NSImage?
    @State private var iconPath: String?
    @State private var autoColors = true
    @State private var accent = Color(red: 0.357, green: 0.553, blue: 0.937)
    @State private var bgTop = Color(red: 0.102, green: 0.102, blue: 0.180)
    @State private var bgBottom = Color(red: 0.086, green: 0.129, blue: 0.243)
    @State private var preview: NSImage?
    @State private var frames: [ElementFrame] = []
    @State private var offsets: [String: CGSize] = [:]
    @State private var pillExtra: [CGFloat] = [0, 0, 0]
    @State private var draggingID: String?
    @State private var dragBase: [String: CGSize] = [:]
    @State private var isTargeted = false
    @State private var history: [HistorySnapshot] = []
    struct HistorySnapshot {
        var offsets: [String: CGSize]
        var pillExtra: [CGFloat]
    }
    @State private var titleFontID = "hn-light"
    @State private var bodyFontID = "pf-reg"

    // README 自动生成相关状态
    @State private var readmeText = ""
    @State private var readmeURL = ""
    @State private var readmeStatus: String?
    @State private var readmeBusy = false
    @State private var grabIcon = false
    @State private var currentRawBase: String?

    var body: some View {
        HStack(spacing: 0) {
            controls
                .frame(width: 348)
            Divider()
            previewArea
        }
        .frame(minWidth: 1150, minHeight: 700)
        .onAppear(perform: regenerate)
    }

    // 胶囊改为动态 tagList，绑定直接用 $tagList[i]

    // MARK: 左侧控制区

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section("① 应用图标（拖入或选择）") {
                    iconDrop
                    HStack {
                        Button("选择图标…") { chooseIcon() }
                        Spacer()
                        if iconPath != nil {
                            Button("移除") { iconNS = nil; iconPath = nil; regenerate() }
                        }
                    }
                    Toggle("自动从图标采色", isOn: $autoColors)
                        .onChange(of: autoColors) { _ in regenerate() }
                }

                section("② 文案") {
                    labeled("产品名", field: $name)
                    labeled("副标题", field: $subtitle)
                    labeled("标语", field: $tagline)
                }

                section("③ 功能胶囊（宽度滑杆可独立调节 · 解析后全量显示）") {
                    ForEach(tagList.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                TagField(placeholder: "标签 \(i + 1)",
                                         text: $tagList[i],
                                         onChange: regenerate)
                                if tagList.count > 1 {
                                    Button(action: {
                                        pushHistory()
                                        tagList.remove(at: i)
                                        if pillExtra.count > i { pillExtra.remove(at: i) }
                                        regenerate()
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            HStack(spacing: 8) {
                                Text("窄").font(.system(size: 10)).opacity(0.45)
                                Slider(value: Binding(
                                    get: { Double(pillExtra[i]) },
                                    set: { v in pillExtra[i] = CGFloat(v); regenerate() }
                                ), in: -60...260, step: 2,
                                onEditingChanged: { editing in
                                    if editing { pushHistory() }
                                })
                                .disabled($tagList[i].wrappedValue.isEmpty)
                                Text("宽").font(.system(size: 10)).opacity(0.45)
                                Text("\(Int(pillExtra[i]) > 0 ? "+" : "")\(Int(pillExtra[i]))")
                                    .font(.system(size: 10).monospacedDigit())
                                    .opacity(0.55)
                                    .frame(width: 34, alignment: .trailing)
                            }
                            .opacity($tagList[i].wrappedValue.isEmpty ? 0.4 : 1)
                        }
                    }
                    Button(action: {
                        pushHistory()
                        tagList.append("")
                        pillExtra.append(0)
                        regenerate()
                    }) {
                        Label("新增胶囊", systemImage: "plus.circle")
                            .font(.system(size: 12))
                    }
                }

                section("④ 配色（手动改即覆盖自动采样）") {
                    ColorRow(label: "主色 accent", color: $accent, onChange: manualColorChanged)
                    ColorRow(label: "背景顶部", color: $bgTop, onChange: manualColorChanged)
                    ColorRow(label: "背景底部", color: $bgBottom, onChange: manualColorChanged)
                }

                section("⑤ 字体（标题 / 正文分别选择，均为系统内置）") {
                    Picker("标题字体", selection: $titleFontID) {
                        ForEach(titleFonts) { f in Text(f.label).tag(f.id) }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: titleFontID) { _ in regenerate() }
                    Picker("正文字体", selection: $bodyFontID) {
                        ForEach(bodyFonts) { f in Text(f.label).tag(f.id) }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: bodyFontID) { _ in regenerate() }
                }

                section("⑥ 从 README 生成（拖入 / 粘贴 / GitHub 链接）") {
                    readmeDrop
                    HStack {
                        Button("选择 README 文件…") { chooseReadme() }
                        Spacer()
                    }

                    DisclosureGroup("或粘贴 README 文本") {
                        TextEditor(text: $readmeText)
                            .font(.system(size: 12))
                            .frame(minHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12)))
                        Button("解析粘贴内容") { loadReadmePasted() }
                            .disabled(readmeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || readmeBusy)
                    }

                    HStack {
                        TextField("GitHub 链接，如 github.com/owner/repo", text: $readmeURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        Button("载入") { loadReadmeFromURL() }
                            .disabled(readmeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || readmeBusy)
                    }

                    Toggle("尝试从 README 抓图标（需联网）", isOn: $grabIcon)
                        .font(.system(size: 12))
                        .opacity(0.8)

                    if readmeBusy {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("读取中…").font(.system(size: 11)).opacity(0.6)
                        }
                    } else if let st = readmeStatus {
                        Text(st).font(.system(size: 11)).opacity(0.65)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button("复位布局") {
                    offsets = [:]
                    dragBase = [:]
                    pillExtra = [0, 0, 0]
                    history = []
                    regenerate()
                }
                .frame(maxWidth: .infinity)

                Button {
                    undo()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("撤销上一步")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(history.isEmpty)
                .keyboardShortcut("z", modifiers: .command)

                Button {
                    export()
                } label: {
                    Text("导出 PNG（1280×640）")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 2)
            }
            .padding(16)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 13, weight: .semibold)).opacity(0.75)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08)))
    }

    private var iconDrop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isTargeted ? Color.accentColor : Color.primary.opacity(0.15),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [5])))
            if let img = iconNS {
                Image(nsImage: img).resizable().scaledToFit().frame(height: 72)
            } else {
                Text("拖入 AppIcon.png / .icns")
                    .font(.system(size: 12)).opacity(0.5)
            }
        }
        .frame(height: 88)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async { loadIcon(url: url) }
            }
            return true
        }
        .onTapGesture { chooseIcon() }
    }

    @State private var isReadmeTargeted = false
    private var readmeDrop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isReadmeTargeted ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isReadmeTargeted ? Color.accentColor : Color.primary.opacity(0.15),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [5])))
            if readmeStatus != nil {
                Text("已解析 · 见左侧文案区").font(.system(size: 12)).opacity(0.55)
            } else {
                Text("拖入 README.md / .markdown").font(.system(size: 12)).opacity(0.5)
            }
        }
        .frame(height: 64)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onDrop(of: [UTType.fileURL], isTargeted: $isReadmeTargeted) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async { loadReadmeFile(url: url) }
            }
            return true
        }
    }

    private func labeled(_ label: String, field: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12)).opacity(0.6)
            TextField("", text: field)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .onChange(of: field.wrappedValue) { _ in regenerate() }
        }
    }

    private struct TagField: View {
        let placeholder: String
        @Binding var text: String
        var onChange: (() -> Void)? = nil
        var body: some View {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .onChange(of: text) { _ in onChange?() }
        }
    }

    private struct ColorRow: View {
        let label: String
        @Binding var color: Color
        var onChange: (() -> Void)? = nil
        var body: some View {
            HStack {
                Text(label).font(.system(size: 12)).opacity(0.6)
                Spacer()
                ColorPicker("", selection: $color, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: color) { _ in onChange?() }
            }
        }
    }

    // MARK: 右侧：可拖拽预览画布

    private var previewArea: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let s = geo.size.width / CanvasRenderer.canvasW
                ZStack(alignment: .topLeading) {
                    if let img = preview {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                    }
                    // 元素热区：可拖拽
                    ForEach(frames, id: \.id) { f in
                        let dragging = draggingID == f.id
                        Rectangle()
                            .fill(dragging ? Color.white.opacity(0.12) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(dragging ? Color.accentColor : Color.white.opacity(0.0),
                                                  style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                            .contentShape(Rectangle())
                            .frame(width: f.rect.width * s, height: f.rect.height * s)
                            .offset(x: f.rect.origin.x * s, y: f.rect.origin.y * s)
                            .onHover { hovering in
                                if hovering && draggingID == nil { NSCursor.pointingHand.push() }
                                else { NSCursor.pop() }
                            }
                            .gesture(dragGesture(f, scale: s))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width / 2, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text("拖动画布中的文字块可自由调整位置 · 虚线框为可拖拽热区")
                .font(.system(size: 11)).opacity(0.45)
            Text("1280 × 640 · 与 GitHub Social preview 同规格")
                .font(.system(size: 11)).opacity(0.45)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func dragGesture(_ f: ElementFrame, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if draggingID != f.id {
                    draggingID = f.id
                    dragBase[f.id] = offsets[f.id] ?? .zero
                    pushHistory()
                }
                let base = dragBase[f.id] ?? .zero
                offsets[f.id] = CGSize(width: base.width + value.translation.width / scale,
                                       height: base.height + value.translation.height / scale)
                regenerate()
            }
            .onEnded { _ in
                draggingID = nil
                dragBase[f.id] = nil
            }
    }

    // MARK: 逻辑

    private func pushHistory() {
        history.append(HistorySnapshot(offsets: offsets, pillExtra: pillExtra))
        if history.count > 200 { history.removeFirst() }
    }

    private func undo() {
        guard let snap = history.popLast() else { return }
        offsets = snap.offsets
        pillExtra = snap.pillExtra
        regenerate()
    }

    private func manualColorChanged() {
        autoColors = false
        regenerate()
    }

    private func loadIcon(url: URL) {
        guard let img = NSImage(contentsOf: url) else { return }
        iconNS = img
        iconPath = url.path
        if autoColors { applySampledColors(from: img) }
        regenerate()
    }

    private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, UTType(filenameExtension: "icns")!]
        panel.begin { r in
            guard r == .OK, let url = panel.url else { return }
            loadIcon(url: url)
        }
    }

    // MARK: README 自动生成

    private func parseAndFill(_ raw: String, rawBase: String?, productName: String? = nil) {
        let res = ReadmeParser.parse(raw, productName: productName)
        name = res.name
        subtitle = res.subtitle
        tagline = res.tagline
        tagList = res.tags
        if pillExtra.count < tagList.count {
            pillExtra.append(contentsOf: Array(repeating: CGFloat(0), count: tagList.count - pillExtra.count))
        }
        readmeStatus = "已提取：\(res.name) · 跳过元数据\(res.skippedMeta)段 · 截断\(res.truncated)处"
        if grabIcon,
           let imgPath = ReadmeParser.extractImageURL(raw),
           let absURL = ReadmeParser.resolveImageURL(imgPath, rawBase: rawBase) {
            readmeBusy = true
            ReadmeParser.fetchImage(absURL) { img in
                DispatchQueue.main.async {
                    readmeBusy = false
                    if let img = img {
                        iconNS = img
                        iconPath = absURL
                        if autoColors { applySampledColors(from: img) }
                    }
                    regenerate()
                }
            }
        } else {
            regenerate()
        }
    }

    private func chooseReadme() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "md")!, UTType(filenameExtension: "markdown")!]
        panel.begin { r in
            guard r == .OK, let url = panel.url else { return }
            loadReadmeFile(url: url)
        }
    }

    private func loadReadmeFile(url: URL) {
        guard let txt = try? String(contentsOf: url, encoding: .utf8) else {
            readmeStatus = "读取文件失败"
            return
        }
        parseAndFill(txt, rawBase: nil)
    }

    private func loadReadmePasted() {
        parseAndFill(readmeText, rawBase: nil)
    }

    private func loadReadmeFromURL() {
        let input = readmeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        readmeBusy = true
        readmeStatus = nil
        let base = ReadmeParser.rawBase(for: input)
        let repo = Self.repoNameFromURL(input)
        ReadmeParser.fetchMarkdown(input) { result in
            DispatchQueue.main.async {
                readmeBusy = false
                switch result {
                case .success(let txt):
                    currentRawBase = base
                    parseAndFill(txt, rawBase: base, productName: repo)
                case .failure(let err):
                    readmeStatus = "载入失败：\(err.localizedDescription)"
                }
            }
        }
    }

    /// 从 GitHub URL 提取仓库名（owner/repo 的 repo 段），作为产品名最准确来源
    private static func repoNameFromURL(_ input: String) -> String? {
        guard let u = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = u.host, host == "github.com" else { return nil }
        let comps = u.pathComponents.filter { $0 != "/" }
        guard comps.count >= 2 else { return nil }
        var repo = comps[1]
        if repo.hasSuffix(".git") { repo = String(repo.dropLast(4)) }
        return repo
    }

    private func applySampledColors(from img: NSImage) {
        guard let s = CanvasRenderer.sampleColors(from: img) else { return }
        accent = Color(nsColor: s.accent)
        bgTop = Color(nsColor: s.top)
        bgBottom = Color(nsColor: s.bottom)
    }

    private func buildConfig() -> PreviewConfig {
        func ns(_ c: Color) -> NSColor {
            NSColor(c).usingColorSpace(.deviceRGB) ?? .controlAccentColor
        }
        var cfg = PreviewConfig(
            name: name,
            subtitle: subtitle,
            tagline: tagline,
            tags: tagList,
            icon: iconNS,
            accent: autoColors ? nil : ns(accent),
            bgTop: autoColors ? nil : ns(bgTop),
            bgBottom: autoColors ? nil : ns(bgBottom))
        cfg.offsets = offsets
        cfg.pillExtra = pillExtra
        let tf = titleFonts.first(where: { $0.id == titleFontID }) ?? titleFonts[0]
        let bf = bodyFonts.first(where: { $0.id == bodyFontID }) ?? bodyFonts[0]
        cfg.titleFontName = tf.ps
        cfg.titleWeight = tf.weight
        cfg.bodyFontName = bf.ps
        cfg.bodyWeight = bf.weight
        return cfg
    }

    private func regenerate() {
        let r = CanvasRenderer.imageWithFrames(buildConfig())
        preview = r.0
        frames = r.1
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "social-preview.png"
        panel.begin { r in
            guard r == .OK, let url = panel.url, let data = CanvasRenderer.pngData(buildConfig()) else { return }
            try? data.write(to: url)
        }
    }
}
