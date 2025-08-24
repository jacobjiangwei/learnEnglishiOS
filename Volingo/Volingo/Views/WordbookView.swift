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
                // 统计卡片区域
                if !viewModel.isLoading && viewModel.wordbookStats.totalWords > 0 {
                    WordbookStatsView(stats: viewModel.wordbookStats)
                        .padding()
                }
                
                // 筛选和搜索栏
                WordbookFilterView(
                    searchText: $viewModel.searchText,
                    selectedLevel: $viewModel.selectedMasteryLevel
                )
                .padding(.horizontal)
                .onChange(of: viewModel.searchText) { _, _ in
                    viewModel.applyFilters()
                }
                .onChange(of: viewModel.selectedMasteryLevel) { _, _ in
                    viewModel.applyFilters()
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

// MARK: - 统计卡片视图
struct WordbookStatsView: View {
    let stats: WordbookStats
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                StatsCard(
                    title: "总词汇",
                    value: "\(stats.totalWords)",
                    color: .blue
                )
                
                StatsCard(
                    title: "待复习",
                    value: "\(stats.needReviewCount)",
                    color: .orange
                )
            }
            
            HStack {
                StatsCard(
                    title: "新词",
                    value: "\(stats.newWords)",
                    color: .red
                )
                
                StatsCard(
                    title: "学习中",
                    value: "\(stats.learningWords)",
                    color: .orange
                )
                
                StatsCard(
                    title: "复习中",
                    value: "\(stats.reviewingWords)",
                    color: .blue
                )
                
                StatsCard(
                    title: "已掌握",
                    value: "\(stats.masteredWords)",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatsCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(8)
    }
}

// MARK: - 筛选视图
struct WordbookFilterView: View {
    @Binding var searchText: String
    @Binding var selectedLevel: MasteryLevel?
    
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
                        isSelected: selectedLevel == nil,
                        action: { selectedLevel = nil }
                    )
                    
                    ForEach(MasteryLevel.allCases, id: \.self) { level in
                        FilterChip(
                            title: level.rawValue,
                            isSelected: selectedLevel == level,
                            action: { selectedLevel = level }
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
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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
                    Text(savedWord.masteryLevel.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(savedWord.masteryLevel.color.opacity(0.2))
                        .foregroundColor(savedWord.masteryLevel.color)
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
                        
                        Text("答对率 \(Int(savedWord.accuracyRate * 100))%")
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
    @StateObject private var audioService = AudioService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 移除重复的单词头部，直接从音标和发音按钮开始
                    VStack(alignment: .leading, spacing: 8) {
                        // 音标和发音按钮
                        HStack {
                            if let phonetic = savedWord.word.phonetic {
                                Text(phonetic)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                audioService.playWordPronunciation(savedWord.word.word)
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
                        }
                        
                        // 词汇级别
                        if !savedWord.word.levels.activeLevels.isEmpty {
                            LazyHGrid(rows: [GridItem(.flexible())], spacing: 8) {
                                ForEach(savedWord.word.levels.activeLevels, id: \.self) { level in
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
                    Text(savedWord.masteryLevel.rawValue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(savedWord.masteryLevel.color.opacity(0.2))
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
                        Text("\(Int(savedWord.accuracyRate * 100))%")
                    }
                }
                
                HStack {
                    Text("添加时间:")
                    Spacer()
                    Text(savedWord.addedDate, style: .date)
                        .foregroundColor(.secondary)
                }
                
                if let lastReview = savedWord.lastReviewDate {
                    HStack {
                        Text("上次复习:")
                        Spacer()
                        Text(lastReview, style: .relative)
                            .foregroundColor(.secondary)
                    }
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

// MARK: - 生词本专用的单词头部视图
struct WordbookWordHeaderView: View {
    let savedWord: SavedWord
    @StateObject private var audioService = AudioService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(savedWord.word.word)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    audioService.playWordPronunciation(savedWord.word.word)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: audioService.isPlaying ? "speaker.wave.3" : "speaker.wave.2")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        if (audioService.isPlaying) {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                }
                .disabled(audioService.isPlaying)
            }
            
            if let phonetic = savedWord.word.phonetic {
                Text(phonetic)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // 词汇级别
            if (!savedWord.word.levels.activeLevels.isEmpty) {
                LazyHGrid(rows: [GridItem(.flexible())], spacing: 8) {
                    ForEach(savedWord.word.levels.activeLevels, id: \.self) { level in
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
