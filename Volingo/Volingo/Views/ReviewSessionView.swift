//
//  ReviewSessionView.swift
//  Volingo
//
//  全屏沉浸式复习 Session
//

import SwiftUI

// MARK: - 复习 Session 主视图
struct ReviewSessionView: View {
    @StateObject private var viewModel = ReviewSessionViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            switch viewModel.state {
            case .loading:
                ProgressView("准备复习...")
                
            case .question:
                questionContent
                
            case .completed:
                SessionCompletionView(results: viewModel.sessionResults) {
                    dismiss()
                }
            }
        }
        .toast(item: $viewModel.toastItem) {
            viewModel.onCorrectToastDismissed()
        }
        .bottomBanner(
            isPresented: $viewModel.showWrongAnswer,
            style: .error,
            title: "答错了",
            detail: "正确答案: \(viewModel.lastCorrectAnswer)"
        ) {
            viewModel.dismissWrongAndContinue()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("退出") { dismiss() }
                    .foregroundColor(.secondary)
            }
            if viewModel.state == .question {
                ToolbarItem(placement: .principal) {
                    Text(viewModel.progressText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            viewModel.startSession()
        }
    }
    
    // MARK: - 题目分发
    
    @ViewBuilder
    private var questionContent: some View {
        if let question = viewModel.currentQuestion {
            VStack(spacing: 0) {
                // 进度条
                ProgressView(value: viewModel.progress)
                    .tint(.blue)
                    .padding(.horizontal)
                
                Spacer()
                
                // 根据题型显示不同视图
                Group {
                    switch question.type {
                    case .engToChMCQ:
                        if let q = question as? ReviewMCQQuestion {
                            EngToChMCQView(question: q) { selected in
                                viewModel.answerMCQ(selected: selected)
                            }
                        }
                    case .chToEngMCQ:
                        if let q = question as? ReviewMCQQuestion {
                            ChToEngMCQView(question: q) { selected in
                                viewModel.answerMCQ(selected: selected)
                            }
                        }
                    case .clozeFill:
                        if let q = question as? ReviewClozeQuestion {
                            ClozeFillView(question: q) { typed in
                                viewModel.answerCloze(typed: typed)
                            }
                        }
                    case .listenSpell:
                        if let q = question as? ReviewSpellQuestion {
                            ListenSpellView(question: q) { typed in
                                viewModel.answerSpell(typed: typed)
                            }
                        }
                    case .matching:
                        if question is ReviewMatchingQuestion {
                            MatchingGameView(viewModel: viewModel)
                                .onAppear { viewModel.setupMatching() }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
    
}

// MARK: - 英选中 (看英文选中文)
struct EngToChMCQView: View {
    let question: ReviewMCQQuestion
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Text(question.prompt)
                .font(.system(size: 36, weight: .bold))
            
            Text("选择正确的中文释义")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ForEach(question.options, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        Text(option)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 中选英 (看中文选英文)
struct ChToEngMCQView: View {
    let question: ReviewMCQQuestion
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Text(question.prompt)
                .font(.system(size: 28, weight: .bold))
            
            Text("选择对应的英文单词")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ForEach(question.options, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        Text(option)
                            .font(.title3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 例句填空
struct ClozeFillView: View {
    let question: ReviewClozeQuestion
    let onSubmit: (String) -> Void
    
    @State private var typed = ""
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Text("完成句子")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(question.sentence)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            
            Text(question.translation)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("输入单词...", text: $typed)
                .font(.title2)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .onSubmit {
                    if !typed.isEmpty { onSubmit(typed) }
                }
            
            Button {
                if !typed.isEmpty { onSubmit(typed) }
            } label: {
                Text("确认")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(typed.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(14)
            }
            .disabled(typed.isEmpty)
        }
        .onAppear { focused = true }
    }
}

// MARK: - 听音拼写
struct ListenSpellView: View {
    let question: ReviewSpellQuestion
    let onSubmit: (String) -> Void
    
    @State private var typed = ""
    @FocusState private var focused: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            Text("听音拼写")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button {
                AudioService.shared.playWordPronunciation(question.wordToSpell)
            } label: {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.blue)
                    .padding(24)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Text("请拼写你听到的单词")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("输入单词...", text: $typed)
                .font(.title2)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.asciiCapable)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .onSubmit {
                    if !typed.isEmpty { onSubmit(typed) }
                }
            
            Button {
                if !typed.isEmpty { onSubmit(typed) }
            } label: {
                Text("确认")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(typed.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(14)
            }
            .disabled(typed.isEmpty)
        }
        .onAppear {
            focused = true
            // 自动播放一次
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AudioService.shared.playWordPronunciation(question.wordToSpell)
            }
        }
    }
}

// MARK: - 连线消消乐
struct MatchingGameView: View {
    @ObservedObject var viewModel: ReviewSessionViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("连线配对")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if viewModel.matchingRemainingPairs.isEmpty {
                // 全部消除
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("全部配对成功!")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            } else {
                HStack(spacing: 24) {
                    // 左侧：英文
                    VStack(spacing: 12) {
                        ForEach(viewModel.matchingRemainingPairs, id: \.english) { pair in
                            MatchingButton(
                                text: pair.english,
                                isSelected: viewModel.matchingSelectedEnglish == pair.english,
                                isError: viewModel.matchingErrorFlash && viewModel.matchingSelectedEnglish == pair.english
                            ) {
                                viewModel.selectMatchingEnglish(pair.english)
                            }
                        }
                    }
                    
                    // 右侧：中文
                    VStack(spacing: 12) {
                        ForEach(viewModel.matchingShuffledChinese, id: \.self) { ch in
                            MatchingButton(
                                text: ch,
                                isSelected: viewModel.matchingSelectedChinese == ch,
                                isError: viewModel.matchingErrorFlash && viewModel.matchingSelectedChinese == ch
                            ) {
                                viewModel.selectMatchingChinese(ch)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct MatchingButton: View {
    let text: String
    let isSelected: Bool
    let isError: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .background(
                    isError ? Color.red.opacity(0.2) :
                    isSelected ? Color.blue.opacity(0.15) :
                    Color(.systemBackground)
                )
                .foregroundColor(
                    isError ? .red :
                    isSelected ? .blue :
                    .primary
                )
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isError ? Color.red :
                            isSelected ? Color.blue :
                            Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isError)
    }
}

// MARK: - Session 完成页
struct SessionCompletionView: View {
    let results: SessionResults
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundColor(.yellow)
            
            Text("复习完成!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 统计
            VStack(spacing: 16) {
                HStack {
                    StatBubble(title: "复习", value: "\(results.totalWords) 个词", color: .blue)
                    StatBubble(title: "用时", value: results.durationText, color: .purple)
                }
                HStack {
                    StatBubble(title: "正确", value: "\(results.correctCount)", color: .green)
                    StatBubble(title: "错误", value: "\(results.wrongCount)", color: .red)
                }
                
                // 正确率
                let pct = Int(results.accuracy * 100)
                Text("正确率 \(pct)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(pct >= 80 ? .green : pct >= 60 ? .orange : .red)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            .padding(.horizontal)
            
            Spacer()
            
            Button {
                onClose()
            } label: {
                Text("返回生词本")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

struct StatBubble: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        ReviewSessionView()
    }
}
