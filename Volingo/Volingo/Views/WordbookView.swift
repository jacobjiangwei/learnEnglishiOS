//
//  WordbookView.swift
//  Volingo
//

import SwiftUI

struct WordbookView: View {
    @StateObject private var viewModel = WordbookViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                if !viewModel.isLoading {
                    WordbookSearchBar(searchText: $viewModel.searchText)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .onChange(of: viewModel.searchText) { _, _ in
                            viewModel.applyFilters()
                        }
                }
                
                // 统计概要 + 开始复习
                if !viewModel.isLoading && viewModel.wordbookStats.totalWords > 0 {
                    WordbookSummaryBanner(
                        stats: viewModel.wordbookStats
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // 内容区域
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                        Text("加载中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                        NavigationLink {
                            ReviewSessionView()
                                .onDisappear {
                                    viewModel.loadData()
                                }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("复习 (\(viewModel.wordbookStats.needReviewCount))")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else if viewModel.wordbookStats.totalWords > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("已完成")
                        }
                        .font(.subheadline)
                        .foregroundColor(.green)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingWordDetail) {
                if let savedWord = viewModel.selectedWord {
                    SavedWordDetailView(savedWord: savedWord)
                }
            }
            .onAppear {
                viewModel.loadData()
            }
            .refreshable {
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
}

// MARK: - 搜索栏
struct WordbookSearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
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
    }
}

// MARK: - 统计概要横幅
struct WordbookSummaryBanner: View {
    let stats: WordbookStats
    
    var body: some View {
        HStack {
            Label("\(stats.totalWords) 个单词", systemImage: "book.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if stats.needReviewCount > 0 {
                Label("\(stats.needReviewCount) 个待复习", systemImage: "clock.badge.exclamationmark")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            } else {
                Label("今日已完成", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
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
                
                // 词汇级别标签 + 复习状态
                HStack {
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
                    
                    // FSRS 复习状态
                    Text(savedWord.needsReview ? "待复习" : savedWord.timeUntilNextReview)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(savedWord.needsReview ? Color.orange.opacity(0.2) : Color.blue.opacity(0.15))
                        .foregroundColor(savedWord.needsReview ? .orange : .blue)
                        .cornerRadius(4)
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
        .navigationViewStyle(.stack)
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
                    Text("记忆状态:")
                    Spacer()
                    Text(memoryStateText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(memoryStateColor.opacity(0.2))
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
    
    private var memoryStateText: String {
        switch savedWord.memory.state {
        case .new: return "新词"
        case .learning: return "学习中"
        case .review: return "已学会"
        case .relearning: return "重新学习"
        }
    }
    
    private var memoryStateColor: Color {
        switch savedWord.memory.state {
        case .new: return .blue
        case .learning: return .orange
        case .review: return .green
        case .relearning: return .red
        }
    }
}

#Preview {
    WordbookView()
}
