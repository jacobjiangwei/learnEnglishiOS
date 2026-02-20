//
//  ToastView.swift
//  Volingo
//
//  全局 Toast 组件 — 仿 Apple HUD 风格
//  支持 success / error / info 三种样式
//  用法: .toast(item: $toastItem)
//

import SwiftUI

// MARK: - Toast 数据模型

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let style: ToastStyle
    let title: String
    var subtitle: String? = nil
    /// 自动消失时间（秒），nil 表示手动关闭
    var duration: Double? = nil
    
    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum ToastStyle {
    case success
    case error
    case info
    case warning
    
    var icon: String {
        switch self {
        case .success:  return "checkmark.circle.fill"
        case .error:    return "xmark.circle.fill"
        case .info:     return "info.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success:  return .green
        case .error:    return .red
        case .info:     return .blue
        case .warning:  return .orange
        }
    }
    
    /// 默认自动消失时间
    var defaultDuration: Double? {
        switch self {
        case .success:  return 1.2
        case .error:    return nil   // 错误不自动消失
        case .info:     return 2.0
        case .warning:  return 2.5
        }
    }
}

// MARK: - Toast 视图

struct ToastView: View {
    let item: ToastItem
    
    /// 居中 HUD 样式（成功/信息/警告）
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: item.style.icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(item.style.color)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }
}

// MARK: - Toast ViewModifier

struct ToastModifier: ViewModifier {
    @Binding var item: ToastItem?
    var onDismiss: (() -> Void)?
    
    @State private var isPresented = false
    @State private var dismissTask: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented, let toast = item {
                    ZStack {
                        // 半透明背景（仅阻止交互）
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture {
                                // 点击任意位置关闭（如果是自动消失类型可选）
                                if toast.style == .error || toast.style == .warning {
                                    dismiss()
                                }
                            }
                        
                        ToastView(item: toast)
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.7)
                                        .combined(with: .opacity),
                                    removal: .scale(scale: 0.9)
                                        .combined(with: .opacity)
                                )
                            )
                    }
                }
            }
            .onChange(of: item) { _, newValue in
                if let toast = newValue {
                    show(toast)
                } else {
                    dismiss()
                }
            }
    }
    
    private func show(_ toast: ToastItem) {
        dismissTask?.cancel()
        
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            isPresented = true
        }
        
        // 触觉反馈
        let generator = UINotificationFeedbackGenerator()
        switch toast.style {
        case .success: generator.notificationOccurred(.success)
        case .error:   generator.notificationOccurred(.error)
        case .warning: generator.notificationOccurred(.warning)
        case .info:    break
        }
        
        // 自动消失
        let duration = toast.duration ?? toast.style.defaultDuration
        if let duration {
            dismissTask = Task {
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                await MainActor.run { dismiss() }
            }
        }
    }
    
    private func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(duration: 0.25, bounce: 0)) {
            isPresented = false
        }
        // 延迟清理，让动画完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            item = nil
            onDismiss?()
        }
    }
}

// MARK: - 底部结果横幅（答错时显示正确答案 + 继续按钮）

struct BottomResultBanner: View {
    let style: ToastStyle
    let title: String
    var detail: String? = nil
    let buttonTitle: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 遮罩
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture {} // 吞掉点击
            
            // 底部面板
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: style.icon)
                        .font(.title2)
                        .foregroundColor(style.color)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(style.color)
                }
                
                if let detail {
                    Text(detail)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: onDismiss) {
                    Text(buttonTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(14)
                }
            }
            .padding(24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct BottomResultBannerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let style: ToastStyle
    let title: String
    var detail: String?
    var buttonTitle: String = "继续"
    var onDismiss: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isPresented)
            .overlay {
                if isPresented {
                    BottomResultBanner(
                        style: style,
                        title: title,
                        detail: detail,
                        buttonTitle: buttonTitle
                    ) {
                        withAnimation(.spring(duration: 0.25)) {
                            isPresented = false
                        }
                        onDismiss?()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// 居中 HUD Toast（成功/信息/警告自动消失，错误手动关闭）
    func toast(item: Binding<ToastItem?>, onDismiss: (() -> Void)? = nil) -> some View {
        modifier(ToastModifier(item: item, onDismiss: onDismiss))
    }
    
    /// 底部结果横幅（需用户点击按钮关闭）
    func bottomBanner(
        isPresented: Binding<Bool>,
        style: ToastStyle,
        title: String,
        detail: String? = nil,
        buttonTitle: String = "继续",
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(BottomResultBannerModifier(
            isPresented: isPresented,
            style: style,
            title: title,
            detail: detail,
            buttonTitle: buttonTitle,
            onDismiss: onDismiss
        ))
    }
}
