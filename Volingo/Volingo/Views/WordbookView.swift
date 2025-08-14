//
//  WordbookView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct WordbookView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("生词本模块")
                    .font(.largeTitle)
                    .padding()
                
                Text("TODO: 自动记录生词，艾宾浩斯记忆曲线复习，进度追踪")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("生词本")
        }
    }
}

#Preview {
    WordbookView()
}
