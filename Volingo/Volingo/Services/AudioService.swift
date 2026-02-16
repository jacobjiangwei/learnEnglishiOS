//
//  AudioService.swift
//  Volingo
//
//  Created by jacob on 2025/8/23.
//

import Foundation
import AVFoundation

// MARK: - 音频服务
class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()
    private var player: AVAudioPlayer?
    private var speechSynthesizer = AVSpeechSynthesizer()
    
    @Published var isPlaying = false
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ 音频会话设置失败: \(error)")
        }
    }
    
    // 使用系统语音合成播放单词发音
    func playWordPronunciation(_ word: String, rate: Float = 0.5) {
        guard !word.isEmpty else { return }
        
        // 停止当前播放
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        // 创建语音合成请求
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // 美式英语
        utterance.rate = rate
        utterance.pitchMultiplier = 1.1 // 增加音调
        utterance.volume = 1.0 // 音量从 0 到 1
        
        isPlaying = true
        
        // 设置代理来监听播放完成
        speechSynthesizer.delegate = self
        speechSynthesizer.speak(utterance)
    }
    
    // 播放音频文件（如果有本地音频文件）
    func playAudio(url: String) {
        guard let audioURL = URL(string: url) else {
            print("❌ 无效的音频URL: \(url)")
            return
        }
        
        // 如果是网络URL，需要先下载
        if audioURL.scheme == "http" || audioURL.scheme == "https" {
            playRemoteAudio(url: audioURL)
        } else {
            playLocalAudio(url: audioURL)
        }
    }
    
    private func playLocalAudio(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            
            isPlaying = true
            player?.play()
        } catch {
            print("❌ 播放本地音频失败: \(error)")
            isPlaying = false
        }
    }
    
    private func playRemoteAudio(url: URL) {
        // 简单的网络音频播放实现
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("❌ 下载音频失败: \(error?.localizedDescription ?? "未知错误")")
                DispatchQueue.main.async {
                    self?.isPlaying = false
                }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    self?.player = try AVAudioPlayer(data: data)
                    self?.player?.delegate = self
                    self?.player?.prepareToPlay()
                    self?.isPlaying = true
                    self?.player?.play()
                } catch {
                    print("❌ 播放网络音频失败: \(error)")
                    self?.isPlaying = false
                }
            }
        }.resume()
    }
    
    // 停止播放
    func stopPlaying() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        player?.stop()
        isPlaying = false
    }

    // MARK: - 录音功能

    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    @Published var isRecording = false
    @Published var recordedFileURL: URL?

    /// 录音文件存储路径
    private var recordingURL: URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("volingo_recording.wav")
    }

    /// 切换音频会话为录音模式
    private func setupRecordingSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ 录音会话设置失败: \(error)")
        }
    }

    /// 切换回播放会话
    private func restorePlaybackSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ 恢复播放会话失败: \(error)")
        }
    }

    /// 开始录音（使用 AVAudioRecorder）
    func startRecording() {
        stopPlaying()
        setupRecordingSession()

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordedFileURL = nil
            print("🎤 开始录音...")
        } catch {
            print("❌ 开始录音失败: \(error)")
            isRecording = false
        }
    }

    /// 停止录音并返回音频文件 URL
    @discardableResult
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        restorePlaybackSession()

        if FileManager.default.fileExists(atPath: recordingURL.path) {
            recordedFileURL = recordingURL
            print("🎤 录音已保存: \(recordingURL)")
            return recordingURL
        }
        return nil
    }

    /// 播放录音回放
    func playRecording() {
        guard let url = recordedFileURL else { return }
        playLocalAudio(url: url)
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension AudioService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ 音频播放解码错误: \(error?.localizedDescription ?? "未知错误")")
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}
