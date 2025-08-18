//
//  VolingoApp.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI

@main
struct VolingoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Task {
                        await try? DictionaryService.shared.searchWord("english")
                    }
                }
        }
    }
}
