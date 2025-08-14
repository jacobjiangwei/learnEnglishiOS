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
            DictionaryView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("查词")
                }
            
            WordbookView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("生词本")
                }
            
            ScenarioView()
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("对话")
                }
            
            WritingView()
                .tabItem {
                    Image(systemName: "pencil")
                    Text("写作")
                }
            
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
