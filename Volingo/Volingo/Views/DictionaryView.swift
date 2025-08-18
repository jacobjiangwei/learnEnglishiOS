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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBarView(
                    text: $viewModel.searchText,
                    onSearchButtonClicked: {
                        viewModel.searchWord(viewModel.searchText)
                    }
                )
                .padding()
                
                // 错误提示
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage) {
                        viewModel.clearError()
                    }
                }
                
                // 内容区域
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
                        onAddToWordbook: { word in
                            viewModel.addToWordbook(word)
                        }
                    )
                }
                
                Spacer()
            }
            .navigationTitle("查词")
        }
        .sheet(isPresented: $showingWordDetail) {
            if let word = viewModel.selectedWord {
                WordDetailView(word: word)
            }
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
    let onAddToWordbook: (Word) -> Void
    
    var body: some View {
        List(words) { word in
            WordRowView(
                word: word,
                onTap: { onWordSelected(word) },
                onAddToWordbook: { onAddToWordbook(word) }
            )
        }
        .listStyle(.plain)
    }
}

// MARK: - 单词行视图
struct WordRowView: View {
    let word: Word
    let onTap: () -> Void
    let onAddToWordbook: () -> Void
    
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
                if !word.levels.activeLevels.isEmpty {
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
            
            Button(action: onAddToWordbook) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - 单词详情视图
struct WordDetailView: View {
    let word: Word
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 头部信息
                    WordHeaderView(word: word)
                    
                    // 词义列表
                    WordSensesView(senses: word.senses)
                    
                    // 词形变化
                    if hasWordForms(word.exchange) {
                        WordFormsView(exchange: word.exchange)
                    }
                    
                    // 同义词反义词
                    if !word.synonyms.isEmpty || !word.antonyms.isEmpty {
                        SynonymsAntonymsView(synonyms: word.synonyms, antonyms: word.antonyms)
                    }
                }
                .padding()
            }
            .navigationTitle(word.word)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(word.word)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    // TODO: 播放发音
                }) {
                    Image(systemName: "speaker.wave.2")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            if let phonetic = word.phonetic {
                Text(phonetic)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // 词汇级别
            if !word.levels.activeLevels.isEmpty {
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

#Preview {
    DictionaryView()
}
