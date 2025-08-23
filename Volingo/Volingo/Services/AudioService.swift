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
    func playWordPronunciation(_ word: String) {
        guard !word.isEmpty else { return }
        
        // 停止当前播放
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        // 创建语音合成请求
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // 美式英语
        utterance.rate = 0.45 // 设置语速为适中
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
    
    // 开始录音
    func startRecording() {
        // TODO: 实现录音功能
        print("🎤 开始录音...")
    }
    
    // 停止录音并返回音频数据
    func stopRecording() -> Data? {
        // TODO: 实现录音功能
        print("🎤 停止录音...")
        return nil
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
