//
//  ContentView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Tab 1: 首页（今日推荐 + 专项训练）
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("首页")
                }
            
            // Tab 2: 查词（词典/例句/发音/收藏）
            DictionaryView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("查词")
                }
            
            // Tab 3: 我的（进度/错题/成就/设置）
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("我的")
                }
        }
    }
}

#Preview {
    ContentView()
}
