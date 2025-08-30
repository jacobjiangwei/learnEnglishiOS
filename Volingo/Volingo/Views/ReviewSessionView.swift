//
//  ReviewSessionView.swift
//  Volingo
//
//  Created by jacob on 2025/8/30.
//

import SwiftUI

// MARK: - 复习难度枚举
enum ReviewDifficultyLevel: String, CaseIterable {
    case multiple = "选择题"
    case typing = "输入题"
    
    var description: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .multiple: return "checkmark.circle"
        case .typing: return "pencil.circle"
        }
    }
}

struct ReviewSessionView: View {
    let words: [SavedWord]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ReviewSessionViewModel
    @State private var selectedDifficulty: ReviewDifficultyLevel = .multiple
    @State private var showingDifficultySelection = true
    
    init(words: [SavedWord]) {
        self.words = words
        self._viewModel = StateObject(wrappedValue: ReviewSessionViewModel(words: words))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if showingDifficultySelection {
                    // 难度选择界面
                    DifficultySelectionView(
                        selectedDifficulty: $selectedDifficulty,
                        wordsCount: words.count,
                        onStart: {
                            showingDifficultySelection = false
                            viewModel.startReview()
                        }
                    )
                } else if viewModel.isLoading {
                    VStack {
                        ProgressView()
                        Text("准备复习...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.hasWords {
                    // 复习进度条
                    ReviewProgressView(
                        current: viewModel.currentIndex + 1,
                        total: viewModel.totalWords
                    )
                    .padding()
                    
                    // 复习卡片
                    ReviewCardView(
                        word: viewModel.currentWord!,
                        difficulty: selectedDifficulty,
                        onAnswer: { isCorrect in
                            viewModel.answerCurrentWord(isCorrect: isCorrect)
                        }
                    )
                    .id(viewModel.currentWord!.id) // 添加id确保单词变化时重新创建视图
                    .padding()
                    
                    Spacer()
                    
                    // 控制按钮
                    ReviewControlButtons(
                        onSkip: { viewModel.skipCurrentWord() },
                        onNext: { viewModel.moveToNext() },
                        canSkip: true,
                        canNext: viewModel.hasAnswered
                    )
                    .padding()
                } else {
                    // 复习完成
                    ReviewCompletionView(
                        results: viewModel.reviewResults,
                        onRestart: { viewModel.restart() },
                        onClose: { dismiss() }
                    )
                }
            }
            .navigationTitle(showingDifficultySelection ? "选择难度" : "复习")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                if !showingDifficultySelection && viewModel.hasWords {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("\(viewModel.currentIndex + 1)/\(viewModel.totalWords)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            // 不在这里自动开始，等待用户选择难度
        }
    }
}

// MARK: - 难度选择界面
struct DifficultySelectionView: View {
    @Binding var selectedDifficulty: ReviewDifficultyLevel
    let wordsCount: Int
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("选择复习难度")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("准备复习 \(wordsCount) 个单词")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                ForEach(ReviewDifficultyLevel.allCases, id: \.self) { difficulty in
                    DifficultyOptionCard(
                        difficulty: difficulty,
                        isSelected: selectedDifficulty == difficulty,
                        onSelect: { selectedDifficulty = difficulty }
                    )
                }
            }
            
            Spacer()
            
            Button("开始复习") {
                onStart()
            }
            .buttonStyle(.borderedProminent)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - 难度选项卡片
struct DifficultyOptionCard: View {
    let difficulty: ReviewDifficultyLevel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: difficulty.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.description)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(getDescription(for: difficulty))
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func getDescription(for difficulty: ReviewDifficultyLevel) -> String {
        switch difficulty {
        case .multiple:
            return "看例句和音标，从4个选项中选择正确的单词"
        case .typing:
            return "看例句和音标，输入正确的单词拼写"
        }
    }
}

// MARK: - 复习进度条
struct ReviewProgressView: View {
    let current: Int
    let total: Int
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("复习进度")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(current)/\(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
    }
}

// MARK: - 复习卡片
struct ReviewCardView: View {
    let word: SavedWord
    let difficulty: ReviewDifficultyLevel
    let onAnswer: (Bool) -> Void
    
