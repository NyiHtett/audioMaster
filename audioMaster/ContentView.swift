//
//  ContentView.swift
//  audioMaster
//
//  Created by Nyi Htet on 3/3/26.
//
import AVFoundation
import SwiftUI
import Speech


struct ContentView: View {
    @State private var audio = AudioActor()  // initialize the audio system domain layer
    @State private var displayText: String = "this is the starting point"
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button {
                Task {
                    await audio.startRecording();
                }
            } label: {
                Image(systemName: "mic")
            }
            Text(displayText)
        }
        .padding()
        .task{
            for await text in await audio.transcription.stream {
                displayText = text
            }
        }
    }
}

#Preview {
    ContentView()
}
