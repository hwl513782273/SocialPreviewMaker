import SwiftUI
import AppKit

struct AboutView: View {
    let version: String

    var body: some View {
        VStack(spacing: 0) {
            // 图标居中置顶
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.bottom, 14)
            }

            // 名称 + 版本（居中）
            Text("SocialPreviewMaker")
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)

            Text("版本 \(version)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 5)

            Divider()
                .padding(.horizontal, 60)
                .padding(.vertical, 16)

            // 功能简介（居中）
            Text("""
            由模板拆解到批量生成的社交预览图工具。
            拖入 App 图标 → 自动采色 → 实时预览 → 导出 1280×640 PNG。
            纯系统字体，零依赖，开箱即用。
            """)
            .font(.system(size: 13))
            .lineSpacing(6)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.horizontal, 60)
                .padding(.vertical, 16)

            // 版权（居中）
            Text("Copyright © 2026 banqiu. Released under the MIT License.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(width: 420)
    }
}
