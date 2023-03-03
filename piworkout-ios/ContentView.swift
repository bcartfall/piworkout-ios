//
//  ContentView.swift
//  piworkout-ios
//
//  Created by Bryan on 2023-02-26.
//

import SwiftUI


struct ContentView: View {
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
