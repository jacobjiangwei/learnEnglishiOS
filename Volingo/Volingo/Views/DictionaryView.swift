//
//  DictionaryView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct DictionaryView: View {
    @StateObject private var viewModel = DictionaryViewModel()
    @State private var showingWordDetail = false
    @State private var showingWordbook = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool
    
    /// 是否正在搜索（有输入内容或正在加载）
    private var isSearching: Bool {
        !viewModel.searchText.isEmpty || viewModel.isLoading
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ── 内容区域 ──
                if isSearching {
                    // 搜索模式：搜索栏置顶 + 结果
                    SearchBarView(
                        text: $viewModel.searchText,
                        onSearchButtonClicked: {
                            viewModel.searchWord(viewModel.searchText)
                        }
                    )
                    .focused($isSearchFocused)
                    .padding()
                    
                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage) {
                            viewModel.clearError()
                        }
                    }
                    
                    searchResultsContent
                } else {
                    // 默认模式：生词本在上，搜索在下
                    idleContent
                }
                
                Spacer()
            }
            .navigationTitle("词典")
            .onChange(of: viewModel.searchText) { oldValue, newValue in
                searchTask?.cancel()
                if newValue.isEmpty {
                    viewModel.searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if !Task.isCancelled {
                        await MainActor.run {
                            viewModel.searchWord(newValue)
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingWordDetail) {
            if let word = viewModel.selectedWord {
                WordDetailView(
                    word: word,
                    isInWordbook: viewModel.isWordInWordbook(word),
                    onWordbookToggle: {
                        if viewModel.isWordInWordbook(word) {
                            viewModel.removeFromWordbook(word)
                        } else {
                            viewModel.addToWordbook(word)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingWordbook, onDismiss: {
            viewModel.refreshWordbookStats()
        }) {
            WordbookView()
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }
    
    // MARK: - 默认状态（未搜索时）
    
    private var idleContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 生词本入口卡片
                WordbookEntryCard(
                    stats: viewModel.wordbookStats,
                    onTap: { showingWordbook = true }
                )
                .padding(.horizontal)
                
                // 搜索入口
                SearchBarView(
                    text: $viewModel.searchText,
                    onSearchButtonClicked: {
                        viewModel.searchWord(viewModel.searchText)
                    }
                )
                .focused($isSearchFocused)
                .padding(.horizontal)
                
                // 缓存统计
                let cachedCount = DictionaryService.shared.getCachedWordCount()
                if cachedCount > 0 {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.secondary)
                        Text("已缓存 \(cachedCount) 个词条")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - 搜索结果
    
    @ViewBuilder
    private var searchResultsContent: some View {
        if viewModel.isLoading {
            LoadingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
            EmptyResultsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WordResultsList(
                words: viewModel.searchResults,
                onWordSelected: { word in
                    viewModel.selectedWord = word
                    showingWordDetail = true
                },
                onWordbookAction: { word in
                    if viewModel.isWordInWordbook(word) {
                        viewModel.removeFromWordbook(word)
                    } else {
                        viewModel.addToWordbook(word)
                    }
                },
                isWordInWordbook: { word in
                    viewModel.isWordInWordbook(word)
                }
            )
        }
    }
}

// MARK: - 生词本入口卡片
struct WordbookEntryCard: View {
    let stats: WordbookStats
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "book.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("我的生词本")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if stats.totalWords > 0 {
                    HStack(spacing: 16) {
                        StatPill(value: "\(stats.totalWords)", label: "总词数", color: .blue)
                        
                        if stats.needReviewCount > 0 {
                            StatPill(value: "\(stats.needReviewCount)", label: "待复习", color: .orange)
                        }
                        
                        if stats.masteredWords > 0 {
                            StatPill(value: "\(stats.masteredWords)", label: "已掌握", color: .green)
                        }
                        
                        Spacer()
                    }
                } else {
                    HStack {
                        Text("查词后可收藏到生词本")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct StatPill: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 搜索栏组件
struct SearchBarView: View {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("输入要查询的单词...", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    onSearchButtonClicked()
                }
            
            Button("搜索", action: onSearchButtonClicked)
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - 错误横幅
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
            
            Spacer()
            
            Button("关闭", action: onDismiss)
                .font(.caption)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - 加载视图
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在搜索...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
}

// MARK: - 空结果视图
struct EmptyResultsView: View {
    var body: some View {
        VStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("未找到相关单词")
                .font(.headline)
                .padding(.top, 16)
            
            Text("请检查拼写或尝试其他关键词")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
}

// MARK: - 搜索结果列表
struct WordResultsList: View {
    let words: [Word]
    let onWordSelected: (Word) -> Void
    let onWordbookAction: (Word) -> Void
    let isWordInWordbook: (Word) -> Bool
    
    var body: some View {
        List(words) { word in
            WordRowView(
                word: word,
                onTap: { onWordSelected(word) },
                onWordbookAction: { onWordbookAction(word) },
                isWordInWordbook: { isWordInWordbook(word) }
            )
        }
        .listStyle(.plain)
    }
}

// MARK: - 单词行视图
struct WordRowView: View {
    let word: Word
    let onTap: () -> Void
    let onWordbookAction: () -> Void
    let isWordInWordbook: () -> Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // 单词和音标
                HStack {
                    Text(word.word)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let phonetic = word.phonetic {
                        Text(phonetic)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 第一个释义
                if let firstSense = word.senses.first {
                    HStack {
                        Text(firstSense.pos)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        
                        Text(firstSense.translations.first ?? firstSense.definitions.first ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // 词汇级别标签
                if (!word.levels.activeLevels.isEmpty) {
                    HStack {
                        ForEach(Array(word.levels.activeLevels.prefix(3)), id: \.self) { level in
                            Text(level)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(3)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: onWordbookAction) {
                Image(systemName: isWordInWordbook() ? "minus.circle" : "plus.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - 单词详情视图
struct WordDetailView: View {
    let word: Word
    var isInWordbook: Bool = false
    var onWordbookToggle: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 使用简化后的 WordHeaderView
                    WordHeaderView(word: word)
                    
                    // 词义列表
                    WordSensesView(senses: word.senses)
                    
                    // 词形变化
                    if let exchange = word.exchange, hasWordForms(exchange) {
                        WordFormsView(exchange: exchange)
                    }
                    
                    // 同义词反义词
                    if !word.synonyms.isEmpty || !word.antonyms.isEmpty {
                        SynonymsAntonymsView(synonyms: word.synonyms, antonyms: word.antonyms)
                    }
                    
                    // 常用短语
                    if !word.relatedPhrases.isEmpty {
                        RelatedPhrasesView(phrases: word.relatedPhrases)
                    }
                    
                    // 用法说明
                    if let notes = word.usageNotes, !notes.isEmpty {
                        UsageNotesView(notes: notes)
                    }
                }
                .padding()
            }
            .navigationTitle(word.word)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let toggle = onWordbookToggle {
                        Button(action: toggle) {
                            Image(systemName: isInWordbook ? "star.fill" : "star")
                                .foregroundColor(isInWordbook ? .yellow : .gray)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func hasWordForms(_ exchange: WordExchange) -> Bool {
        return [exchange.plural, exchange.pastTense, exchange.pastParticiple,
                exchange.presentParticiple, exchange.comparative, exchange.superlative,
                exchange.thirdPersonSingular].compactMap { $0 }.filter { !$0.isEmpty }.count > 0
    }
}

// MARK: - 单词头部视图
struct WordHeaderView: View {
    let word: Word
    @StateObject private var audioService = AudioService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 音标和发音按钮行
            HStack(spacing: 30) {
                if let phonetic = word.phonetic {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    audioService.playWordPronunciation(word.word)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: audioService.isPlaying ? "speaker.wave.3" : "speaker.wave.2")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        if audioService.isPlaying {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                }
                .disabled(audioService.isPlaying)
                
                Spacer()
            }
            
            // 词汇级别
            if (!word.levels.activeLevels.isEmpty) {
                LazyHGrid(rows: [GridItem(.flexible())], spacing: 8) {
                    ForEach(word.levels.activeLevels, id: \.self) { level in
                        Text(level)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
}

// MARK: - 词义视图
struct WordSensesView: View {
    let senses: [WordSense]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("释义")
                .font(.headline)
            
            ForEach(Array(senses.enumerated()), id: \.offset) { index, sense in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(sense.pos)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    ForEach(Array(sense.translations.enumerated()), id: \.offset) { _, translation in
                        Text("• \(translation)")
                            .font(.body)
                    }
                    
                    if !sense.examples.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(sense.examples.prefix(2)) { example in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(example.en)
                                        .font(.caption)
                                        .italic()
                                    Text(example.zh)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 16)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - 词形变化视图
struct WordFormsView: View {
    let exchange: WordExchange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("词形变化")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                if let plural = exchange.plural, !plural.isEmpty {
                    WordFormItem(label: "复数", value: plural)
                }
                if let thirdPerson = exchange.thirdPersonSingular, !thirdPerson.isEmpty {
                    WordFormItem(label: "第三人称单数", value: thirdPerson)
                }
                if let pastTense = exchange.pastTense, !pastTense.isEmpty {
                    WordFormItem(label: "过去式", value: pastTense)
                }
                if let pastParticiple = exchange.pastParticiple, !pastParticiple.isEmpty {
                    WordFormItem(label: "过去分词", value: pastParticiple)
                }
                if let presentParticiple = exchange.presentParticiple, !presentParticiple.isEmpty {
                    WordFormItem(label: "现在分词", value: presentParticiple)
                }
                if let comparative = exchange.comparative, !comparative.isEmpty {
                    WordFormItem(label: "比较级", value: comparative)
                }
                if let superlative = exchange.superlative, !superlative.isEmpty {
                    WordFormItem(label: "最高级", value: superlative)
                }
            }
        }
    }
}

struct WordFormItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 同义词反义词视图
struct SynonymsAntonymsView: View {
    let synonyms: [String]
    let antonyms: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("同义词")
                        .font(.headline)
                    
                    Text(synonyms.joined(separator: ", "))
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }
            
            if !antonyms.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("反义词")
                        .font(.headline)
                    
                    Text(antonyms.joined(separator: ", "))
                        .font(.body)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - 常用短语视图
struct RelatedPhrasesView: View {
    let phrases: [RelatedPhrase]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("常用短语")
                .font(.headline)
            
            ForEach(phrases) { phrase in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phrase.phrase)
                            .font(.body)
                            .fontWeight(.medium)
                        Text(phrase.meaning)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - 用法说明视图
struct UsageNotesView: View {
    let notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用法说明")
                .font(.headline)
            
            Text(notes)
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
}

#Preview {
    DictionaryView()
}
