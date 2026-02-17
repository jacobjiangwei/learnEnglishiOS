//
//  VolingoApp.swift
//  Volingo
//
//  Created by jacob on 2025/8/10.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        #if DEBUG
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        print("📂 沙盒 Documents: \(docs.path)")
        #endif

        return true
    }
}

@main
struct VolingoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    Task {
                        await try? DictionaryService.shared.searchWord("english")
                    }
                }
        }
    }
}
