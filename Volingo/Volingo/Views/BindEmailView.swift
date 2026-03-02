//
//  BindEmailView.swift
//  海豹英语
//
//  绑定邮箱流程：输入邮箱 → 发送验证码 → 输入验证码 → 完成
//  已绑定：显示邮箱 + 退出邮箱登录
//

import SwiftUI

// MARK: - ViewModel

@MainActor
final class BindEmailViewModel: ObservableObject {
    enum Step { case inputEmail, inputCode }

    @Published var step: Step = .inputEmail
    @Published var email = ""
    @Published var code = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isComplete = false
    @Published var showLogoutConfirm = false

    private let authManager = AuthManager.shared

    var isBound: Bool {
        authManager.currentUser?.isEmailUser == true
    }

    var boundEmail: String? {
        authManager.currentUser?.email
    }

    var canSendCode: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }

    var canVerify: Bool {
        code.count == 6
    }

    func sendCode() {
        guard canSendCode else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authManager.bindEmail(email: email)
                withAnimation(.easeInOut(duration: 0.2)) {
                    step = .inputCode
                }
            } catch {
                errorMessage = (error as? APIServiceError)?.localizedChineseMessage ?? "请求失败，请稍后重试"
            }
            isLoading = false
        }
    }

    func verify() {
        guard canVerify else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authManager.verifyEmailBinding(code: code)
                isComplete = true
            } catch {
                errorMessage = (error as? APIServiceError)?.localizedChineseMessage ?? "请求失败，请稍后重试"
            }
            isLoading = false
        }
    }

    func resendCode() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authManager.bindEmail(email: email)
                errorMessage = nil
            } catch {
                errorMessage = (error as? APIServiceError)?.localizedChineseMessage ?? "请求失败，请稍后重试"
            }
            isLoading = false
        }
    }

    func emailLogout() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await authManager.emailLogout()
                isComplete = true
            } catch {
                errorMessage = (error as? APIServiceError)?.localizedChineseMessage ?? "请求失败，请稍后重试"
            }
            isLoading = false
        }
    }
}

// MARK: - View

struct BindEmailView: View {
    @StateObject private var vm = BindEmailViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header illustration
                    Image(systemName: vm.isBound ? "envelope.badge.shield.half.filled.fill" : "envelope.badge.shield.half.filled")
                        .font(.system(size: 56))
                        .foregroundStyle(vm.isBound ? .green : .blue)
                        .padding(.top, 20)

                    if vm.isBound {
                        boundEmailSection
                    } else if vm.step == .inputEmail {
                        emailInputSection
                    } else {
                        codeInputSection
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle(vm.isBound ? "邮箱管理" : (vm.step == .inputEmail ? "绑定邮箱" : "验证邮箱"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: vm.isComplete) { _, completed in
                if completed { dismiss() }
            }
            .alert("退出邮箱登录", isPresented: $vm.showLogoutConfirm) {
                Button("取消", role: .cancel) { }
                Button("确认退出", role: .destructive) { vm.emailLogout() }
            } message: {
                Text("退出后将变为匿名用户，再次绑定此邮箱可恢复数据。确定退出吗？")
            }
        }
    }

    // MARK: - Bound Email

    private var boundEmailSection: some View {
        VStack(spacing: 20) {
            Text("已绑定邮箱")
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            Text(vm.boundEmail ?? "")
                .font(.system(size: 18, weight: .semibold))

            Text("你可以使用此邮箱在其他设备上登录")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical, 8)

            Button(role: .destructive) {
                vm.showLogoutConfirm = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("退出邮箱登录")
                }
                .font(.system(size: 16))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            .disabled(vm.isLoading)
        }
    }

    // MARK: - Email Input

    private var emailInputSection: some View {
        VStack(spacing: 16) {
            Text("绑定邮箱后，可以在其他设备上登录你的账号")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField("邮箱地址", text: $vm.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            Button(action: vm.sendCode) {
                Group {
                    if vm.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("发送验证码")
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(vm.canSendCode ? Color.blue : Color.gray.opacity(0.4))
                .cornerRadius(12)
            }
            .disabled(!vm.canSendCode || vm.isLoading)
        }
    }

    // MARK: - Code Input

    private var codeInputSection: some View {
        VStack(spacing: 16) {
            Text("验证码已发送至")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            Text(vm.email)
                .font(.system(size: 16, weight: .semibold))

            TextField("请输入6位验证码", text: $vm.code)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .onChange(of: vm.code) { _, newValue in
                    let filtered = String(newValue.filter(\.isNumber).prefix(6))
                    if filtered != newValue { vm.code = filtered }
                }

            Button(action: vm.verify) {
                Group {
                    if vm.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("确认绑定")
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(vm.canVerify ? Color.blue : Color.gray.opacity(0.4))
                .cornerRadius(12)
            }
            .disabled(!vm.canVerify || vm.isLoading)

            Button("重新发送验证码", action: vm.resendCode)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .disabled(vm.isLoading)
        }
    }
}

#Preview {
    BindEmailView()
}
