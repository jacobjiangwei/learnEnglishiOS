//
//  DictionaryView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct DictionaryView: View {
    @StateObject private var viewModel = DictionaryViewModel()
    @State private var showingWordbook = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 生词本入口卡片
                WordbookEntryCard(
                    stats: viewModel.wordbookStats,
                    onTap: { showingWordbook = true }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 搜索栏（始终在原位）
                SearchBarView(
                    text: $viewModel.searchText,
                    onSearchButtonClicked: {
                        viewModel.suggestions = []
                        viewModel.searchWord(viewModel.searchText)
                    }
                )
                .focused($isSearchFocused)
                .padding(.horizontal)
                .padding(.top, 12)
                
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage) {
                        viewModel.clearError()
                    }
                }
                
                // 搜索栏下方：建议 / loading / 结果
                searchResultsContent
                
                Spacer()
            }
            .navigationTitle("词典")
            .onChange(of: viewModel.searchText) { oldValue, newValue in
                if newValue.isEmpty {
                    viewModel.searchResults = []
                    viewModel.suggestions = []
                    viewModel.selectedWord = nil
                    return
                }
                viewModel.updateSuggestions()
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingWordbook, onDismiss: {
            viewModel.refreshWordbookStats()
        }) {
            WordbookView()
        }
    }
    
    // MARK: - 搜索结果
    
    @ViewBuilder
    private var searchResultsContent: some View {
        if viewModel.isLoading {
            LoadingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let word = viewModel.selectedWord {
            // 已选中词 → 内联显示详情
            InlineWordDetailView(
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
        } else if !viewModel.suggestions.isEmpty {
            // 有建议 → 显示建议列表
            SuggestionListView(
                suggestions: viewModel.suggestions,
                onSelect: { suggestion in
                    viewModel.selectSuggestion(suggestion)
                    isSearchFocused = false
                }
            )
        } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
            EmptyResultsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !viewModel.searchResults.isEmpty {
            // 搜索结果列表（多结果时）— 点击直接选中
            WordResultsList(
                words: viewModel.searchResults,
                onWordSelected: { word in
                    viewModel.selectedWord = word
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

// MARK: - 自动补全建议列表
struct SuggestionListView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        List(suggestions, id: \.self) { word in
            Button(action: { onSelect(word) }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(word)
                        .font(.body)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }
}

// MARK: - 内联词详情视图
struct InlineWordDetailView: View {
    let word: Word
    let isInWordbook: Bool
    let onWordbookToggle: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 单词标题 + 收藏按钮
                HStack(alignment: .center) {
                    Text(word.word)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: onWordbookToggle) {
                        HStack(spacing: 4) {
                            Image(systemName: isInWordbook ? "star.fill" : "star")
                                .foregroundColor(isInWordbook ? .yellow : .gray)
                                .font(.title2)
                            Text(isInWordbook ? "已收藏" : "收藏")
                                .font(.caption)
                                .foregroundColor(isInWordbook ? .yellow : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // 音标 + 发音
                WordHeaderView(word: word)
                
                Divider()
                
                // 词义列表
                WordSensesView(senses: word.senses)
                
                // 词形变化
                if let exchange = word.exchange, hasWordForms(exchange) {
                    Divider()
                    WordFormsView(exchange: exchange)
                }
                
                // 同义词反义词
                if !word.synonyms.isEmpty || !word.antonyms.isEmpty {
                    Divider()
                    SynonymsAntonymsView(synonyms: word.synonyms, antonyms: word.antonyms)
                }
                
                // 常用短语
                if !word.relatedPhrases.isEmpty {
                    Divider()
                    RelatedPhrasesView(phrases: word.relatedPhrases)
                }
                
                // 用法说明
                if let notes = word.usageNotes, !notes.isEmpty {
                    Divider()
                    UsageNotesView(notes: notes)
                }
            }
            .padding()
        }
    }
    
    private func hasWordForms(_ exchange: WordExchange) -> Bool {
        return [exchange.plural, exchange.pastTense, exchange.pastParticiple,
                exchange.presentParticiple, exchange.comparative, exchange.superlative,
                exchange.thirdPersonSingular].compactMap { $0 }.filter { !$0.isEmpty }.count > 0
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

// MARK: - 单词详情视图（供其他页面以 sheet 方式使用）
struct WordDetailView: View {
    let word: Word
    var isInWordbook: Bool = false
    var onWordbookToggle: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            InlineWordDetailView(
                word: word,
                isInWordbook: isInWordbook,
                onWordbookToggle: onWordbookToggle ?? {}
            )
            .navigationTitle(word.word)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
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
