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
    @State private var showingLearningStats = false
    
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
                
                // 今日完成状态横幅
                if !viewModel.isLoading && viewModel.wordbookStats.totalWords > 0 && viewModel.wordbookStats.needReviewCount == 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("🎉 今日复习任务已完成！")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
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
                        Button("开始复习") {
                            showingReviewSession = true
                        }
                        .buttonStyle(.borderedProminent)
                    } else if viewModel.wordbookStats.totalWords > 0 {
                        // 没有需要复习的单词时显示成就状态
                        Button(action: {
                            showingLearningStats = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trophy.fill")
                                Text("今日完成")
                            }
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    } else {
                        // 生词本为空时的引导按钮
                        Button(action: {
                            // 跳转到词典页面添加单词
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                Text("添加单词")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $viewModel.showingWordDetail) {
            if let savedWord = viewModel.selectedWord {
                SavedWordDetailView(savedWord: savedWord)
            }
        }
        .sheet(isPresented: $showingLearningStats) {
            LearningStatsView(stats: viewModel.wordbookStats)
        }
        .sheet(isPresented: $showingReviewSession) {
            ReviewSessionView(words: viewModel.getRecommendedReviewWords())
                .onDisappear {
                    // 复习完成后刷新数据
                    viewModel.loadData()
                }
        }
        .onAppear {
            // 视图出现时加载数据
            viewModel.loadData()
        }
        .refreshable {
            // 支持下拉刷新
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

// MARK: - 学习统计视图
struct LearningStatsView: View {
    let stats: WordbookStats
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 成就祝贺
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("🎉 太棒了！")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("今天的复习任务已完成")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // 学习统计卡片
                VStack(spacing: 16) {
                    StatCard(
                        icon: "book.fill",
                        title: "总词汇量",
                        value: "\(stats.totalWords)",
                        color: .blue
                    )
                    
                    HStack(spacing: 16) {
                        StatCard(
                            icon: "star.fill",
                            title: "已掌握",
                            value: "\(stats.masteredWords)",
                            color: .green
                        )
                        
                        StatCard(
                            icon: "clock.fill",
                            title: "学习中",
                            value: "\(stats.learningWords + stats.reviewingWords)",
                            color: .orange
                        )
                    }
                }
                
                // 学习建议
                VStack(alignment: .leading, spacing: 12) {
                    Text("学习建议")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        SuggestionRow(
                            icon: "plus.circle",
                            text: "继续添加新单词来扩充词汇量",
                            color: .blue
                        )
                        
                        SuggestionRow(
                            icon: "repeat.circle",
                            text: "定期复习已学单词以巩固记忆",
                            color: .green
                        )
                        
                        if stats.totalWords > 50 {
                            SuggestionRow(
                                icon: "target",
                                text: "尝试在对话和写作中使用学过的单词",
                                color: .purple
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("学习统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 建议行
struct SuggestionRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    WordbookView()
}
