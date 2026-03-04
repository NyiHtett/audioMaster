//
//  ContentView.swift
//  audioMaster
//
//  Created by Nyi Htet on 3/3/26.
//
import AVFoundation
import SwiftUI

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
    private var state: Condition = .idle
    func toggleAudio() {
        if state == .idle {
            state = .recording
        } else {
            state = .stopped
        }
    }
    func getState() -> Condition{
        return state
    }
    private func configureAudioSession() throws {
        // continuation of audio recording while in background
        // bluetooth connection, headphone connection
        // quality raw input with preprocessing
        
        let session = AVAudioSession.sharedInstance()
        // handling the error
        try session.setCategory(.playAndRecord, mode:.measurement, options: [
            .allowBluetoothHFP,
            .mixWithOthers
        ])
        try session.setActive(true);
    }
}


struct ContentView: View {
    @State private var actor = AudioActor()  // initialize the audio system domain layer
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button {
                Task {
                    await actor.toggleAudio()
                    print("Current mode: \(actor.getState())")
                }
            } label: {
                Image(systemName: "mic")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
