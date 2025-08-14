//
//  ProfileView.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("个人中心模块")
                    .font(.largeTitle)
                    .padding()
                
                Text("TODO: 用户账号、学习进度、设置、做题练习入口")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("我的")
        }
    }
}

#Preview {
    ProfileView()
}
