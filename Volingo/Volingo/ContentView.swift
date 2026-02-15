//
//  ContentView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 首页（今日推荐 + 专项训练）
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("首页")
                }
                .tag(0)
            
            // Tab 2: 查词（词典/例句/发音/收藏）
            DictionaryView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("查词")
                }
                .tag(1)
            
            // Tab 3: 我的（进度/错题/成就/设置）
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我的")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { _, newValue in
            let names = ["首页", "查词", "我的"]
            AnalyticsService.shared.trackTabSwitched(names[newValue])
        }
    }
}

#Preview {
    ContentView()
}
