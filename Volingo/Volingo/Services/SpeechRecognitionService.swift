//
//  SpeechRecognitionService.swift
//  海豹英语
//
//  语音识别 + 发音评测服务（基于 Apple Speech Framework）
//

import Foundation
import Speech
import AVFoundation

// MARK: - 发音评测结果

/// 单词级评测详情
struct WordScore: Identifiable {
    let id = UUID()
    let word: String            // 期望单词
    let recognized: String?     // 识别到的单词（nil 表示漏读）
    let isCorrect: Bool
}

/// 整体发音评测结果
struct PronunciationResult {
    let recognizedText: String      // 识别出的完整文本
    let referenceText: String       // 参考原文
    let overallScore: Int           // 总分 0-100
    let accuracyScore: Int          // 准确度 0-100
    let completenessScore: Int      // 完整度 0-100
    let fluencyScore: Int           // 流利度 0-100
    let wordScores: [WordScore]     // 逐词评分
    let feedback: String            // 反馈建议

    /// 评级
    var grade: PronunciationGrade {
        switch overallScore {
        case 90...100: return .excellent
        case 75..<90:  return .good
        case 60..<75:  return .fair
        default:       return .needsWork
        }
    }
}

enum PronunciationGrade: String {
    case excellent  = "优秀"
    case good       = "良好"
    case fair       = "一般"
    case needsWork  = "需加强"

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good:      return "blue"
        case .fair:      return "orange"
        case .needsWork: return "red"
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .good:      return "hand.thumbsup.fill"
        case .fair:      return "face.smiling"
        case .needsWork: return "arrow.up.heart.fill"
        }
    }
}

// MARK: - 语音识别服务

@MainActor
class SpeechRecognitionService: ObservableObject {
    static let shared = SpeechRecognitionService()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // MARK: - 权限

    /// 请求语音识别 & 麦克风权限
    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        authorizationStatus = speechStatus

        guard speechStatus == .authorized else {
            print("❌ 语音识别权限被拒绝: \(speechStatus.rawValue)")
            return false
        }

        let micStatus: Bool
        if #available(iOS 17.0, *) {
            micStatus = await AVAudioApplication.requestRecordPermission()
        } else {
            micStatus = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }

        guard micStatus else {
            print("❌ 麦克风权限被拒绝")
            return false
        }

        return true
    }

    // MARK: - 实时识别（流式，用于实时显示文字）

    /// 开始实时语音识别
    func startListening() throws {
        // 如果已有任务则先停止
        stopListening()

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }
        request.shouldReportPartialResults = true

        // 安装音频 tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
        recognizedText = ""

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                }

                if error != nil || (result?.isFinal ?? false) {
                    self.cleanupAudioEngine()
                }
            }
        }
    }

    /// 停止实时识别
    func stopListening() {
        recognitionTask?.cancel()
        recognitionTask = nil
        cleanupAudioEngine()
    }

    private func cleanupAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isListening = false
    }

    // MARK: - 离线评测（录音文件 → 评分）

    /// 对录音文件进行发音评测（与参考文本做对比）
    func evaluatePronunciation(audioURL: URL, referenceText: String) async throws -> PronunciationResult {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    cont.resume(returning: result)
                }
            }
        }

        let recognized = result.bestTranscription.formattedString
        return buildAssessment(recognized: recognized, reference: referenceText, confidence: result.bestTranscription.segments.map(\.confidence))
    }

    // MARK: - 评分算法

    /// 根据识别文本与参考文本做对比评分
    private func buildAssessment(recognized: String, reference: String, confidence: [Float]) -> PronunciationResult {
        let refWords = normalizeWords(reference)
        let recWords = normalizeWords(recognized)

        // 逐词对比
        var wordScores: [WordScore] = []
        var matchCount = 0

        for (i, refWord) in refWords.enumerated() {
            if i < recWords.count {
                let recWord = recWords[i]
                let isMatch = refWord.lowercased() == recWord.lowercased()
                if isMatch { matchCount += 1 }
                wordScores.append(WordScore(word: refWord, recognized: recWord, isCorrect: isMatch))
            } else {
                // 漏读
                wordScores.append(WordScore(word: refWord, recognized: nil, isCorrect: false))
            }
        }

        // 多读的词
        if recWords.count > refWords.count {
            for i in refWords.count..<recWords.count {
                wordScores.append(WordScore(word: "", recognized: recWords[i], isCorrect: false))
            }
        }

        // 计算各项分数
        let totalRefWords = max(refWords.count, 1)

        // 准确度：正确词 / 识别词数
        let totalRecWords = max(recWords.count, 1)
        let accuracyRaw = Double(matchCount) / Double(totalRecWords) * 100
        let accuracyScore = min(100, Int(accuracyRaw))

        // 完整度：识别到的正确词 / 参考文本词数
        let completenessRaw = Double(matchCount) / Double(totalRefWords) * 100
        let completenessScore = min(100, Int(completenessRaw))

        // 流利度：基于置信度的平均值
        let avgConfidence = confidence.isEmpty ? 0.5 : Double(confidence.reduce(0, +)) / Double(confidence.count)
        let fluencyScore = min(100, Int(avgConfidence * 100))

        // 总分：加权平均
        let overallScore = Int(Double(accuracyScore) * 0.4 + Double(completenessScore) * 0.35 + Double(fluencyScore) * 0.25)

        // 生成反馈
        let feedback = generateFeedback(accuracy: accuracyScore, completeness: completenessScore, fluency: fluencyScore, wordScores: wordScores)

        return PronunciationResult(
            recognizedText: recognized,
            referenceText: reference,
            overallScore: overallScore,
            accuracyScore: accuracyScore,
            completenessScore: completenessScore,
            fluencyScore: fluencyScore,
            wordScores: wordScores,
            feedback: feedback
        )
    }

    /// 分词 & 规范化
    private func normalizeWords(_ text: String) -> [String] {
        text .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }
    }

    /// 根据各维度分数生成中文反馈
    private func generateFeedback(accuracy: Int, completeness: Int, fluency: Int, wordScores: [WordScore]) -> String {
        var parts: [String] = []

        if accuracy >= 90 {
            parts.append("发音非常准确 👍")
        } else if accuracy >= 75 {
            parts.append("发音基本准确")
        } else {
            let wrongWords = wordScores.filter { !$0.isCorrect && $0.recognized != nil }
                .prefix(3)
                .map { "\"\($0.word)\"" }
                .joined(separator: "、")
            if !wrongWords.isEmpty {
                parts.append("注意以下单词的发音：\(wrongWords)")
            } else {
                parts.append("发音需要加强练习")
            }
        }

        if completeness < 80 {
            let missed = wordScores.filter { $0.recognized == nil }
                .prefix(3)
                .map { "\"\($0.word)\"" }
                .joined(separator: "、")
            if !missed.isEmpty {
                parts.append("漏读了：\(missed)")
            } else {
                parts.append("尝试把句子读完整")
            }
        }

        if fluency >= 85 {
            parts.append("语速流畅自然")
        } else if fluency < 60 {
            parts.append("建议多听原音，模仿语速和节奏")
        }

        return parts.joined(separator: "。") + "。"
    }
}

// MARK: - 错误类型

enum SpeechError: LocalizedError {
    case recognizerUnavailable
    case requestCreationFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable: return "语音识别服务不可用"
        case .requestCreationFailed: return "无法创建识别请求"
        case .permissionDenied: return "语音识别权限被拒绝"
        }
    }
}
