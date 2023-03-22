//
//  SettingsView.swift
//  piworkout-ios
//
//  Created by Bryan on 2023-02-28.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var playerController: VLCPLayerController
    @AppStorage("serverHost") private var serverHost = ""
    @AppStorage("muted") private var muted = true
    @AppStorage("videoQuality") private var videoQuality = "4K"
    @AppStorage("ssl") private var ssl = true
    
    let qualities = ["4K", "1440p", "1080p", "720p"]

    var body: some View {
        Form {
            Section(header: Text("Server Settings")) {
                TextField("Server Host", text: $serverHost)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                Toggle(isOn: $ssl) {
                    Text("SSL")
                }
            }
            Section(header: Text("Player Settings")) {
                Picker("Video Quality", selection: $videoQuality) {
                    ForEach(qualities, id: \.self) {
                        Text($0)
                    }
                }
                Toggle(isOn: $muted) {
                    Text("Muted")
                }
            }
        }.onDisappear {
            print("Settings went away")
            playerController.openWebSocket()
        }
    }
}
