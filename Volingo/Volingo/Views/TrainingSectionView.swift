//
//  TrainingSectionView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 一个专项训练分组（横滑卡片）
struct TrainingSectionView: View {
    let category: TrainingCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 分组标题
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                Text(category.rawValue)
                    .font(.headline)
                Spacer()
                NavigationLink(destination: TrainingCategoryListView(category: category)) {
                    Text("全部")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // 横滑卡片
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(category.questionTypes) { type in
                        NavigationLink(destination: PracticeRouterView(questionType: type)) {
                            TrainingTypeCard(type: type)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// 单个题型入口卡片
private struct TrainingTypeCard: View {
    let type: QuestionType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 图标
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(type.color)
                .frame(width: 40, height: 40)
                .background(type.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // 名称
            Text(type.rawValue)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            
            // 描述
            Text(type.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 130, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// 分组全部题型列表
struct TrainingCategoryListView: View {
    let category: TrainingCategory

    var body: some View {
        List {
            ForEach(category.questionTypes) { type in
                NavigationLink(destination: PracticeRouterView(questionType: type)) {
                    HStack(spacing: 12) {
                        Image(systemName: type.icon)
                            .foregroundColor(type.color)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.rawValue)
                                .font(.body)
                            Text(type.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(TrainingCategory.allCases) { cat in
                    TrainingSectionView(category: cat)
                }
            }
            .padding()
        }
    }
}
