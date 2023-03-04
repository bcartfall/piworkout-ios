//
//  ContentView.swift
//  piworkout-ios
//
//  Created by Bryan on 2023-02-26.
//

import SwiftUI


struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    @StateObject var playerController: VLCPLayerController = VLCPLayerController()
    
    var body: some View {
        NavigationStack() {
            PlayerView()
            .navigationDestination(isPresented: $playerController.showSettingsView) {
                SettingsView()
            }
            .onLongPressGesture {
                playerController.showSettings()
            }
            .onDisappear {
                playerController.release()
            }.onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    playerController.setup()
                } else {
                    playerController.release()
                }
            }
        }
        .environmentObject(playerController)
        .ignoresSafeArea(.all)
        .persistentSystemOverlays(.hidden)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
