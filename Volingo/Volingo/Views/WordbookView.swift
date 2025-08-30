//
//  WordbookView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct WordbookView: View {
    @StateObject private var viewModel = WordbookViewModel()
    @State private var showingReviewSession = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 筛选和搜索栏（包含统计数字）
                if !viewModel.isLoading {
                    WordbookFilterView(
                        searchText: $viewModel.searchText,
                        selectedLevel: $viewModel.selectedMasteryDescription,
                        stats: viewModel.wordbookStats
                    )
                    .padding(.horizontal)
                    .onChange(of: viewModel.searchText) { _, _ in
                        viewModel.applyFilters()
                    }
                    .onChange(of: viewModel.selectedMasteryDescription) { _, _ in
                        viewModel.applyFilters()
                    }
                }
                
                // 内容区域
                if viewModel.isLoading {
                    LoadingView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.savedWords.isEmpty {
                    EmptyWordbookView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredWords.isEmpty {
                    EmptyFilterResultsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    SavedWordsList(
                        words: viewModel.filteredWords,
                        onWordSelected: { word in
                            viewModel.selectedWord = word
                            viewModel.showingWordDetail = true
                        },
                        onDeleteWord: { word in
                            viewModel.deleteWord(word)
                        }
                    )
                }
            }
            .navigationTitle("生词本")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.wordbookStats.needReviewCount > 0 {
                        Button("开始复习") {
                            showingReviewSession = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingWordDetail) {
            if let savedWord = viewModel.selectedWord {
                SavedWordDetailView(savedWord: savedWord)
            }
        }
        .sheet(isPresented: $showingReviewSession) {
            ReviewSessionView(words: viewModel.getRecommendedReviewWords())
        }
        .onAppear {
            viewModel.loadData()
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - 筛选视图
struct WordbookFilterView: View {
    @Binding var searchText: String
    @Binding var selectedLevel: String?
    let stats: WordbookStats
    
    // 可选择的掌握程度选项
    private let masteryOptions = ["新词", "学习中", "熟悉", "掌握"]
    
    // 根据掌握程度获取对应的数量
    private func getCount(for level: String) -> Int {
        switch level {
        case "新词": return stats.newWords
        case "学习中": return stats.learningWords
        case "熟悉": return stats.reviewingWords
        case "掌握": return stats.masteredWords
        default: return 0
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索单词或释义...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // 掌握程度筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "全部",
                        count: stats.totalWords,
                        isSelected: selectedLevel == nil,
                        action: { selectedLevel = nil }
                    )
                    
                    ForEach(masteryOptions, id: \.self) { option in
                        FilterChip(
                            title: option,
                            count: getCount(for: option),
                            isSelected: selectedLevel == option,
                            action: { selectedLevel = option }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

// MARK: - 生词列表
struct SavedWordsList: View {
    let words: [SavedWord]
    let onWordSelected: (SavedWord) -> Void
    let onDeleteWord: (SavedWord) -> Void
    
    var body: some View {
        List {
            ForEach(words) { savedWord in
                SavedWordRowView(
                    savedWord: savedWord,
                    onTap: { onWordSelected(savedWord) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("删除", role: .destructive) {
                        onDeleteWord(savedWord)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - 生词行视图
struct SavedWordRowView: View {
    let savedWord: SavedWord
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // 单词和音标
                HStack {
                    Text(savedWord.word.word)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let phonetic = savedWord.word.phonetic {
                        Text(phonetic)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 中文翻译
                if let firstSense = savedWord.word.senses.first,
                   let translation = firstSense.translations.first {
                    Text(translation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // 词汇级别标签和掌握程度标签
                HStack {
                    // 词汇级别标签（左侧）
                    if !savedWord.word.levels.activeLevels.isEmpty {
                        ForEach(Array(savedWord.word.levels.activeLevels.prefix(3)), id: \.self) { level in
                            Text(level)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(3)
                        }
                    }
                    
                    Spacer()
                    
                    // 掌握程度标签（右侧）
                    Text(savedWord.masteryDescription)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(savedWord.masteryColor.opacity(0.2))
                        .foregroundColor(savedWord.masteryColor)
                        .cornerRadius(4)
                }
                
                // 学习统计（如果有复习记录的话）
                if savedWord.totalReviews > 0 {
                    HStack {
                        Text("复习 \(savedWord.totalReviews) 次")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("答对率 \(Int((Double(savedWord.correctCount) / Double(max(savedWord.totalReviews, 1))) * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - 空状态视图
struct EmptyWordbookView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("生词本为空")
                .font(.headline)
            
            Text("去查词典添加一些单词吧！")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct EmptyFilterResultsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("没有找到匹配的单词")
                .font(.headline)
            
            Text("试试调整搜索条件")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 生词详情视图
struct SavedWordDetailView: View {
    let savedWord: SavedWord
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 使用统一的 WordHeaderView
                    WordHeaderView(word: savedWord.word)
                    
                    // 学习进度
                    LearningProgressView(savedWord: savedWord)
                    
                    // 词义详情
                    WordbookSensesView(senses: savedWord.word.senses)
                }
                .padding()
            }
            .navigationTitle(savedWord.word.word)
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
}

// MARK: - 学习进度视图
struct LearningProgressView: View {
    let savedWord: SavedWord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("学习进度")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack {
                    Text("掌握程度:")
                    Spacer()
                    Text(savedWord.masteryDescription)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(savedWord.masteryColor.opacity(0.2))
                        .cornerRadius(6)
                }
                
                if savedWord.totalReviews > 0 {
                    HStack {
                        Text("复习次数:")
                        Spacer()
                        Text("\(savedWord.totalReviews)")
                    }
                    
                    HStack {
                        Text("答对率:")
                        Spacer()
                        let accuracy = Double(savedWord.correctCount) / Double(max(savedWord.totalReviews, 1))
                        Text("\(Int(accuracy * 100))%")
                    }
                }
                
                HStack {
                    Text("添加时间:")
                    Spacer()
                    Text(savedWord.addedDate, style: .date)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("下次复习:")
                    Spacer()
                    Text(savedWord.timeUntilNextReview)
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 复习会话视图（占位符）
struct ReviewSessionView: View {
    let words: [SavedWord]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("复习会话")
                    .font(.title)
                
                Text("准备复习 \(words.count) 个单词")
                    .foregroundColor(.secondary)
                
                // TODO: 实现复习功能
                
                Spacer()
            }
            .padding()
            .navigationTitle("复习")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 生词本专用的词义视图
struct WordbookSensesView: View {
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

#Preview {
    WordbookView()
}
