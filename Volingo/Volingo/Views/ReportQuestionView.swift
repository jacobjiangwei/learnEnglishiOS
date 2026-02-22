//
//  ReportQuestionView.swift
//  Volingo
//
//  举报错题组件：在任何练习界面都可以使用
//

import SwiftUI

// MARK: - PreferenceKey：子视图上报当前题目 ID，父视图统一渲染举报按钮

struct ReportableQuestionKey: PreferenceKey {
    static var defaultValue: String? = nil
    static func reduce(value: inout String?, nextValue: () -> String?) {
        value = nextValue() ?? value
    }
}

extension View {
    /// 将当前题目 ID 上报给父视图（PracticeRouterView 读取后统一放举报按钮）
    func reportableQuestion(id: String?) -> some View {
        preference(key: ReportableQuestionKey.self, value: id)
    }
}

// MARK: - 举报原因

enum ReportReason: String, CaseIterable, Identifiable {
    case wrongAnswer    = "答案错误"
    case badQuestion    = "题目不合理"
    case unclear        = "题意不清"
    case wrongLevel     = "难度不匹配"
    case typo           = "拼写/语法错误"
    case other          = "其他"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .wrongAnswer:  return "xmark.circle"
        case .badQuestion:  return "hand.thumbsdown"
        case .unclear:      return "questionmark.circle"
        case .wrongLevel:   return "chart.bar"
        case .typo:         return "textformat.abc"
        case .other:        return "ellipsis.circle"
        }
    }
}

// MARK: - 举报按钮（工具栏使用）

struct ReportQuestionButton: View {
    let questionId: String
    let questionType: String?
    @State private var showReportSheet = false
    @State private var submitted = false

    var body: some View {
        Button {
            if !submitted {
                showReportSheet = true
            }
        } label: {
            Image(systemName: submitted ? "flag.fill" : "flag")
                .font(.body)
                .foregroundColor(submitted ? .red : .primary)
        }
        .accessibilityLabel(submitted ? "已举报" : "举报此题")
        .sheet(isPresented: $showReportSheet) {
            ReportQuestionSheet(
                questionId: questionId,
                questionType: questionType,
                isPresented: $showReportSheet,
                didSubmit: $submitted
            )
        }
        .onChange(of: questionId) { _ in
            submitted = false
        }
    }
}

// MARK: - 举报表单 Sheet

struct ReportQuestionSheet: View {
    let questionId: String
    let questionType: String?
    @Binding var isPresented: Bool
    @Binding var didSubmit: Bool

    @State private var selectedReason: ReportReason? = nil
    @State private var additionalDescription = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if showSuccess {
                    successView
                } else {
                    reportForm
                }
            }
            .padding()
            .navigationTitle("举报错题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 举报表单

    private var reportForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("这道题有什么问题？")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(ReportReason.allCases) { reason in
                    Button {
                        selectedReason = reason
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: reason.icon)
                                .font(.subheadline)
                            Text(reason.rawValue)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedReason == reason ? Color.red.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                        .foregroundColor(selectedReason == reason ? .red : .primary)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedReason == reason ? Color.red : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("补充说明（可选）")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("描述具体问题…", text: $additionalDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            Spacer()

            Button {
                submitReport()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("提交举报")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedReason != nil ? Color.red : Color.gray)
                .cornerRadius(12)
            }
            .disabled(selectedReason == nil || isSubmitting)
        }
    }

    // MARK: - 提交成功

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("举报已提交")
                .font(.title2.bold())
            Text("感谢反馈，我们会尽快审核处理")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button("关闭") {
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 提交逻辑

    private func submitReport() {
        guard let reason = selectedReason else { return }
        isSubmitting = true

        Task {
            do {
                _ = try await APIService.shared.reportQuestion(
                    questionId: questionId,
                    reason: reason.rawValue,
                    description: additionalDescription.isEmpty ? nil : additionalDescription,
                    questionType: questionType
                )
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                    didSubmit = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                    didSubmit = true
                }
                #if DEBUG
                print("[Report] ❌ 举报失败: \(error)")
                #endif
            }
        }
    }
}

#Preview {
    ReportQuestionSheet(
        questionId: "preview-123",
        questionType: "cloze",
        isPresented: .constant(true),
        didSubmit: .constant(false)
    )
}
