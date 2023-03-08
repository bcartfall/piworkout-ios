//
//  VLCPlayerController.swift
//  piworkout-ios
//
//  Created by Bryan on 2023-03-01.
//

import SwiftUI
import MobileVLCKit

class VLCPLayerController: ObservableObject {
    @Published var showSettingsView = false
    @Published var connected = false
    
    @AppStorage("serverHost") private var serverHost = ""
    @AppStorage("muted") private var muted = true
    @AppStorage("videoQuality") private var videoQuality = "4K"
    let player: VLCMediaPlayer = VLCMediaPlayer()
    enum Orientation {
        case portrait
        case landscape
    }
    private var orientation: Orientation
    private var _observer: NSObjectProtocol?
    
    /// Variables to manage playback and videos from server
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var videos: [VideoData] = []
    private var pingStart: Double = 0
    private var serverLatency: Int = 0
    public var currentVideo: VideoData?
    private var diffSyncWait: Double = 0
    private var playbackSpeed: Float = 1
    private var diffQueue: [Int] = []
    public var firstFrame = 0
    private var status: Int = -1

    init() {
        // determine orientation
        let w = UIScreen.main.bounds.size.width
        let h = UIScreen.main.bounds.size.height
        if (w > h) {
            orientation = .landscape
        } else {
            orientation = .portrait
        }
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        print("Setup")
        if (connected) {
            self.openWebSocket()
            return
        }
                 
        _observer = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: nil) { [unowned self] note in
            guard let device = note.object as? UIDevice else {
                return
            }
            if device.orientation.isPortrait {
                self.orientation = .portrait
            } else if device.orientation.isLandscape {
                self.orientation = .landscape
            }
            self.setScale()
        }
                        
