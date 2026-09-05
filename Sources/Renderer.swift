import AppKit
import CoreText

// MARK: - 画布元素包围框（1280×640 画布坐标，左上原点）

struct ElementFrame {
    let id: String
    let rect: CGRect
}

// MARK: - 配置模型

struct PreviewConfig {
    var name: String
    var subtitle: String
    var tagline: String
    var tags: [String]
    var icon: NSImage?
    var accent: NSColor
    var bgTop: NSColor
    var bgBottom: NSColor
    var titleColor: NSColor = .white
    var subColor: NSColor
    var tagColor: NSColor
    /// 标题字体（PostScript 名，nil = 系统字体 + titleWeight）
    var titleFontName: String? = "HelveticaNeue-Light"
    var titleWeight: NSFont.Weight = .light
    /// 正文字体（副标题/标语/胶囊共用）
    var bodyFontName: String? = "PingFangSC-Regular"
    var bodyWeight: NSFont.Weight = .regular
    /// 每个元素的拖拽偏移（画布像素），key: title/subtitle/tagline/pill0..2
    var offsets: [String: CGSize] = [:]
    /// 每个胶囊的额外宽度（可负，画布像素）
    var pillExtra: [CGFloat] = [0, 0, 0]

    init(name: String, subtitle: String, tagline: String, tags: [String],
         icon: NSImage?, accent: NSColor?, bgTop: NSColor?, bgBottom: NSColor?) {
        self.name = name.isEmpty ? "App" : name
        self.subtitle = subtitle
        self.tagline = tagline
        self.tags = tags
        self.icon = icon

        var acc: NSColor?
        var top: NSColor?
        var bot: NSColor?
        if let icon = icon, accent == nil || bgTop == nil || bgBottom == nil,
           let s = CanvasRenderer.sampleColors(from: icon) {
            acc = s.accent; top = s.top; bot = s.bottom
        }
        self.accent = accent ?? acc ?? NSColor(srgbRed: 0.486, green: 0.322, blue: 0.851, alpha: 1)
        self.bgTop = bgTop ?? top ?? NSColor(srgbRed: 0.059, green: 0.047, blue: 0.114, alpha: 1)
        self.bgBottom = bgBottom ?? bot ?? NSColor(srgbRed: 0.165, green: 0.118, blue: 0.322, alpha: 1)

        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let rgb = self.accent.usingColorSpace(.deviceRGB) ?? self.accent
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        self.subColor = NSColor(hue: h, saturation: 0.06, brightness: 0.98, alpha: 1)
        self.tagColor = NSColor(hue: h, saturation: 0.30, brightness: 0.91, alpha: 1)
    }
}

// MARK: - 渲染器（1280×640，与模板一致）

final class CanvasRenderer {
    static let canvasW: CGFloat = 1280
    static let canvasH: CGFloat = 640

    // MARK: 图标主色自动采样（饱和色相众数）

