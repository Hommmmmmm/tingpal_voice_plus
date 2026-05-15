#ifndef FLUTTER_PLUGIN_TINGPAL_VOICE_PLUS_PLUGIN_H_
#define FLUTTER_PLUGIN_TINGPAL_VOICE_PLUS_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include "speech_recognizer.h"

#include <map>
#include <string>

#include <memory>

namespace tingpal_voice_plus {

class TingpalVoicePlusPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  TingpalVoicePlusPlugin();

  virtual ~TingpalVoicePlusPlugin();

  // Disallow copy and assign.
  TingpalVoicePlusPlugin(const TingpalVoicePlusPlugin&) = delete;
  TingpalVoicePlusPlugin& operator=(const TingpalVoicePlusPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  static void OnSdkResult(const char *result, char is_last);
  static void OnSdkSpeechBegin();
  static void OnSdkSpeechEnd(int reason);

  void HandleSdkResult(const char *result, bool is_last);
  void HandleSdkSpeechBegin();
  void HandleSdkSpeechEnd(int reason);

  bool EnsureLoggedIn();
  bool EnsureRecognizerReady();
  void ResetRecognizer();
  void LogoutSdk();
  std::string BuildSessionParams() const;
  std::string EncodableValueToString(const flutter::EncodableValue &value) const;
  flutter::EncodableMap BuildErrorPayload(int code, const std::string &desc) const;

  void EmitEvent(const std::string &event_name,
             flutter::EncodableMap payload);

  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_owner_;
  flutter::EventSink<flutter::EncodableValue> *event_sink_ = nullptr;
  speech_rec recognizer_{};
  speech_rec_notifier notifier_{};
  bool recognizer_ready_ = false;
  bool logged_in_ = false;
  bool is_listening_ = false;
  bool emit_completed_on_stop_ = false;
  std::string app_id_windows_;
  std::string audio_file_path_;
  std::map<std::string, flutter::EncodableValue> voice_options_;
};

}  // namespace tingpal_voice_plus

#endif  // FLUTTER_PLUGIN_TINGPAL_VOICE_PLUS_PLUGIN_H_
