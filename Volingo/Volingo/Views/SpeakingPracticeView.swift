//
//  SpeakingPracticeView.swift
//  Volingo
//
//  Created by jacob on 2026/2/13.
//

import SwiftUI

/// 口语专项练习（多邻国风格：所有题目都有明确期望答案）
/// 题型：朗读句子 / 翻译并朗读 / 听后跟读 / 补全句子
struct SpeakingPracticeView: View {
    let questions: [SpeakingQuestion]
    var onAnswer: ((String, Bool) -> Void)? = nil

    @State private var currentIndex = 0
    @State private var showResult = false
    @State private var correctCount = 0

    // 录音 & 识别状态
    @StateObject private var audio = AudioService.shared
    @StateObject private var speech = SpeechRecognitionService.shared
    @State private var isRecording = false
    @State private var pronunciationResult: PronunciationResult? = nil
    @State private var isEvaluating = false
    @State private var permissionGranted: Bool? = nil
    @State private var hasListened = false  // 听后跟读：是否已听过示范

    var body: some View {
        VStack(spacing: 0) {
            if questions.isEmpty {
                emptyView
            } else if showResult {
                PracticeResultView(title: "口语专项", totalCount: questions.count, correctCount: correctCount)
            } else if permissionGranted == false {
                permissionDeniedView
            } else {
                PracticeProgressHeader(current: currentIndex, total: questions.count)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        let question = questions[currentIndex]

                        // 题型标签 + 图标
                        HStack(spacing: 6) {
                            Image(systemName: question.category.icon)
                                .font(.caption)
                            Text(question.category.rawValue)
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .clipShape(Capsule())

                        // 根据题型展示不同的题面
                        questionContentView(question)

                        // 录音控制区
                        recordingSection(question)

                        // 实时识别文字
                        if isRecording && !speech.recognizedText.isEmpty {
                            liveRecognitionView
                        }

                        // 评测中
                        if isEvaluating {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("正在评测发音…")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }

                        // 评测结果
                        if let result = pronunciationResult {
                            pronunciationResultView(result)

                            // 翻译题：评测后显示正确英文
                            if question.category == .translateSpeak {
                                answerCard(title: "正确答案", text: question.referenceText, translation: nil)
                            }

                            // 补全题：评测后显示完整句子
                            if question.category == .completeSpeak {
                                answerCard(title: "完整句子", text: question.referenceText, translation: question.translation)
                            }

                            // 回放按钮
                            if audio.recordedFileURL != nil {
                                playbackButton
                            }

                            NextQuestionButton(isLast: currentIndex >= questions.count - 1) {
                                nextQuestion()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("口语专项")
        .navigationBarTitleDisplayMode(.inline)
        .reportableQuestion(id: questions.isEmpty || showResult ? nil : questions[currentIndex].id)
        .task {
            let granted = await speech.requestPermissions()
            permissionGranted = granted
        }
    }

    // MARK: - 题面内容（根据题型不同展示）

    @ViewBuilder
    private func questionContentView(_ question: SpeakingQuestion) -> some View {
        switch question.category {

        case .readAloud:
            // 朗读句子：显示英文 + 中文翻译 + 可听示范
            VStack(alignment: .leading, spacing: 12) {
                Text("请朗读以下句子")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(question.referenceText)
                    .font(.title3.bold())
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let translation = question.translation, !translation.isEmpty {
                    Text(translation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                listenButtons(question.referenceText)
            }

        case .translateSpeak:
            // 翻译说：显示中文，用户说出英文
            VStack(alignment: .leading, spacing: 12) {
                Text("请将中文翻译成英文并朗读")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let translation = question.translation, !translation.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "character.bubble.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text(translation)
                            .font(.title3.bold())
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

        case .listenRepeat:
            // 听后跟读：先听示范 → 显示文字 → 用户跟读
            VStack(alignment: .leading, spacing: 12) {
                Text("请先听示范，然后跟读")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                listenButtons(question.referenceText)

                // 听过之后显示文字，辅助用户
                if hasListened || pronunciationResult != nil {
                    Text(question.referenceText)
                        .font(.title3.bold())
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let translation = question.translation, !translation.isEmpty {
                        Text(translation)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "ear.fill")
                            .foregroundColor(.blue)
                        Text("请先点击上方按钮听示范")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

        case .completeSpeak:
            // 补全说：显示有空白的句子，用户说出完整版
            VStack(alignment: .leading, spacing: 12) {
                Text("请补全并朗读完整句子")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // prompt 里包含带 ___ 的句子
                Text(question.prompt)
                    .font(.title3.bold())
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let translation = question.translation, !translation.isEmpty {
                    Text(translation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                listenButtons(question.referenceText)
            }
        }
    }

    // MARK: - 听示范

    private func listenButtons(_ text: String) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                audio.playWordPronunciation(text)
                hasListened = true
            }) {
                HStack {
                    Image(systemName: audio.isPlaying ? "speaker.wave.3.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text(audio.isPlaying ? "播放中…" : "听示范")
                        .font(.subheadline.bold())
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(audio.isPlaying || isRecording)

            Button(action: {
                audio.playWordPronunciation(text, rate: 0.2)
                hasListened = true
            }) {
                HStack {
                    Image(systemName: "tortoise.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("慢速")
                        .font(.subheadline.bold())
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(audio.isPlaying || isRecording)
        }
    }

    // MARK: - 实时识别

    private var liveRecognitionView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("识别中…")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Text(speech.recognizedText)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 录音控制区

    @State private var pulsePhase = false

    private func recordingSection(_ question: SpeakingQuestion) -> some View {
        let disabled = isEvaluating
            || (question.category == .listenRepeat && !hasListened)

        return VStack(spacing: 4) {
            Button(action: toggleRecording) {
                VStack(spacing: 12) {
                    ZStack {
                        if isRecording {
                            // 外层 — 慢速大圈，向外扩散淡出
                            Circle()
                                .stroke(Color.red.opacity(0.15), lineWidth: 2)
                                .frame(width: 90, height: 90)
                                .scaleEffect(pulsePhase ? 1.4 : 0.85)
                                .opacity(pulsePhase ? 0 : 0.7)
                                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: pulsePhase)

                            // 中层 — 呼吸填充
                            Circle()
                                .fill(Color.red.opacity(0.10))
                                .frame(width: 78, height: 78)
                                .scaleEffect(pulsePhase ? 1.2 : 0.95)
                                .opacity(pulsePhase ? 0.08 : 0.4)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulsePhase)

                            // 内层 — 快速呼吸光晕
                            Circle()
                                .fill(Color.red.opacity(0.12))
                                .frame(width: 70, height: 70)
                                .scaleEffect(pulsePhase ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulsePhase)
                        }

                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(recordButtonColor(disabled: disabled))
                            .symbolEffect(.pulse, isActive: isRecording)
                    }
                    .frame(height: 80)
                    .onChange(of: isRecording) { _, newVal in
                        if newVal {
                            // 先重置到初始态，下一帧再触发动画
                            pulsePhase = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                pulsePhase = true
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.3)) {
                                pulsePhase = false
                            }
                        }
                    }

                    Text(recordLabel(disabled: disabled, isListenRepeat: question.category == .listenRepeat))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .disabled(disabled)

            // 重新录音按钮
            if pronunciationResult != nil && !isEvaluating {
                Button(action: retryRecording) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重新录音")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func recordButtonColor(disabled: Bool) -> Color {
        if isRecording { return .red }
        if disabled { return .gray }
        return .blue
    }

    private func recordLabel(disabled: Bool, isListenRepeat: Bool) -> String {
        if isRecording { return "录音中…点击停止" }
        if isEvaluating { return "评测中…" }
        if isListenRepeat && !hasListened { return "请先听示范" }
        return "点击开始录音"
    }

    /// 重新录音：清除上次结果并开始新一轮
    private func retryRecording() {
        pronunciationResult = nil
        isRecording = false
        isEvaluating = false
        pulsePhase = false
    }

    // MARK: - 录音逻辑

    private func toggleRecording() {
        if isRecording {
            stopAndEvaluate()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        audio.stopPlaying()
        pronunciationResult = nil

        audio.startRecording()
        do {
            try speech.startListening()
        } catch {
            print("❌ 实时识别启动失败: \(error)")
        }
        isRecording = true
        // pulsePhase 由 onChange(of: isRecording) 自动触发
    }

    private func stopAndEvaluate() {
        isRecording = false
        // pulsePhase 由 onChange(of: isRecording) 自动收起
        speech.stopListening()

        let fileURL = audio.stopRecording()
        let question = questions[currentIndex]

        guard let url = fileURL else {
            pronunciationResult = PronunciationResult(
                recognizedText: "",
                referenceText: question.referenceText,
                overallScore: 0, accuracyScore: 0, completenessScore: 0, fluencyScore: 0,
                wordScores: [],
                feedback: "录音失败，请重试。"
            )
            return
        }

        isEvaluating = true
        Task {
            do {
                let result = try await speech.evaluatePronunciation(audioURL: url, referenceText: question.referenceText)
                pronunciationResult = result
            } catch {
                pronunciationResult = PronunciationResult(
                    recognizedText: speech.recognizedText,
                    referenceText: question.referenceText,
                    overallScore: 0, accuracyScore: 0, completenessScore: 0, fluencyScore: 0,
                    wordScores: [],
                    feedback: "评测失败: \(error.localizedDescription)"
                )
            }
            isEvaluating = false
        }
    }

    // MARK: - 评测结果视图

    private func pronunciationResultView(_ result: PronunciationResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 总分 + 评级
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("发音评测")
                        .font(.headline)
                    HStack(spacing: 6) {
                        Image(systemName: result.grade.icon)
                        Text(result.grade.rawValue)
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(gradeColor(result.grade))
                }
                Spacer()
                Text("\(result.overallScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(gradeColor(result.grade))
                Text("/ 100")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 三维指标
            HStack(spacing: 0) {
                scoreGauge(label: "准确度", score: result.accuracyScore, color: .blue)
                scoreGauge(label: "完整度", score: result.completenessScore, color: .green)
                scoreGauge(label: "流利度", score: result.fluencyScore, color: .purple)
            }

            Divider()

            // 逐词标注
            if !result.wordScores.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("逐词评测")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(result.wordScores) { ws in
                            Text(ws.word.isEmpty ? (ws.recognized ?? "") : ws.word)
                                .font(.body.bold())
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ws.isCorrect ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .foregroundColor(ws.isCorrect ? .green : .red)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }

            // 识别文本
            if !result.recognizedText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("你说的")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text(result.recognizedText)
                        .font(.body)
                }
            }

            Divider()

            // 反馈
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text(result.feedback)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 辅助视图

    private func scoreGauge(label: String, score: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundColor(color)
            }
            .frame(width: 52, height: 52)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func gradeColor(_ grade: PronunciationGrade) -> Color {
        switch grade {
        case .excellent: return .green
        case .good:      return .blue
        case .fair:      return .orange
        case .needsWork: return .red
        }
    }

    private func answerCard(title: String, text: String, translation: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Text(text)
                .font(.title3.bold())
            if let t = translation, !t.isEmpty {
                Text(t)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var playbackButton: some View {
        Button(action: { audio.playRecording() }) {
            HStack {
                Image(systemName: "play.fill")
                Text("回放录音")
            }
            .font(.subheadline.bold())
            .foregroundColor(.purple)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.purple.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(audio.isPlaying)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无口语题目")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("需要语音权限")
                .font(.title3.bold())
            Text("请在「设置 → Volingo」中开启麦克风和语音识别权限")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 导航

    private func nextQuestion() {
        audio.stopPlaying()
        // 结算本题：仅以最终结果计分（重试不重复计算）
        if let result = pronunciationResult {
            let isCorrect = result.overallScore >= 60
            if isCorrect { correctCount += 1 }
            onAnswer?(questions[currentIndex].id, isCorrect)
        }
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            isRecording = false
            pronunciationResult = nil
            isEvaluating = false
            hasListened = false
        } else {
            showResult = true
        }
    }
}

#Preview {
    NavigationView {
        SpeakingPracticeView(questions: [
            SpeakingQuestion(id: "p1", prompt: "请朗读以下句子：", referenceText: "The weather is nice today.", translation: "今天天气真好。", category: .readAloud),
            SpeakingQuestion(id: "p2", prompt: "请将中文翻译成英文并朗读：", referenceText: "I like to read books.", translation: "我喜欢阅读。", category: .translateSpeak),
            SpeakingQuestion(id: "p3", prompt: "请先听示范朗读，然后跟读：", referenceText: "She goes to school by bus.", translation: "她坐公交车上学。", category: .listenRepeat),
            SpeakingQuestion(id: "p4", prompt: "请补全并朗读完整句子：I ___ to school every day.", referenceText: "I go to school every day.", translation: "我每天去学校。", category: .completeSpeak),
        ])
    }
}
