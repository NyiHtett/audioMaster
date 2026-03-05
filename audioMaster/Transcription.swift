//
//  Transcription.swift
//  audioMaster
//
//  Created by Nyi Htet on 3/4/26.
//
import SwiftUI
import Speech
actor Transcription {
    private var key = "sk_a8c29e8edff58c093c0260317421df97d29c560a9cd44408"
    private var failureCounter: Int = 0
    private var recognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechURLRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var text: String = ""
    // just like useState in react, for setting new value - pipe inlet
    private var continuation: AsyncStream<String>.Continuation?
    
    // lazy function for making efficient function
    lazy var stream: AsyncStream<String> = AsyncStream { continuation in
        self.continuation = continuation
    }
    
    func transcribeAudio(url: URL) async {
        if(failureCounter < 6) {
            await sendToWhisper(url: url)
        } else {
            await appleLocalTranscription(url: url)
        }
    }
    private func sendToWhisper(url: URL) async {
        /*
         1. read the .wav audio data
         2. build multipart/form-data
         3. Send it to openAI
         4. Decode the data in text
         5. emit it to update to the main View
         */
        do {
            let audioData = try Data(contentsOf: url)
            let boundary  = UUID().uuidString
            
            var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!)
            
            request.httpMethod = "POST"
            request.setValue(key, forHTTPHeaderField: "xi-api-key")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            // body data
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model_id\"\r\n\r\n".data(using: .utf8)!)
            body.append("scribe_v2\r\n".data(using: .utf8)!)

            // file field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("fetching data in whisper is failed")
                print("Number of elevenLabs errors: \(failureCounter)")
                let errorBody = String(data: data, encoding: .utf8) ?? "unreadable"
                print("status Code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                print("error Code: \(errorBody)")
                failureCounter += 1
                return
            }
            
            let result = try JSONDecoder().decode(ElevenLabsResponse.self, from: data)
            emit(result.text)
        } catch {
            print("Whisper error \(error)")
            failureCounter+=1
            print("Number of elevenLabs errors: \(failureCounter)")
        }
    }
    
    private struct ElevenLabsResponse: Decodable {
        let text: String
    }
    
    private func appleLocalTranscription(url: URL) async {
        await withCheckedContinuation { continuation in
            //initiate request for input
            recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
            recognitionRequest?.shouldReportPartialResults = false
            //preparing processing for whenever buffer comes in
            recognitionTask = recognizer?.recognitionTask(with: recognitionRequest!) { result, error in
                if result?.isFinal == true {
                    if let text = result?.bestTranscription.formattedString {
                        print(text)
                        Task {
                            self.emit(text)
                        }
                        
                        // made sure result is in the final stage
                        continuation.resume()
                    }
                    if error != nil {
                        continuation.resume()
                    }
                }
        }
        }
    }
    
    private func emit(_ newText: String) {
        text = newText
        continuation?.yield(newText)
    }
}
