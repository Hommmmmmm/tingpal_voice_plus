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

