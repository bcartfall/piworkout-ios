//
//  PlayerView.swift
//  piworkout-ios
//
//  Created by Bryan on 2023-02-28.
//

import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var playerController: VLCPLayerController
        
    var body: some View {
        VStack {
            VLCPlayerView().frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            
            if (!playerController.connected) {
                HStack {
                    Button("Settings") {
                        playerController.showSettings()
                    }
                }.padding()
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
        .statusBarHidden(true)
    }
}
