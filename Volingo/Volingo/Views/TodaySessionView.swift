//
//  TodaySessionView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 今日推荐套餐 - 按题型分段列表，点击每段进入对应练习
struct TodaySessionView: View {
    let package: TodayPackage

    var body: some View {
        List {
            Section {
                ForEach(package.items) { item in
                    NavigationLink(destination: PracticeRouterView(questionType: item.type)) {
                        HStack(spacing: 12) {
                            Image(systemName: item.type.icon)
                                .foregroundColor(item.type.color)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.type.rawValue)
                                    .font(.body)
                                Text(item.type.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("\(item.count) 题")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("今日练习项目")
            } footer: {
                Text("共 \(package.totalQuestions) 题 · 约 \(package.estimatedMinutes) 分钟")
            }
        }
        .navigationTitle("今日推荐")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AnalyticsService.shared.trackScreenView("TodaySessionView")
            AnalyticsService.shared.trackTodayPackageStarted(textbookCode: package.level)
        }
    }
}

#Preview {
    NavigationView {
        TodaySessionView(package: TodayPackage(
            date: Date(),
            level: "juniorPEP-7a",
            items: [
                PackageItem(type: .multipleChoice, count: 5, weight: 0.4),
                PackageItem(type: .cloze, count: 3, weight: 0.3),
            ],
            estimatedMinutes: 10
        ))
        .environmentObject(UserStateStore())
    }
}
