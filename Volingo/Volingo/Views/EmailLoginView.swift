//
//  EmailLoginView.swift
//  海豹英语
//
//  统一注册/登录：邮箱 → 验证码（无密码）
//

import SwiftUI

// MARK: - ViewModel

@MainActor
final class EmailLoginViewModel: ObservableObject {
    enum Step { case emailInput, verifyCode }

    @Published var step: Step = .emailInput
    @Published var email = ""
    @Published var code = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLoginComplete = false

    private let authManager = AuthManager.shared

    var isValidEmail: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }

    var canVerifyCode: Bool {
        code.count == 6
    }

    // MARK: - Actions

    /// 输入邮箱后直接发送验证码
    func proceedWithEmail() {
        guard isValidEmail else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authManager.sendLoginCode(email: email)
                withAnimation(.easeInOut(duration: 0.2)) {
                    step = .verifyCode
                }
            } catch {
                errorMessage = parseError(error)
            }
            isLoading = false
        }
    }

    func verifyLoginCode() {
        guard canVerifyCode else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authManager.verifyLoginCode(email: email, code: code)
                isLoginComplete = true
            } catch {
                errorMessage = parseError(error)
            }
            isLoading = false
        }
    }

    func resendCode() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authManager.sendLoginCode(email: email)
                errorMessage = nil
            } catch {
                errorMessage = parseError(error)
            }
            isLoading = false
        }
    }

    func goBackToEmail() {
        withAnimation(.easeInOut(duration: 0.2)) {
            step = .emailInput
            code = ""
            errorMessage = nil
        }
    }

    private func parseError(_ error: Error) -> String {
        if let apiErr = error as? APIServiceError {
            return apiErr.localizedChineseMessage
        }
        return "请求失败，请稍后重试"
    }
}

// MARK: - View

struct EmailLoginView: View {
    @StateObject private var vm = EmailLoginViewModel()
    @Environment(\.dismiss) private var dismiss
    var onLoginSuccess: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Branding
                    VStack(spacing: 10) {
                        Text("🦭")
                            .font(.system(size: 56))
                        Text("海豹英语")
                            .font(.system(size: 24, weight: .bold))
                    }
                    .padding(.top, 28)

                    switch vm.step {
                    case .emailInput:
                        emailStepView
                    case .verifyCode:
                        codeStepView
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("注册 / 登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onChange(of: vm.isLoginComplete) { _, completed in
                if completed {
                    dismiss()
                    onLoginSuccess?()
                }
            }
        }
    }

    // MARK: - Step 1: Email

    private var emailStepView: some View {
        VStack(spacing: 16) {
            Text("输入你的邮箱")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.secondary)

            TextField("邮箱地址", text: $vm.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(size: 16))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .onSubmit { vm.proceedWithEmail() }

            Button(action: vm.proceedWithEmail) {
                if vm.isLoading {
                    ProgressView()
                        .tint(.white)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(white: 0.18))
                        .cornerRadius(14)
                } else {
                    Text("发送验证码")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(vm.isValidEmail ? Color(white: 0.18) : Color.gray.opacity(0.3))
                        .cornerRadius(14)
                }
            }
            .disabled(!vm.isValidEmail || vm.isLoading)

            Text("新邮箱将自动注册账号")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    // MARK: - Step 2: Verify Code

    private var codeStepView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("验证码已发送至")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                Text(vm.email)
                    .font(.system(size: 16, weight: .semibold))
            }

            TextField("请输入 6 位验证码", text: $vm.code)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .onChange(of: vm.code) { _, newValue in
                    let filtered = String(newValue.filter(\.isNumber).prefix(6))
                    if filtered != newValue { vm.code = filtered }
                }

            Button(action: vm.verifyLoginCode) {
                actionButtonContent(text: "确认")
            }
            .disabled(!vm.canVerifyCode || vm.isLoading)

            HStack(spacing: 16) {
                Button("重新发送", action: vm.resendCode)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .disabled(vm.isLoading)

                Button("返回", action: vm.goBackToEmail)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    // MARK: - Helpers

    private func actionButtonContent(text: String) -> some View {
        Group {
            if vm.isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(text)
            }
        }
        .font(.system(size: 17, weight: .bold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color(white: 0.18))
        .cornerRadius(14)
    }
}

#Preview {
    EmailLoginView()
}
