//
//  ScenarioView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct ScenarioView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("情景对话模块")
                    .font(.largeTitle)
                    .padding()
                
                Text("TODO: 多场景（机场、餐厅、商务等），AI语音评测打分")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("情景对话")
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    ScenarioView()
}
