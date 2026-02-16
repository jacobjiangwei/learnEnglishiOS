//
//  WritingView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct WritingView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("写作训练模块")
                    .font(.largeTitle)
                    .padding()
                
                Text("TODO: 实时批改（语法、用词、句式），动态难度调整")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("写作训练")
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    WritingView()
}