    static func sampleColors(from image: NSImage) -> (accent: NSColor, top: NSColor, bottom: NSColor)? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        var hues: [Int: Int] = [:]
        let w = rep.pixelsWide, h = rep.pixelsHigh
        var y = 0
        while y < h {
            var x = 0
            while x < w {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.78 {
                    var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, a: CGFloat = 0
                    c.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &a)
                    if sat > 0.30 && bri > 0.30 {
                        hues[Int(hue * 36) % 36, default: 0] += 1
                    }
                }
                x += 4
            }
            y += 4
        }
        guard let best = hues.max(by: { $0.value < $1.value }) else { return nil }
        let hue = CGFloat(best.key) / 36.0
        return (NSColor(hue: hue, saturation: 0.72, brightness: 0.82, alpha: 1),
                NSColor(hue: hue, saturation: 0.55, brightness: 0.10, alpha: 1),
                NSColor(hue: hue, saturation: 0.60, brightness: 0.32, alpha: 1))
    }

    // MARK: 渲染（返回 PNG Data + 元素包围框）

    static func render(_ cfg: PreviewConfig) -> (data: Data?, frames: [ElementFrame]) {
        let W = canvasW, H = canvasH
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0),
              let gctx = NSGraphicsContext(bitmapImageRep: rep) else { return (nil, []) }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gctx
        let frames = draw(cfg, W: W, H: H)
        NSGraphicsContext.restoreGraphicsState()
        let data = rep.representation(using: .png, properties: [:])
        return (data, frames)
    }

    static func pngData(_ cfg: PreviewConfig) -> Data? {
        render(cfg).data
    }

    static func imageWithFrames(_ cfg: PreviewConfig) -> (NSImage?, [ElementFrame]) {
        let r = render(cfg)
        guard let d = r.data else { return (nil, []) }
        return (NSImage(data: d), r.frames)
    }

    // MARK: 绘制（非翻转坐标，y 轴向上；文字全部走 CoreText）

    private static func draw(_ cfg: PreviewConfig, W: CGFloat, H: CGFloat) -> [ElementFrame] {
        var frames: [ElementFrame] = []

        // 1. 背景垂直渐变（上暗下亮）
        NSGradient(colors: [cfg.bgTop, cfg.bgBottom])!
            .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

        // 2. 应用图标 320×320 @ iconX 垂直居中
        let iconX: CGFloat = 95
        if let icon = cfg.icon {
            let s: CGFloat = 320
            let rect = NSRect(x: iconX, y: (H - s) / 2, width: s, height: s)
            if let cg = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let cgc = NSGraphicsContext.current!.cgContext
                cgc.interpolationQuality = .high
                cgc.draw(cg, in: rect)
            }
        }

        let x: CGFloat = 460
        // 边界约束：最长文字行的最后一个字距右边框 = iconX（95px）；短文字保持左对齐，不右推
        let sideMargin: CGFloat = iconX
        let avail = W - x - sideMargin

        func mkFont(ps: String?, _ size: CGFloat, weight: NSFont.Weight) -> NSFont {
            if let ps = ps, let f = NSFont(name: ps, size: size) { return f }
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
        func width(_ s: String, _ f: NSFont) -> CGFloat {
            NSAttributedString(string: s, attributes: [.font: f]).size().width
        }
        func off(_ id: String) -> CGSize { cfg.offsets[id] ?? .zero }

        // 3. 标题 Light，超宽自动缩 78→40，仍超则截断（画布层：放不下才加 …）
        var tSize: CGFloat = 78
        var titleFont = mkFont(ps: cfg.titleFontName, tSize, weight: cfg.titleWeight)
        while tSize > 40 {
            titleFont = mkFont(ps: cfg.titleFontName, tSize, weight: cfg.titleWeight)
            if width(cfg.name, titleFont) <= avail { break }
            tSize -= 4
        }
        let displayName = width(cfg.name, titleFont) <= avail
            ? cfg.name
            : Self.truncateToWidth(cfg.name, maxWidth: avail, font: titleFont)

        // 4. 副标题/标语超宽降字号，仍超则截断（画布层：放不下才加 …）
        var subFont = mkFont(ps: cfg.bodyFontName, 38, weight: cfg.bodyWeight)
        if width(cfg.subtitle, subFont) > avail {
            subFont = mkFont(ps: cfg.bodyFontName, 32, weight: cfg.bodyWeight)
        }
        let displaySub = width(cfg.subtitle, subFont) <= avail
            ? cfg.subtitle
            : Self.truncateToWidth(cfg.subtitle, maxWidth: avail, font: subFont)
        // tagline：先按 25 号字折行，超 3 行则降到 21 号，仍超则截断到第 3 行尾
        var tagFont = mkFont(ps: cfg.bodyFontName, 25, weight: cfg.bodyWeight)
        var tagLines = wrapText(cfg.tagline, font: tagFont, maxWidth: avail)
        if tagLines.count > 3 {
            tagFont = mkFont(ps: cfg.bodyFontName, 21, weight: cfg.bodyWeight)
            tagLines = wrapText(cfg.tagline, font: tagFont, maxWidth: avail)
            if tagLines.count > 3 {
                var kept = Array(tagLines.prefix(3))
                let last = kept[2]
                if last.count > 1 { kept[2] = String(last.dropLast()) + "…" }
                tagLines = kept
            }
        }
        let pillFont = mkFont(ps: cfg.bodyFontName, 20, weight: cfg.bodyWeight)

        // 5. 标题 CoreText 行 + 字形路径包围盒
        let titleAttr = NSAttributedString(string: displayName,
                                           attributes: [.font: titleFont, .foregroundColor: cfg.titleColor])
        let titleLine = CTLineCreateWithAttributedString(titleAttr)
        let tBounds = CTLineGetBoundsWithOptions(titleLine, .useGlyphPathBounds)
        let titleDepth = titleFont.ascender - tBounds.minY
        let titleWidth = tBounds.width

        let subLineH = subFont.ascender - subFont.descender
        let tagLineH = tagFont.ascender - tagFont.descender
        let pillH = ceil(pillFont.ascender - pillFont.descender) + 20

        // 6. 逐行排版，整块垂直居中
        let uH: CGFloat = 5, uGap: CGFloat = 10, g1: CGFloat = 26, g2: CGFloat = 18, g3: CGFloat = 30
        let tagBlockH = tagLineH * CGFloat(tagLines.count) + 4 * CGFloat(max(0, tagLines.count - 1))
        // —— 胶囊换行：每行 3 个，整块高度随行数增长（垂直居中自动适配）——
        let pillsPerRow = 3
        let rowGap: CGFloat = 14
        let validTags = cfg.tags.filter { !$0.isEmpty }
        let pillRows = validTags.isEmpty ? 0 : Int(ceil(Double(validTags.count) / Double(pillsPerRow)))
        let pillBlockH = pillH * CGFloat(pillRows) + rowGap * CGFloat(max(0, pillRows - 1))
        let blockH = titleDepth + uGap + uH + g1 + subLineH + g2 + tagBlockH + g3 + pillBlockH
        var top = (H - blockH) / 2 - 10

        // —— 标题（含下划线，一起拖动；左对齐）——
        let tOff = off("title")
        let titleBlockTop = top + tOff.height
        let titleX = x + tOff.width
        drawCT(titleAttr, x: titleX, baselineY: H - (titleBlockTop + titleFont.ascender))
        top += titleDepth + uGap
        let uw = max(90, titleWidth / 4)
        cfg.accent.setFill()
        NSRect(x: titleX + 2, y: H - top - tOff.height - uH, width: uw, height: uH).fill()
        top += uH + g1
        frames.append(ElementFrame(id: "title",
                                   rect: CGRect(x: x + tOff.width, y: titleBlockTop,
                                                width: max(uw + 2, titleWidth),
                                                height: titleDepth + uGap + uH)))

        // —— 副标题（左对齐）——
        let sOff = off("subtitle")
        let subW = width(displaySub, subFont)
        let subX = x + sOff.width
        drawCT(NSAttributedString(string: displaySub,
                                  attributes: [.font: subFont, .foregroundColor: cfg.subColor]),
               x: subX, baselineY: H - (top + sOff.height + subFont.ascender))
        frames.append(ElementFrame(id: "subtitle",
                                   rect: CGRect(x: x + sOff.width, y: top + sOff.height, width: subW, height: subLineH)))
        top += subLineH + g2

        // —— 标语（自动换行，最多 3 行；左对齐）——
        let gOff = off("tagline")
        let tagW = tagLines.map { width($0, tagFont) }.max() ?? 0
        var ty = top + gOff.height
        for ln in tagLines {
            let lnX = x + gOff.width
            drawCT(NSAttributedString(string: ln,
                                      attributes: [.font: tagFont, .foregroundColor: cfg.tagColor]),
                   x: lnX, baselineY: H - (ty + tagFont.ascender))
            ty += tagLineH + 4
        }
        frames.append(ElementFrame(id: "tagline",
                                   rect: CGRect(x: x + gOff.width, y: top + gOff.height,
                                                width: max(tagW, 1), height: tagBlockH)))
        top += tagBlockH + g3

        // —— 胶囊 ×N（每行 3 个、自动换行；宽度可调：pillExtra[i]；左对齐）——
        // 画布层：UI 端 tagList 保留完整文字；此处按"胶囊目标宽度"决定显示多少字。
        //   · 胶囊目标宽度 = baseW(默认≈212) + pillExtra[i]（滑杆拉宽 → 能显示更多字）
        //   · 文字比目标宽度窄 → 全显示，胶囊收缩贴合文字
        //   · 文字比目标宽度宽 → 截断到目标宽度内能放下的字数 + …
        //   · 每满 pillsPerRow 个即换行，新行 px 重置为 x、py 下移一行
        let baseW: CGFloat = 212
        let innerPad: CGFloat = 52
        let pillGap: CGFloat = 18
        var px = x
        var rowIndex = 0
        var colIndex = 0
        let pillStartY = top
        for (i, rawLabel) in cfg.tags.enumerated() where !rawLabel.isEmpty {
            let pOff = off("pill\(i)")
            let extra = i < cfg.pillExtra.count ? cfg.pillExtra[i] : 0
            let targetW = baseW + extra
            let fullW = Self.widthOf(rawLabel, pillFont)
            let (label, w): (String, CGFloat)
            if fullW + innerPad <= targetW {
                label = rawLabel
                w = fullW + innerPad
            } else {
                label = Self.truncateToWidth(rawLabel, maxWidth: targetW - innerPad, font: pillFont)
                w = targetW
            }
            let attr = NSAttributedString(string: label,
                                          attributes: [.font: pillFont, .foregroundColor: cfg.tagColor])
            let py = pillStartY + pOff.height + CGFloat(rowIndex) * (pillH + rowGap)
            let rectY = H - py - pillH
            let path = NSBezierPath(roundedRect: NSRect(x: px + pOff.width, y: rectY, width: w, height: pillH),
                                    xRadius: pillH / 2, yRadius: pillH / 2)
            cfg.accent.setStroke()
            path.lineWidth = 2
            path.stroke()
            // 用真实字形盒（useGlyphPathBounds）做垂直居中，CJK/Latin 都准
            let pillGlyphLine = CTLineCreateWithAttributedString(attr)
            let glyphB = CTLineGetBoundsWithOptions(pillGlyphLine, .useGlyphPathBounds)
            let baseline = rectY + pillH / 2 - (glyphB.minY + glyphB.height / 2)
            drawCT(attr, x: px + pOff.width + 26, baselineY: baseline)
            frames.append(ElementFrame(id: "pill\(i)",
                                       rect: CGRect(x: px + pOff.width, y: py, width: w, height: pillH)))
            px += w + pillGap
            colIndex += 1
            if colIndex >= pillsPerRow {
                colIndex = 0
                rowIndex += 1
                px = x
            }
        }
        return frames
    }

    // 测量文字宽度（static 版本，供画布胶囊动态截断使用）
    private static func widthOf(_ s: String, _ f: NSFont) -> CGFloat {
        NSAttributedString(string: s, attributes: [.font: f]).size().width
    }

    // 画布层按"目标宽度"截断：能显示多少显示多少，放不下才加 …
    private static func truncateToWidth(_ s: String, maxWidth: CGFloat, font: NSFont) -> String {
        let full = widthOf(s, font)
        if full <= maxWidth { return s }
        var lo = 0, hi = s.count
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if widthOf(String(s.prefix(mid)), font) <= maxWidth { lo = mid } else { hi = mid - 1 }
        }
        if lo <= 0 { return "" }
        return String(s.prefix(lo)) + "…"
    }

    // 按最大宽度把字符串折成多行（CoreText 类型排版器建议断行）
    private static func wrapText(_ s: String, font: NSFont, maxWidth: CGFloat) -> [String] {
        guard !s.isEmpty else { return [] }
        let attr = NSAttributedString(string: s, attributes: [.font: font])
        let typesetter = CTTypesetterCreateWithAttributedString(attr)
        let total = (s as NSString).length
        var lines: [String] = []
        var start = 0
        while start < total {
            var count = CTTypesetterSuggestLineBreak(typesetter, start, maxWidth)
            if count == 0 { count = 1 }
            let end = min(start + count, total)
            lines.append((s as NSString).substring(with: NSRange(location: start, length: end - start)))
            start = end
        }
        return lines
    }

    private static func drawCT(_ attr: NSAttributedString, x: CGFloat, baselineY: CGFloat) {
        let line = CTLineCreateWithAttributedString(attr)
        let cgc = NSGraphicsContext.current!.cgContext
        cgc.textPosition = CGPoint(x: x, y: baselineY)
        CTLineDraw(line, cgc)
    }
}

