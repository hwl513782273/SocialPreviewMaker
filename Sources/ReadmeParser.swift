import Foundation
import AppKit

// MARK: - README 解析结果

struct ReadmeResult {
    var name: String = "App"
    var subtitle: String = ""
    var tagline: String = ""
    var tags: [String] = []
    var skippedMeta: Int = 0   // 跳过的元数据段数（作者/许可证/版本等）
    var truncated: Int = 0     // 因超宽被截断的字段数
}

// MARK: - 解析 + 远程抓取（纯本地启发式，不调 AI）

enum ReadmeParser {

    // 清理：去代码块 / HTML / 图片链接 / 行内链接 / 引用符 / 表格分隔 / 强调符号
    static func clean(_ raw: String) -> String {
        var s = raw
        s = s.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^)]*\\)", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?m)^>\\s?", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?m)^\\|[-:\\s|]+\\|$", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "**", with: "")
        s = s.replacingOccurrences(of: "__", with: "")
        s = s.replacingOccurrences(of: "`", with: "")
        return s
    }

    static func parse(_ raw: String, productName: String? = nil) -> ReadmeResult {
        let text = clean(raw)
        let lines = text.components(separatedBy: "\n")

        // 标题（首个 # 标题）：banqiu 双语模板格式 「英文仓库名 / 中文名」
        var headingLine = ""
        for l in lines {
            let t = l.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("#") {
                headingLine = t.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                                 .trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // name：GitHub URL 入口优先用 repo 段（最准）；否则从标题 / 拆分
        // headingSub：标题 / 后的中文名（作为 subtitle 候选）
        var name = "App"
        var headingSub = ""
        if !headingLine.isEmpty {
            if let range = headingLine.range(of: " / ") {
                name = String(headingLine[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                headingSub = String(headingLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else if let slash = headingLine.firstIndex(of: "/") {
                name = String(headingLine[..<slash]).trimmingCharacters(in: .whitespaces)
                headingSub = String(headingLine[headingLine.index(after: slash)...]).trimmingCharacters(in: .whitespaces)
            } else {
                name = headingLine
            }
        }
        if let pn = productName, !pn.isEmpty { name = pn }

        // 找 features 段索引
        var featIdx = -1
        for (i, l) in lines.enumerated() {
            let t = l.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("#") {
                let h = t.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces).lowercased()
                if h.contains("feature") || h.contains("功能") || h.contains("特性")
                    || h.contains("特点") || h.contains("highlights") || h.contains("亮点") {
                    featIdx = i
                    break
                }
            }
        }

        // 收集描述段落 + features 列表项
        var paras: [String] = []
        var listItems: [String] = []
        var curPara: [String] = []
        var inFeat = false

        func flush() {
            if !curPara.isEmpty {
                let p = curPara.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !p.isEmpty { paras.append(p) }
                curPara = []
            }
        }

        for (i, l) in lines.enumerated() {
            let t = l.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { flush(); continue }
            if t.hasPrefix("#") {
                flush()
                if i == featIdx { inFeat = true }
                else if inFeat && i > featIdx { inFeat = false }
                continue
            }
            if inFeat {
                if let m = t.range(of: "^(?:[-*+]\\s+|\\d+[.)]\\s+)", options: .regularExpression) {
                    let item = String(t[m.upperBound...]).trimmingCharacters(in: .whitespaces)
                    let c = cleanListItem(item)
                    if !c.isEmpty { listItems.append(c) }
                }
                continue
            }
            if t.hasPrefix("|") { flush(); continue }
            curPara.append(t)
        }
        flush()

        // subtitle / tagline：先过滤掉元数据段（作者/许可证/版本等）
        let descParas = paras.filter { !Self.isMetaParagraph($0) }
        let skippedMeta = paras.count - descParas.count

        var subtitle = ""
        var tagline = ""
        let truncated = 0   // 解析层不再截断文案（交由画布层处理），此处恒为 0

        if !headingSub.isEmpty {
            // —— 双语模板路径：subtitle=标题里的中文名，tagline=首段 / 前的中文描述（全量，画布层负责截断）——
            subtitle = headingSub
            if let first = descParas.first {
                let cn = (first.components(separatedBy: "/").first ?? first)
                            .trimmingCharacters(in: .whitespaces)
                tagline = cn
            }
        } else if descParas.isEmpty {
            // 没有描述段，留空
        } else if descParas.count == 1 {
            subtitle = descParas[0]
            // 单段尝试按句号拆出剩余句作为 tagline
            let parts = descParas[0].components(separatedBy: CharacterSet(charactersIn: "。.!?；;"))
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if parts.count >= 2 {
                tagline = parts.dropFirst().joined(separator: " ")
            }
        } else {
            subtitle = descParas[0]
            tagline = descParas[1]
        }

        // tags：features 列表项 > 描述段拆词（保留完整文字，不截断；UI 可编辑区全量展示）
        var tags = listItems
        if tags.isEmpty {
            let words = subtitle.components(separatedBy: CharacterSet(charactersIn: "、,，·|/"))
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            tags = Array(words.prefix(3))
        }

        return ReadmeResult(name: name, subtitle: subtitle, tagline: tagline, tags: tags,
                            skippedMeta: skippedMeta, truncated: truncated)
    }

    private static func cleanListItem(_ s: String) -> String {
        var r = s
        r = r.replacingOccurrences(of: "**", with: "")
        r = r.replacingOccurrences(of: "__", with: "")
        r = r.replacingOccurrences(of: "`", with: "")
        r = r.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
        return r.trimmingCharacters(in: .whitespaces)
    }

    private static func truncate(_ s: String, max: Int) -> String {
        if s.count <= max { return s }
        return String(s.prefix(max)) + "…"
    }

    // 元数据段黑名单：以这些词开头的段落视为「作者 / 许可证 / 版本 / 徽章」等非卖点信息，解析时跳过
    private static let metadataSkipPrefixes = [
        "作者", "author", "许可证", "license", "version", "版本",
        "demo", "演示", "screenshot", "截图", "badge", "徽章",
        "toc", "目录", "english", "中文", "language", "语言"
    ]

    /// 判断段是否元数据段（clean 后仍以黑名单词开头）
    private static func isMetaParagraph(_ s: String) -> Bool {
        let lower = s.trimmingCharacters(in: .whitespaces).lowercased()
        return metadataSkipPrefixes.contains { lower.hasPrefix($0) }
    }

    /// 把任意长段整理成适合宽度的短句：按语义断句符切分，优先取第一句（最可能是作者想表达的完整副标题），仍超则硬截 + …
    private static func fit(_ s: String, max: Int) -> (text: String, truncated: Bool) {
        if s.count <= max { return (s, false) }
        let parts = s.components(separatedBy: CharacterSet(charactersIn: "。.!?；;\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let first = parts.first, first.count <= max {
            return (first, false)
        }
        return (String(s.prefix(max)) + "…", true)
    }

    // MARK: - 远程抓取

    /// 把 GitHub 网页 URL / 仓库标识转成可尝试的 raw URL 列表
    static func rawCandidates(for input: String) -> [URL] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("https://raw.githubusercontent.com/"),
           let u = URL(string: trimmed) { return [u] }
        if let u = URL(string: trimmed), let host = u.host, host == "github.com" {
            let comps = u.pathComponents.filter { $0 != "/" }
            if comps.count >= 2 {
                let owner = comps[0], repo = comps[1]
                let branches = ["main", "master"]
                let names = ["README.md", "readme.md", "README.markdown", "readme.markdown", "README.rst"]
                var out: [URL] = []
                for b in branches {
                    for n in names {
                        if let c = URL(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/\(b)/\(n)") {
                            out.append(c)
                        }
                    }
                }
                return out
            }
        }
        return []
    }

    /// 仓库 raw 基址（用于把相对图片路径解析成绝对 URL）
    static func rawBase(for input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let u = URL(string: trimmed), let host = u.host, host == "github.com" {
            let comps = u.pathComponents.filter { $0 != "/" }
            if comps.count >= 2 {
                return "https://raw.githubusercontent.com/\(comps[0])/\(comps[1])/main"
            }
        }
        return nil
    }

    static func fetchMarkdown(_ input: String, completion: @escaping (Result<String, Error>) -> Void) {
        let candidates = rawCandidates(for: input)
        guard !candidates.isEmpty else {
            completion(.failure(NSError(domain: "ReadmeParser", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法识别的链接，仅支持 GitHub 仓库 URL 或直接 raw URL"])))
            return
        }
        func tryNext(_ idx: Int) {
            if idx >= candidates.count {
                completion(.failure(NSError(domain: "ReadmeParser", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "找不到 README（已尝试 main/master 分支常见文件名）"])))
                return
            }
            let url = candidates[idx]
            URLSession.shared.dataTask(with: url) { data, resp, err in
                if err != nil { tryNext(idx + 1); return }
                guard let data = data,
                      let txt = String(data: data, encoding: .utf8),
                      !txt.isEmpty,
                      (resp as? HTTPURLResponse)?.statusCode == 200 else {
                    tryNext(idx + 1); return
                }
                completion(.success(txt))
            }.resume()
        }
        tryNext(0)
    }

    /// 从 README 原文提取第一个图片链接（Markdown 或 HTML）
    static func extractImageURL(_ raw: String) -> String? {
        if let m = raw.range(of: "!\\[[^\\]]*\\]\\(([^)]+)\\)", options: .regularExpression) {
            let inner = String(raw[m])
            if let u = inner.range(of: "\\(([^)]+)\\)", options: .regularExpression) {
                return String(inner[u]).trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            }
        }
        if let m = raw.range(of: "<img[^>]+src=[\"']([^\"']+)[\"']", options: .regularExpression) {
            let inner = String(raw[m])
            if let u = inner.range(of: "src=[\"']([^\"']+)[\"']", options: .regularExpression) {
                let s = String(inner[u])
                return s.replacingOccurrences(of: "src=[\"']", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "[\"']$", with: "", options: .regularExpression)
            }
        }
        return nil
    }

    /// 把相对图片路径解析为绝对 URL（基于仓库 raw base）
    static func resolveImageURL(_ img: String, rawBase: String?) -> String? {
        if img.hasPrefix("http://") || img.hasPrefix("https://") { return img }
        guard let base = rawBase else { return nil }
        if img.hasPrefix("/") {
            if let r = base.range(of: "/main$", options: .regularExpression) {
                return String(base[..<r.lowerBound]) + img
            }
            return base + img
        }
        return base.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + img
    }

    static func fetchImage(_ urlString: String, completion: @escaping (NSImage?) -> Void) {
        guard let u = URL(string: urlString) else { completion(nil); return }
        URLSession.shared.dataTask(with: u) { data, _, _ in
            if let data = data, let img = NSImage(data: data) {
                completion(img)
            } else {
                completion(nil)
            }
        }.resume()
    }
}
