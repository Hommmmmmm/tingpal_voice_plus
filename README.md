# tingpal_voice_plus

A new Flutter plugin project.

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/to/develop-plugins),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Native SDK layout

This plugin expects third-party native SDKs to be placed in platform folders:

- Android: `android/libs/`
- iOS: `ios/Frameworks/`
- Windows: `windows/third_party/iflytek_sdk/`

## Windows SDK requirements

The Windows CMake configuration links and bundles iFlytek SDK files from:

- Headers: `windows/third_party/iflytek_sdk/include/`
- Import libraries: `windows/third_party/iflytek_sdk/libs/`
- Runtime DLLs: `windows/third_party/iflytek_sdk/bin/`

Architecture mapping:

- x64 build: `msc_x64.lib` + `msc_x64.dll`
- x86 build: `msc.lib` + `msc.dll`

If these files are missing, CMake will fail fast with an explicit error.

## macOS (WebSocket 模式)

macOS 平台无需任何原生二进制闭源动态库，内部通过 macOS 原生 `AVAudioEngine` 采集音频并通过科大讯飞流式 WebSocket 协议进行实时语音听写。

### 1. 初始化鉴权凭证
初始化时通过 `appIdWeb`、`apiKeyWeb`、`apiSecretWeb` 传入凭证（与控制台一致）：

```dart
await TingpalVoiceClient.instance.init(
  appIdIos: 'your_ios_app_id',
  appIdAndroid: 'your_android_app_id',
  appIdWindows: 'your_windows_app_id',
  appIdWeb: 'your_xf_app_id',
  apiKeyWeb: 'your_xf_api_key',
  apiSecretWeb: 'your_xf_api_secret',
);
```

> 注：若习惯将凭证合并在 `appIdWeb` 中传递，插件亦支持传递包含凭证的 JSON 字符串（如 `{"appId":"...","apiKey":"...","apiSecret":"..."}`）或逗号分隔格式（`appId,apiKey,apiSecret`），内部会自动解析。

### 2. macOS 宿主应用权限配置
在接入的 Flutter macOS 宿主项目中，请配置麦克风与网络访问权限：

1. **`macos/Runner/Info.plist`** 添加麦克风权限说明：
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>应用需要麦克风权限以进行语音识别</string>
   ```

2. **`macos/Runner/DebugProfile.entitlements`** 和 **`Release.entitlements`** 开启沙盒音频与网络权限：
   ```xml
   <key>com.apple.security.device.audio-input</key>
   <true/>
   <key>com.apple.security.network.client</key>
   <true/>
   ```

