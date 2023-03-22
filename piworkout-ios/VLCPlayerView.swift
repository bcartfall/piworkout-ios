//
//  VLCPlayer.swift
//  piworkout-ios
//
//  Created by Bryan on 2023-02-28.
//

import SwiftUI
import MobileVLCKit

struct VLCPlayerView: UIViewRepresentable {
    @EnvironmentObject var playerController: VLCPLayerController

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<VLCPlayerView>) {
        // play / pause
    }

    func makeUIView(context: Context) -> UIView {
        //let uiView = PlayerUIView(frame: .infinite, serverHost: serverHost, muted: muted, videoQuality: videoQuality)
        let uiView = PlayerUIView(frame: .infinite, playerController: playerController)
        return uiView
    }
}

class PlayerUIView: UIView {
    private var playerController: VLCPLayerController
    
    init(frame: CGRect, playerController: VLCPLayerController) {
        self.playerController = playerController
        super.init(frame: frame)
        
        self.playerController.uiView = self
        self.playerController.player.delegate = self
        self.playerController.player.drawable = self
        
        self.playerController.setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PlayerUIView: VLCMediaPlayerDelegate, URLSessionDelegate {
    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        playerController.onTimeChanged()
    }
}
