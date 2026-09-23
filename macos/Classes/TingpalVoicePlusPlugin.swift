import Cocoa
import FlutterMacOS
import AVFoundation
import CryptoKit

public class TingpalVoicePlusPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  
  private var appId: String = ""
  private var apiKey: String = ""
  private var apiSecret: String = ""
  private var options: [String: Any] = [:]
  
  private let audioEngine = AVAudioEngine()
  private var audioConverter: AVAudioConverter?
  private var targetAudioFormat: AVAudioFormat?
  private var audioFileHandle: FileHandle?
  private var fullAudioFilePath: String = ""
  
  private let audioQueue = DispatchQueue(label: "com.tingpal.tingpal_voice_plus.audio")
  private var webSocketTask: URLSessionWebSocketTask?
  private var urlSession: URLSession?
  
  private var isListening: Bool = false
  private var isStopping: Bool = false
  private var isFirstFrame: Bool = true
  private var pcmAccumulator: Data = Data()
  private var lastVolumeEmitTime: TimeInterval = 0
  private var cachedResultText: String?
  private var speechBeganEmitted: Bool = false
  private var speechEndedEmitted: Bool = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "tingpal_voice_plus",
      binaryMessenger: registrar.messenger
    )
    let eventChannel = FlutterEventChannel(
      name: "tingpal_voice_plus/events",
      binaryMessenger: registrar.messenger
    )

    let instance = TingpalVoicePlusPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "init":
      if let args = call.arguments as? [String: Any] {
        parseCredentials(args: args)
      }
      result(nil)
    case "setOptions":
      if let args = call.arguments as? [String: Any] {
        self.options = args
      }
      result(nil)
    case "startListening":
      if isListening {
        result(nil)
        return
      }
      startListeningFlow()
      result(nil)
    case "stopListening":
      stopListeningFlow()
      result(nil)
    case "cancelListening":
      cancelListeningFlow()
      result(nil)
    case "disposeClient":
      disposeFlow()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Credentials Parsing

  private func parseCredentials(args: [String: Any]) {
    var rawAppId = (args["appIdWeb"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    var rawApiKey = (args["apiKeyWeb"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    var rawApiSecret = (args["apiSecretWeb"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

    // Fallback: If appIdWeb contains JSON or delimited string
    if (rawApiKey.isEmpty || rawApiSecret.isEmpty) && !rawAppId.isEmpty {
      if let data = rawAppId.data(using: .utf8),
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let id = json["appId"] as? String ?? json["appid"] as? String {
          rawAppId = id
        }
        if let key = json["apiKey"] as? String ?? json["apikey"] as? String ?? json["key"] as? String {
          rawApiKey = key
        }
        if let sec = json["apiSecret"] as? String ?? json["apisecret"] as? String ?? json["secret"] as? String {
          rawApiSecret = sec
        }
      } else if rawAppId.contains(",") || rawAppId.contains(";") || rawAppId.contains("|") {
        let delimiter: Character = rawAppId.contains(",") ? "," : (rawAppId.contains(";") ? ";" : "|")
        let parts = rawAppId.split(separator: delimiter).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.count >= 3 {
          rawAppId = parts[0]
          rawApiKey = parts[1]
          rawApiSecret = parts[2]
        }
      }
    }

    self.appId = rawAppId
    self.apiKey = rawApiKey
    self.apiSecret = rawApiSecret
  }

  // MARK: - FlutterStreamHandler

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  private func emitEvent(_ event: String, payload: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let sink = self.eventSink else { return }
      var map = payload
      map["event"] = event
      sink(map)
    }
  }

  // MARK: - Flow Control

  private func startListeningFlow() {
    guard !appId.isEmpty && !apiKey.isEmpty && !apiSecret.isEmpty else {
      emitEvent("onCompleted", payload: [
        "error": [
          "code": 10001,
          "desc": "缺少科大讯飞 WebSocket 鉴权凭证 (appIdWeb, apiKeyWeb, apiSecretWeb)"
        ],
        "audioFilePath": ""
      ])
      return
    }

    cachedResultText = nil
    speechBeganEmitted = false
    speechEndedEmitted = false
    isStopping = false

    // Request microphone permission on macOS
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      self.startEngineAndWebSocket()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
        DispatchQueue.main.async {
          if granted {
            self?.startEngineAndWebSocket()
          } else {
            self?.emitEvent("onCompleted", payload: [
              "error": ["code": 10002, "desc": "麦克风权限被拒绝"],
              "audioFilePath": ""
            ])
          }
        }
      }
    case .denied, .restricted:
      emitEvent("onCompleted", payload: [
        "error": ["code": 10002, "desc": "麦克风权限被拒绝，请在系统设置中允许访问麦克风"],
        "audioFilePath": ""
      ])
    @unknown default:
      emitEvent("onCompleted", payload: [
        "error": ["code": 10002, "desc": "未知的麦克风权限状态"],
        "audioFilePath": ""
      ])
    }
  }

  private func startEngineAndWebSocket() {
    guard let wsUrl = buildHandshakeURL() else {
      emitEvent("onCompleted", payload: [
        "error": ["code": 10003, "desc": "生成 WebSocket 鉴权 URL 失败"],
        "audioFilePath": ""
      ])
      return
    }

    prepareAudioFile()

    if urlSession == nil {
      let config = URLSessionConfiguration.default
      urlSession = URLSession(configuration: config)
    }

    let request = URLRequest(url: wsUrl, timeoutInterval: 10)
    webSocketTask = urlSession?.webSocketTask(with: request)
    webSocketTask?.resume()

    isListening = true
    isFirstFrame = true
    pcmAccumulator = Data()

    receiveWebSocketMessages()
    startAudioRecording()
  }

  private func stopListeningFlow() {
    guard isListening else { return }
    isStopping = true
    isListening = false

    stopAudioRecording()

    // Send final frame (status: 2)
    audioQueue.async { [weak self] in
      guard let self = self else { return }
      let remaining = self.pcmAccumulator
      self.pcmAccumulator = Data()
      self.sendAudioFrame(data: remaining, status: 2)
    }

    if !speechEndedEmitted {
      speechEndedEmitted = true
      emitEvent("onEndOfSpeech", payload: [:])
    }
  }

  private func cancelListeningFlow() {
    isListening = false
    isStopping = false
    stopAudioRecording()
    cleanupWebSocket()
    closeAudioFile()
    emitEvent("onCancel", payload: [:])
  }

  private func disposeFlow() {
    cancelListeningFlow()
    urlSession?.invalidateAndCancel()
    urlSession = nil
    appId = ""
    apiKey = ""
    apiSecret = ""
    options.removeAll()
  }

  // MARK: - Audio Recording

  private func prepareAudioFile() {
    fullAudioFilePath = ""
    closeAudioFile()

    if let asrPath = options["asr_audio_path"] as? String, !asrPath.isEmpty {
      if asrPath.hasPrefix("/") {
        fullAudioFilePath = asrPath
      } else {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path ?? NSTemporaryDirectory()
        fullAudioFilePath = (cacheDir as NSString).appendingPathComponent(asrPath)
      }

      let fileURL = URL(fileURLWithPath: fullAudioFilePath)
      let parentDir = fileURL.deletingLastPathComponent()
      try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
      FileManager.default.createFile(atPath: fullAudioFilePath, contents: nil, attributes: nil)
      audioFileHandle = FileHandle(forWritingAtPath: fullAudioFilePath)
    }
  }

  private func closeAudioFile() {
    try? audioFileHandle?.close()
    audioFileHandle = nil
  }

  private func startAudioRecording() {
    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)

    guard inputFormat.sampleRate > 0 else {
      handleComplete(code: 10004, desc: "音频输入设备未就绪 (sampleRate == 0)")
      return
    }

    guard let targetFormat = AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: 16000,
      channels: 1,
      interleaved: true
    ) else {
      handleComplete(code: 10005, desc: "无法创建 16kHz 16-bit 目标音频格式")
      return
    }

    self.targetAudioFormat = targetFormat
    self.audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat)

    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
      self?.audioQueue.async {
        self?.processAudioTap(buffer: buffer)
      }
    }

    do {
      try audioEngine.start()
    } catch {
      handleComplete(code: 10006, desc: "启动 AVAudioEngine 失败: \(error.localizedDescription)")
    }
  }

  private func stopAudioRecording() {
    if audioEngine.isRunning {
      audioEngine.inputNode.removeTap(onBus: 0)
      audioEngine.stop()
    }
  }

  private func processAudioTap(buffer: AVAudioPCMBuffer) {
    guard isListening, let converter = self.audioConverter, let targetFormat = self.targetAudioFormat else { return }

    let ratio = 16000.0 / buffer.format.sampleRate
    let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 128
    guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else { return }

    var hasSuppliedInput = false
    var error: NSError?
    converter.convert(to: outputBuffer, error: &error) { _, outStatus in
      if hasSuppliedInput {
        outStatus.pointee = .noDataNow
        return nil
      }
      hasSuppliedInput = true
      outStatus.pointee = .haveData
      return buffer
    }

    if error != nil {
      return
    }

    guard let channelData = outputBuffer.int16ChannelData else { return }
    let sampleCount = Int(outputBuffer.frameLength)
    guard sampleCount > 0 else { return }

    let byteCount = sampleCount * MemoryLayout<Int16>.size
    let pcmChunk = Data(bytes: channelData.pointee, count: byteCount)

    // Save to audio file if configured
    audioFileHandle?.write(pcmChunk)

    // Calculate volume (RMS)
    let samples = channelData.pointee
    var sum: Double = 0
    for i in 0..<sampleCount {
      let s = Double(samples[i])
      sum += s * s
    }
    let rms = sqrt(sum / Double(sampleCount))
    let volume = min(30, max(0, Int(rms / 1000.0)))

    let now = Date().timeIntervalSince1970
    if now - lastVolumeEmitTime >= 0.1 {
      lastVolumeEmitTime = now
      emitEvent("onVolumeChanged", payload: ["volume": volume])
    }

    // Accumulate PCM data and send ~40ms (1280 bytes) per frame
    pcmAccumulator.append(pcmChunk)
    let frameSize = 1280

    if isFirstFrame {
      if !speechBeganEmitted {
        speechBeganEmitted = true
        emitEvent("onBeginOfSpeech", payload: [:])
      }
      let sendData = pcmAccumulator.prefix(frameSize)
      pcmAccumulator.removeFirst(min(frameSize, pcmAccumulator.count))
      sendAudioFrame(data: sendData, status: 0)
      isFirstFrame = false
    }

    while pcmAccumulator.count >= frameSize && isListening {
      let sendData = pcmAccumulator.prefix(frameSize)
      pcmAccumulator.removeFirst(frameSize)
      sendAudioFrame(data: sendData, status: 1)
    }
  }

  // MARK: - WebSocket Communication

  private func buildHandshakeURL() -> URL? {
    let host = "iat-api.xfyun.cn"
    let path = "/v2/iat"

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US")
    dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
    dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
    let dateString = dateFormatter.string(from: Date())

    let signatureOrigin = "host: \(host)\ndate: \(dateString)\nGET \(path) HTTP/1.1"
    let key = SymmetricKey(data: Data(apiSecret.utf8))
    let signature = HMAC<SHA256>.authenticationCode(for: Data(signatureOrigin.utf8), using: key)
    let signatureBase64 = Data(signature).base64EncodedString()

    let authOrigin = "api_key=\"\(apiKey)\", algorithm=\"hmac-sha256\", headers=\"host date request-line\", signature=\"\(signatureBase64)\""
    let authBase64 = Data(authOrigin.utf8).base64EncodedString()

    var components = URLComponents(string: "wss://\(host)\(path)")
    components?.queryItems = [
      URLQueryItem(name: "authorization", value: authBase64),
      URLQueryItem(name: "date", value: dateString),
      URLQueryItem(name: "host", value: host)
    ]
    return components?.url
  }

  private func sendAudioFrame(data: Data, status: Int) {
    guard let ws = webSocketTask else { return }

    var payload: [String: Any] = [:]
    let base64Audio = data.base64EncodedString()

    if status == 0 {
      var business: [String: Any] = [
        "language": options["language"] as? String ?? "zh_cn",
        "domain": options["domain"] as? String ?? "iat",
        "accent": options["accent"] as? String ?? "mandarin",
        "dwa": options["dwa"] as? String ?? "wpgs"
      ]
      if let vadEos = options["vad_eos"] as? Int {
        business["vad_eos"] = vadEos
      }

      payload = [
        "common": ["app_id": appId],
        "business": business,
        "data": [
          "status": 0,
          "format": "audio/L16;rate=16000",
          "encoding": "raw",
          "audio": base64Audio
        ]
      ]
    } else {
      payload = [
        "data": [
          "status": status,
          "format": "audio/L16;rate=16000",
          "encoding": "raw",
          "audio": base64Audio
        ]
      ]
    }

    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
          let jsonString = String(data: jsonData, encoding: .utf8) else { return }

    ws.send(.string(jsonString)) { error in
      if let error = error {
        print("[tingpal_voice_plus_macos] WebSocket send error: \(error.localizedDescription)")
      }
    }
  }

  private func receiveWebSocketMessages() {
    webSocketTask?.receive { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .failure(let error):
        if self.isListening || self.isStopping {
          self.handleComplete(code: -1, desc: "WebSocket 连接异常: \(error.localizedDescription)")
        }
      case .success(let message):
        switch message {
        case .string(let text):
          self.parseWebSocketResponse(text)
        case .data(let data):
          if let text = String(data: data, encoding: .utf8) {
            self.parseWebSocketResponse(text)
          }
        @unknown default:
          break
        }
        if self.isListening || self.isStopping {
          self.receiveWebSocketMessages()
        }
      }
    }
  }

  private func parseWebSocketResponse(_ text: String) {
    guard let data = text.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

    let code = json["code"] as? Int ?? 0
    if code != 0 {
      let desc = json["message"] as? String ?? "Xunfei error \(code)"
      handleComplete(code: code, desc: desc)
      return
    }

    guard let dataObj = json["data"] as? [String: Any] else { return }
    let status = dataObj["status"] as? Int ?? 1
    var isLast = (status == 2)

    if let resultObj = dataObj["result"] {
      var resultJsonString = ""
      if let resultData = try? JSONSerialization.data(withJSONObject: resultObj),
         let resStr = String(data: resultData, encoding: .utf8) {
        resultJsonString = resStr
      }

      if let resDict = resultObj as? [String: Any], let ls = resDict["ls"] as? Bool, ls {
        isLast = true
      }

      cachedResultText = resultJsonString
      emitEvent("onResults", payload: [
        "result": resultJsonString,
        "isLast": isLast
      ])
    }

    if isLast {
      handleComplete(code: 0, desc: "")
    }
  }

  private func handleComplete(code: Int, desc: String) {
    let hadBeenActive = isListening || isStopping
    isListening = false
    isStopping = false

    stopAudioRecording()
    cleanupWebSocket()
    closeAudioFile()

    if !speechEndedEmitted && hadBeenActive {
      speechEndedEmitted = true
      emitEvent("onEndOfSpeech", payload: [:])
    }

    var errorPayload: [String: Any] = [:]
    if code != 0 {
      errorPayload = [
        "code": code,
        "type": 0,
        "desc": desc
      ]
    }

    emitEvent("onCompleted", payload: [
      "error": errorPayload,
      "audioFilePath": fullAudioFilePath
    ])
  }

  private func cleanupWebSocket() {
    webSocketTask?.cancel(with: .goingAway, reason: nil)
    webSocketTask = nil
  }
}
