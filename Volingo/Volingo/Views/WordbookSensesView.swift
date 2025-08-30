//
//  WordbookSensesView.swift
//  Volingo
//
//  Created by jacob on 2025/8/30.
//

import SwiftUI

// MARK: - 生词本专用的词义视图
struct WordbookSensesView: View {
    let senses: [WordSense]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("释义")
                .font(.headline)
            
            ForEach(Array(senses.enumerated()), id: \.offset) { index, sense in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(sense.pos)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    ForEach(Array(sense.translations.enumerated()), id: \.offset) { _, translation in
                        Text("• \(translation)")
                            .font(.body)
                    }
                    
                    if !sense.examples.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(sense.examples.prefix(2)) { example in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(example.en)
                                        .font(.caption)
                                        .italic()
                                    Text(example.zh)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 16)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

#Preview {
    WordbookSensesView(senses: [])
}