// MARK: - 工具

enum HexColor {
    static func parse(_ s: String?) -> NSColor? {
        guard var t = s?.trimmingCharacters(in: .whitespaces), t.hasPrefix("#") else { return nil }
        t.removeFirst()
        guard t.count == 6, let v = UInt64(t, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                       green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - CLI 模式

enum CLI {
    static func handleIfRequested() {
        let args = CommandLine.arguments
        guard args.contains("--export") else { return }
        func arg(_ key: String) -> String? {
            guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        guard let out = arg("--out") else {
            fputs("[SocialPreviewMaker] 缺少 --out 参数\n", stderr)
            exit(1)
        }
        var icon: NSImage?
        if let ip = arg("--icon") {
            if let img = NSImage(contentsOf: URL(fileURLWithPath: ip)) {
                icon = img
            } else {
                fputs("[SocialPreviewMaker] 图标加载失败: \(ip)\n", stderr)
                exit(1)
            }
        }
        let tags = (arg("--tags") ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var cfg = PreviewConfig(
            name: arg("--name") ?? "App",
            subtitle: arg("--subtitle") ?? "",
            tagline: arg("--tagline") ?? "",
            tags: tags,
            icon: icon,
            accent: HexColor.parse(arg("--accent")),
            bgTop: HexColor.parse(arg("--bg-top")),
            bgBottom: HexColor.parse(arg("--bg-bottom")))
        // 可选：从 README 解析文案（覆盖上面的 name/subtitle/tagline/tags）
        if let rp = arg("--readme"), let rtxt = try? String(contentsOfFile: rp, encoding: .utf8) {
            let r = ReadmeParser.parse(rtxt)
            cfg.name = r.name
            cfg.subtitle = r.subtitle
            cfg.tagline = r.tagline
            cfg.tags = r.tags
            fputs("[SocialPreviewMaker] 已从 README 解析：name=\(r.name) · subtitle=\(r.subtitle) · tagline=\(r.tagline) · tags=\(r.tags.joined(separator: "/")) · 跳过元数据\(r.skippedMeta)段 · 截断\(r.truncated)处\n", stderr)
        }
        // 可选布局覆盖：--offset title:120,40（可多次）；--pillw 0:80（可多次）
        var offsets: [String: CGSize] = [:]
        var extra: [CGFloat] = [0, 0, 0]
        var i = 0
        while i < args.count {
            if args[i] == "--offset", i + 1 < args.count {
                let parts = args[i + 1].split(separator: ":")
                if parts.count == 2 {
                    let xy = parts[1].split(separator: ",").compactMap { Double($0) }
                    if xy.count == 2 { offsets[String(parts[0])] = CGSize(width: xy[0], height: xy[1]) }
                }
                i += 2
            } else if args[i] == "--pillw", i + 1 < args.count {
                let parts = args[i + 1].split(separator: ":")
                if parts.count == 2, let idx = Int(parts[0]), let w = Double(parts[1]), (0..<3).contains(idx) {
                    extra[idx] = CGFloat(w)
                }
                i += 2
            } else {
                i += 1
            }
        }
        cfg.offsets = offsets
        cfg.pillExtra = extra
        guard let data = CanvasRenderer.pngData(cfg) else {
            fputs("[SocialPreviewMaker] 渲染失败\n", stderr)
            exit(1)
        }
        do {
            try data.write(to: URL(fileURLWithPath: out))
            print("OK -> \(out)")
        } catch {
            fputs("[SocialPreviewMaker] 写出失败: \(error)\n", stderr)
            exit(1)
        }
        exit(0)
    }
}
