//
//  AudioActor.swift
//  audioMaster
//
//  Created by Nyi Htet on 3/4/26.
//

import AVFoundation
import SwiftUI
import Speech

// enum type is condition
enum Condition {
    case idle
    case recording
    case dirrupted
    case pause
    case stopped
}

// condition should be observable as it will be tracked for animation purposes
// such as Live Activities and Dynamic Island animations.
actor AudioActor {
    let transcription = Transcription()
    private var state: Condition = .idle
    private var engine = AVAudioEngine()
    
    private var failureCounter: Int = 0
    
    private var recognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var audioFile: AVAudioFile?
    private var currentSegmentURL: URL?
    
    private func generateURL() -> URL {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return doc.appendingPathComponent("\(UUID().uuidString).wav")
    }
    
    private func makeAudioFile() throws {
        let url = generateURL()
        currentSegmentURL = url
        audioFile = try AVAudioFile(forWriting: url, settings: engine.inputNode.outputFormat(forBus: 0).settings)
    }
    
    func startRecording() async {
        //handle permission denial
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            print("Microphone should be allowed");
            return
        }
        
        
        do {
            print("Current mode: \(state)")
            try configureAudioSession()
            
            // fall back to local speech-to-text transcription model when the whisper transcription fails
            /*
            make audio file first
            after 30s
            
            close audio file
            send the url to whisper API
            make new audio file that is acceptable for next 30s
             
            After getting response from whisper
            display the text transcription in the terminal
            */
            Task {
                //loop it untill the user stops or the system is disrrupted
                while state == .recording {
                    do {
                        try makeAudioFile()
                        //after 30s, close audio file
                        try await Task.sleep(for: .seconds(30))
                        audioFile = nil
                        
                        let urlToSend = currentSegmentURL
                        guard let urlToSend else {return}
                        await transcription.transcribeAudio(url: urlToSend)
                    }
                    catch {
                        print("cannot make the audio file")
                    }
                }
                
                
                //display the response from the whisper in the terminal in the mean time
                //go to the top of the loop
            }
            
            
            //setUp the mic
            engine.inputNode.removeTap(onBus: 0)
            engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: engine.inputNode.outputFormat(forBus: 0)) { buffer, time in
                // saving it to audioFile
                // sending it to whisper API
                try? self.audioFile?.write(from: buffer)
            }
            try engine.start()
            state = .recording
        } catch {
            print("Some error happened")
        }
        
        
    }
    
    func endRecording() async {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        state = .stopped
    }
    
    private func configureAudioSession() throws {
        // continuation of audio recording while in background
        // bluetooth connection, headphone connection
        // quality raw input with preprocessing
        
        let session = AVAudioSession.sharedInstance()
        // handling the error
        try session.setCategory(.playAndRecord, mode:.measurement, options: [
            .allowBluetoothHFP
        ])
        try session.setActive(true);
        
        
    }
}
