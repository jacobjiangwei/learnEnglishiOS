//
//  DictionaryView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct DictionaryView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("查词模块")
                    .font(.largeTitle)
                    .padding()
                
                Text("TODO: 英汉双向查询，发音、例句、词性、搭配")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("查词")
        }
    }
}

#Preview {
    DictionaryView()
}