    @State private var showAnswer = false
    @State private var selectedAnswer: String?
    @State private var typedAnswer: String = ""
    @State private var showFeedback = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 单词卡片（不显示答案）
            VStack(spacing: 16) {
                // 不显示单词，只显示音标
                if let phonetic = word.word.phonetic {
                    VStack(spacing: 8) {
                        Text("发音:")
                            .font(.headline)
                        Text(phonetic)
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // 中文释义
                if let translation = word.word.senses.first?.translations.first {
                    VStack(spacing: 8) {
                        Text("释义:")
                            .font(.headline)
                        Text(translation)
                            .font(.title3)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // 例句（隐藏目标单词）
                if let example = word.word.senses.first?.examples.first {
                    VStack(spacing: 8) {
                        Text("完成句子:")
                            .font(.headline)
                        
                        Text(example.en.replacingOccurrences(of: word.word.word, with: "_____", options: .caseInsensitive))
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 2)
            
            if !showAnswer {
                // 根据难度显示不同的答题界面
                switch difficulty {
                case .multiple:
                    ReviewOptionsView(
                        correctWord: word.word.word,
                        onSelect: { selected in
                            selectedAnswer = selected
                            showAnswer = true
                            showFeedback = true
                            
                            // 延迟调用答题结果
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                let isCorrect = selected.lowercased() == word.word.word.lowercased()
                                onAnswer(isCorrect)
                            }
                        }
                    )
                case .typing:
                    ReviewTypingView(
                        typedAnswer: $typedAnswer,
                        onSubmit: { typed in
                            selectedAnswer = typed
                            showAnswer = true
                            showFeedback = true
                            
                            // 延迟调用答题结果
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                let isCorrect = typed.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == word.word.word.lowercased()
                                onAnswer(isCorrect)
                            }
                        }
                    )
                }
            } else {
                // 显示答案和反馈
                ReviewFeedbackView(
                    word: word,
                    selectedAnswer: selectedAnswer,
                    showFeedback: showFeedback
                )
            }
        }
    }
}

// MARK: - 输入题界面
struct ReviewTypingView: View {
    @Binding var typedAnswer: String
    let onSubmit: (String) -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("请输入正确的单词:")
                .font(.headline)
            
            TextField("输入单词...", text: $typedAnswer)
                .textFieldStyle(.roundedBorder)
                .font(.title2)
                .textCase(.lowercase)
                .disableAutocorrection(true)
                .focused($isTextFieldFocused)
                .onSubmit {
                    if !typedAnswer.isEmpty {
                        onSubmit(typedAnswer)
                    }
                }
            
            Button("确认") {
                if !typedAnswer.isEmpty {
                    onSubmit(typedAnswer)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(typedAnswer.isEmpty)
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - 选择题选项 (改进版)
struct ReviewOptionsView: View {
    let correctWord: String
    let onSelect: (String) -> Void
    
    // 改进的干扰选项生成逻辑
    private var options: [String] {
        var distractors: [String] = []
        
        // 生成基于单词特征的干扰项
        let wordLength = correctWord.count
        
        // 1. 长度相似的常见单词
        let commonWords = [
            "make", "take", "have", "give", "come", "time", "work", "life", "think", "know",
            "get", "see", "way", "day", "man", "new", "want", "use", "say", "find",
            "look", "ask", "feel", "try", "leave", "call", "move", "live", "show", "play",
            "turn", "mean", "put", "end", "why", "let", "hand", "old", "tell", "word"
        ]
        
        // 筛选长度相近的单词
        let similarLengthWords = commonWords.filter { word in
            abs(word.count - wordLength) <= 2 && word.lowercased() != correctWord.lowercased()
        }
        
        // 2. 首字母相同的单词
        let firstLetter = String(correctWord.prefix(1)).lowercased()
        let sameStartWords = commonWords.filter { word in
            word.lowercased().hasPrefix(firstLetter) && word.lowercased() != correctWord.lowercased()
        }
        
        // 3. 组合干扰项
        distractors.append(contentsOf: similarLengthWords.prefix(2))
        distractors.append(contentsOf: sameStartWords.prefix(1))
        
        // 如果不够3个，补充其他单词
        if distractors.count < 3 {
            let remaining = commonWords.filter { word in
                !distractors.contains(word) && word.lowercased() != correctWord.lowercased()
            }
            distractors.append(contentsOf: remaining.prefix(3 - distractors.count))
        }
        
        // 确保有3个干扰项
        while distractors.count < 3 {
            distractors.append("word\(distractors.count)")
        }
        
        let allOptions = [correctWord] + Array(distractors.prefix(3))
        return allOptions.shuffled()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("选择正确的单词:")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(options, id: \.self) { option in
                    Button(action: { onSelect(option) }) {
                        Text(option)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

// MARK: - 答题反馈
struct ReviewFeedbackView: View {
    let word: SavedWord
    let selectedAnswer: String?
    let showFeedback: Bool
    
    private var isCorrect: Bool {
        selectedAnswer == word.word.word
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 答题结果
            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isCorrect ? .green : .red)
                    .font(.title2)
                
                Text(isCorrect ? "答对了！" : "答错了")
                    .font(.headline)
                    .foregroundColor(isCorrect ? .green : .red)
            }
            
            // 正确答案和释义
            VStack(spacing: 8) {
                Text("正确答案: \(word.word.word)")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if let definition = word.word.senses.first?.translations.first {
                    Text(definition)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // 完整例句
                if let example = word.word.senses.first?.examples.first {
                    VStack(spacing: 4) {
                        Text(example.en)
                            .font(.body)
                            .italic()
                        Text(example.zh)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - 控制按钮
struct ReviewControlButtons: View {
    let onSkip: () -> Void
    let onNext: () -> Void
    let canSkip: Bool
    let canNext: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            if canSkip {
                Button("跳过") {
                    onSkip()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            if canNext {
                Button("下一个") {
                    onNext()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - 复习完成页面
struct ReviewCompletionView: View {
    let results: ReviewResults
    let onRestart: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("复习完成！")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                ResultRow(title: "总计", value: "\(results.totalWords)")
                ResultRow(title: "答对", value: "\(results.correctCount)", color: .green)
                ResultRow(title: "答错", value: "\(results.wrongCount)", color: .red)
                ResultRow(title: "跳过", value: "\(results.skippedCount)", color: .orange)
                
                Divider()
                
                ResultRow(
                    title: "正确率",
                    value: String(format: "%.1f%%", results.accuracy * 100),
                    color: results.accuracy >= 0.8 ? .green : results.accuracy >= 0.6 ? .orange : .red
                )
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button("再来一轮") {
                    onRestart()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                
                Button("完成") {
                    onClose()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}

struct ResultRow: View {
    let title: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - 占位视图在 DictionaryView.swift 中已定义

#Preview {
    ReviewSessionView(words: [])
}