        // open websocket
        self.openWebSocket()
    }
    
    deinit {
        if let observer = _observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func play() {
        player.play()
        if (muted) {
            print("Muting audio")
            player.audio.volume = 0
        } else {
            print("Not muted")
            player.audio.volume = 100
        }
    }
    
    func stop() {
        player.stop()
    }
    
    func setScale() {
        if (currentVideo == nil) {
            player.scaleFactor = 0
            return
        }
        
        // fill space
        player.scaleFactor = 0
    }
    
    func showSettings() {
        release()
        showSettingsView = true
    }
    
    /// free resources
    func release() {
        print("release")
        //currentVideo = nil
        //connected = false
        player.pause()
        session?.invalidateAndCancel()
        webSocket?.cancel()
        
        webSocket = nil
    }

    /// Open a new websocket and wait for messages from server
    func openWebSocket() {
        print("openWebSocket serverHost=" + serverHost + ", muted=" + String(muted))
        if (serverHost == "") {
            return
        }
        let urlString = "ws://" + serverHost + "/backend"
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            self.session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
            let webSocket = self.session!.webSocketTask(with: request)
            self.webSocket = webSocket
            webSocket.resume()
            connected = true
            
            //let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] timer in
            //    self?.sendPing()
            //}
            //timer.fire()
            
            receiveMessage()
        }
    }
    
    func receiveMessage() {
        webSocket?.receive(completionHandler: { [weak self] result in
            switch result {
            case .failure(let error):
                print("websocket failure: " + error.localizedDescription)
                self!.connected = false
                self?.player.pause()
                self?.webSocket?.cancel()
                self?.webSocket = nil
            case .success(let message):
                switch message {
                case .string(let messageString):
                    self?.handleMessage(messageString: messageString)
                case .data(let data):
                    print(data.description)
                default:
                    print("Unknown type received from WebSocket")
                }
            }
            
            if (self!.connected) {
                self?.receiveMessage()
            }
        })
    }
    
    func handleMessage(messageString: String) {
        let decoder = JSONDecoder()
        do {
            let nsMessage = try decoder.decode(NamespaceMessage.self, from: messageString.data(using: .utf8)!)
            
            //print("handleMessage() " + nsMessage.namespace)
            switch (nsMessage.namespace) {
            case "init": return self.handleInit(messageString: messageString)
            case "ping": return self.handlePing(messageString: messageString)
            case "videos": return self.handleVideos(messageString: messageString)
            case "player": return self.handlePlayer(messageString: messageString)
            default:
                print("namespace not handled.")
            }
        } catch {
            print(error)
        }
    }
    
    func handleInit(messageString: String) {
        let decoder = JSONDecoder()
        do {
            let initMessage = try decoder.decode(InitMessage.self, from: messageString.data(using: .utf8)!)
            
            self.videos = initMessage.data.videos
            actionPlayerData(playerData: initMessage.data.player)
            sendPing()
        } catch {
            print(error)
        }
    }
    
    func sendPing() {
        pingStart = CACurrentMediaTime()
        print("Sending ping " + String(pingStart))
        let uuid = UUID().uuidString
        webSocket?.send(URLSessionWebSocketTask.Message.string("{\"namespace\": \"ping\", \"uuid\": \"" + uuid + "\"}")) { [weak self] error in
            if let error = error {
                print("Failed with Error \(error.localizedDescription)")
            } else {
                // no-op
            }
        }
    }
    
    func handlePing(messageString: String) {
        serverLatency = Int(round((CACurrentMediaTime() - pingStart) * 1000))
        print("handlePing() latency=" + String(serverLatency))
    }
    
    func handleVideos(messageString: String) {
        do {
            let decoder = JSONDecoder()
            let videosMessage = try decoder.decode(VideosMessage.self, from: messageString.data(using: .utf8)!)
            videos = videosMessage.videos
        } catch {
            print(error)
        }
    }
    
    func getVideoById(id: Int) -> VideoData?
    {
        for (_, video) in videos.enumerated() {
            if (video.id == id) {
                return video
            }
        }
        return nil
    }
    
    func handlePlayer(messageString: String) {
        do {
            let decoder = JSONDecoder()
            let playerMessage = try decoder.decode(PlayerMessage.self, from: messageString.data(using: .utf8)!)
            actionPlayerData(playerData: playerMessage.player)
        } catch {
            print(error)
        }
    }
    
    func actionPlayerData(playerData: PlayerData) {
        status = playerData.status
        let action = playerData.action
        let pId = playerData.videoId
        let serverTime = Int(round(playerData.time * 1000)) + serverLatency
        
        if (currentVideo == nil || currentVideo?.id != playerData.videoId) {
            // change video
            let video = getVideoById(id: pId)
            if (video == nil) {
                return
            }
            currentVideo = video
            setScale()
            
            var format: String
            var maxSupportedHeight: Int
            if (videoQuality == "4K") {
                maxSupportedHeight = 2160
            } else if (videoQuality == "1440p") {
                maxSupportedHeight = 1440
            } else if (videoQuality == "1080p") {
                maxSupportedHeight = 1080
            } else {
                maxSupportedHeight = 720
            }
            
            let height = video!.height
            if (height >= 2160 && maxSupportedHeight > 1440) {
                format = "4K"
            } else if (height >= 1440 && maxSupportedHeight > 1080) {
                format = "1440p"
            } else if (height >= 1080 && maxSupportedHeight > 720) {
                format = "1080p"
            } else {
                format = "720p"
            }
            
            let filename = video!.filename
            
            let url: String = "http://" + serverHost + "/videos/" + String(pId) + "-" + format + "-" + filename
            
            print("handlePlayer() playing video " + url + " at serverTime=" + String(serverTime) + ", duration=" + String(video!.duration))
            
            let media = VLCMedia(url: URL(string: url)!)
            player.media = media
            
            print("Seeking to \(serverTime)")
            play()
            player.time = VLCTime(int: Int32(serverTime + 1000))
            
            if (status != Status.PLAYING.rawValue) {
                // load first frame
                firstFrame = 1
            }
            
            // must wait 2.5 before trying to catch up
            diffSyncWait = CACurrentMediaTime() + 2.5
        }
        
        if (status == Status.PLAYING.rawValue) {
            if (action == "progress") {
                if (!player.isPlaying) {
                    play()
                }
                let currentTime = player.time
                
                let clientTime = Int(currentTime!.intValue)
                let cDiff = serverTime - clientTime
                
                let now = CACurrentMediaTime()
                let minDiff: Int = 0
                let maxDiff: Int = 100
                
                if (now >= diffSyncWait) {
                    let count = diffQueue.count
                    diffQueue.append(cDiff)
                    if (diffQueue.count > 9) {
                        diffQueue.removeFirst()
                    }
                    
                    var aDiff = cDiff
                    if (count > 0) {
                        aDiff = diffQueue.reduce(0, +) / count
                    }
                    
                    if (abs(cDiff) > 10000) {
                        // diff is too large
                        print("Seeking to catch up \(serverTime)")
                        player.time = VLCTime(int: Int32(serverTime + 1000))
                        diffSyncWait = CACurrentMediaTime() + 2.5
                    }
                    
                    if (aDiff <= minDiff || aDiff >= maxDiff) {
                        var amount: Float = 0.25
                        if (abs(cDiff) > 1000) {
                            amount = 0.75
                        }
                        if (cDiff < minDiff) {
                            // slow player
                            let base: Int = min(-cDiff + minDiff, 1000 + minDiff)
                            let quotient: Int = 1000 + minDiff
                            playbackSpeed = 1.0 - (Float(base) / Float(quotient) * amount)
                            print("handlePlayer() out of sync, client is ahead, setting playbackSpeed=" + String(playbackSpeed))
                        } else if (cDiff > maxDiff) {
                            // increase
                            let base: Int = min(cDiff + maxDiff, 1000 + maxDiff)
                            let quotient: Int = 1000 + maxDiff
                            playbackSpeed = 1.0 + (Float(base) / Float(quotient) * amount)
                            print("handlePlayer() out of sync, server is ahead, setting playbackSpeed=" + String(playbackSpeed))
                        }
                        
                        player.rate = playbackSpeed
                    } else {
                        if (playbackSpeed != 1.0) {
                            playbackSpeed = 1.0;
                            player.rate = playbackSpeed
                        }
                    }
                    
                    print("handlePlayer() clientTime=" + String(clientTime) + ", serverTime=" + String(serverTime) + ", cDiff=" + String(cDiff) + ", aDiff=" + String(aDiff))
                }
                
            } else if (action == "seek") {
                diffSyncWait = CACurrentMediaTime() + 2.5
                player.time = VLCTime(int: Int32(serverTime + 500))
                diffQueue = []
            } else if (action == "play") {
                play()
            }
        } else if (action == "seek") {
            print("handlePlayer() Seeking")
            play()
            player.time = VLCTime(int: Int32(serverTime + 0))
            firstFrame = 1
        } else if ((status == Status.STOPPED.rawValue || status == Status.PAUSED.rawValue) && firstFrame == 0) {
            // pause video
            print("handlePlayer() Pausing video")
            player.pause()
        }
    }
    
    func onTimeChanged() {
        // if the server has a paused video we want vlc to render the first frame
        // the firstFrame allows us to wait for the player to present a frame before we pause
        if (firstFrame > 5) {
            firstFrame = 0
            if (status != Status.PLAYING.rawValue) {
                print("First frame has been rendered. Pausing.")
                player.pause()
            }
        } else {
            firstFrame += 1
        }
    }
}

/// Current Video Player State
enum Status: Int {
    case STOPPED = 1
    case PAUSED = 2
    case PLAYING = 3
    case ENDED = 4
}

/// Data for JSON from WebSocket
struct NamespaceMessage: Codable {
    let namespace: String
}

struct InitMessage: Codable {
    let data: InitData
}

struct InitData: Codable {
    let connected: Bool
    let videos: [VideoData]
    let player: PlayerData
}

struct VideoData: Codable {
    let id: Int
    let order: Int
    let videoId: String
    let source: String
    let url: String
    let filename: String
    let filesize: Int64
    let title: String
    let description: String
    let duration: Int
    let position: Float
    let width: Int
    let height: Int
    let tbr: Int
    let fps: Int
    let vcodec: String
    let status: Int
}

struct PingMessage: Codable {
    let uuid: String
}

struct VideosMessage: Codable {
    let videos: [VideoData]
}

struct PlayerMessage: Codable {
    let player: PlayerData
}

struct PlayerData: Codable {
    let time: Float
    let videoId: Int
    let status: Int
    let client: String
    let action: String
}
