import AVFoundation
import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var audioPlayer: AVPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // GOOGLE_MAPS_API_KEY must be set in Xcode build settings or via xcconfig.
    // Never hardcode the key here — use the Info.plist placeholder $(GOOGLE_MAPS_API_KEY).
    guard let mapsKey = Bundle.main.infoDictionary?["GOOGLE_MAPS_API_KEY"] as? String,
          !mapsKey.isEmpty else {
      assertionFailure("GOOGLE_MAPS_API_KEY is missing from Info.plist. Set it in Xcode build settings or via xcconfig.")
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    GMSServices.provideAPIKey(mapsKey)

    // Forzar renderer OpenGL en simuladores — Metal no renderiza en iOS Simulator
    #if targetEnvironment(simulator)
    GMSServices.setMetalRendererEnabled(false)
    #endif

    GeneratedPluginRegistrant.register(with: self)
    configureAudioPlayerChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureAudioPlayerChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "sacdia/audio_player",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleAudioPlayerCall(call, result: result)
    }
  }

  private func handleAudioPlayerCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "playUrl":
      guard
        let args = call.arguments as? [String: Any],
        let rawUrl = args["url"] as? String,
        let url = URL(string: rawUrl)
      else {
        result(FlutterError(code: "invalid_url", message: "Invalid audio URL", details: nil))
        return
      }

      do {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        // Playback can still work in many simulator/device states; keep going.
      }

      audioPlayer = AVPlayer(url: url)
      audioPlayer?.play()
      result(nil)

    case "pause":
      audioPlayer?.pause()
      result(nil)

    case "resume":
      audioPlayer?.play()
      result(nil)

    case "stop":
      audioPlayer?.pause()
      audioPlayer = nil
      result(nil)

    case "position":
      let positionSeconds = audioPlayer?.currentTime().seconds ?? 0
      let durationSeconds = audioPlayer?.currentItem?.duration.seconds ?? 0
      result([
        "positionMs": milliseconds(from: positionSeconds),
        "durationMs": milliseconds(from: durationSeconds),
        "isPlaying": audioPlayer?.timeControlStatus == .playing
      ])

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func milliseconds(from seconds: Double) -> Int {
    guard seconds.isFinite, seconds > 0 else {
      return 0
    }
    return Int(seconds * 1000)
  }
}
