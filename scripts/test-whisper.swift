#!/usr/bin/env swift
// Minimal test: load whisper model and transcribe silence to check for crash
import Foundation

let modelPath = NSString("~/Library/Application Support/Murmur/Models/ggml-large-v3-turbo.bin").expandingTildeInPath

guard FileManager.default.fileExists(atPath: modelPath) else {
    print("Model not found at \(modelPath)")
    exit(1)
}

print("Model exists at \(modelPath)")
print("Test: the app crashes during whisper_full transcription.")
print("This script can't directly call whisper_full without linking SwiftWhisper.")
print("Use the app binary with a synthetic audio test instead.")
