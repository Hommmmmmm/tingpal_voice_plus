#include "tingpal_voice_plus_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include "msp_cmn.h"
#include "msp_errors.h"

#include <flutter/event_stream_handler_functions.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cstring>
#include <memory>
#include <sstream>

namespace tingpal_voice_plus {

namespace {

TingpalVoicePlusPlugin* g_active_plugin = nullptr;

constexpr const char* kMethodInit = "init";
constexpr const char* kMethodSetOptions = "setOptions";
constexpr const char* kMethodStartListening = "startListening";
constexpr const char* kMethodStopListening = "stopListening";
constexpr const char* kMethodCancelListening = "cancelListening";
constexpr const char* kMethodDisposeClient = "disposeClient";

constexpr const char* kEventBeginOfSpeech = "onBeginOfSpeech";
constexpr const char* kEventEndOfSpeech = "onEndOfSpeech";
constexpr const char* kEventResults = "onResults";
constexpr const char* kEventCompleted = "onCompleted";
constexpr const char* kEventCancel = "onCancel";

}  // namespace

// static
void TingpalVoicePlusPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "tingpal_voice_plus",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<TingpalVoicePlusPlugin>();

  plugin->event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "tingpal_voice_plus/events",
          &flutter::StandardMethodCodec::GetInstance());

  plugin->event_channel_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [plugin_pointer = plugin.get()](
              const flutter::EncodableValue * /*arguments*/,
              std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>
                  &&events)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            plugin_pointer->event_sink_owner_ = std::move(events);
            plugin_pointer->event_sink_ =
                plugin_pointer->event_sink_owner_.get();
            return nullptr;
          },
          [plugin_pointer = plugin.get()](
              const flutter::EncodableValue * /*arguments*/)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            plugin_pointer->event_sink_owner_.reset();
            plugin_pointer->event_sink_ = nullptr;
            return nullptr;
          }));

  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

TingpalVoicePlusPlugin::TingpalVoicePlusPlugin() {}

TingpalVoicePlusPlugin::~TingpalVoicePlusPlugin() {
  if (g_active_plugin == this) {
    g_active_plugin = nullptr;
  }
  ResetRecognizer();
  LogoutSdk();
}

void TingpalVoicePlusPlugin::OnSdkResult(const char *result, char is_last) {
  if (g_active_plugin != nullptr) {
    g_active_plugin->HandleSdkResult(result, is_last != 0);
  }
}

void TingpalVoicePlusPlugin::OnSdkSpeechBegin() {
  if (g_active_plugin != nullptr) {
    g_active_plugin->HandleSdkSpeechBegin();
  }
}

void TingpalVoicePlusPlugin::OnSdkSpeechEnd(int reason) {
  if (g_active_plugin != nullptr) {
    g_active_plugin->HandleSdkSpeechEnd(reason);
  }
}

void TingpalVoicePlusPlugin::HandleSdkResult(const char *result, bool is_last) {
  EmitEvent(
      kEventResults,
      flutter::EncodableMap{{flutter::EncodableValue("result"),
                             flutter::EncodableValue(result == nullptr ? "" : result)},
                            {flutter::EncodableValue("isLast"),
                             flutter::EncodableValue(is_last)}});
}

void TingpalVoicePlusPlugin::HandleSdkSpeechBegin() {
  EmitEvent(kEventBeginOfSpeech, flutter::EncodableMap{});
}

void TingpalVoicePlusPlugin::HandleSdkSpeechEnd(int reason) {
  is_listening_ = false;

  if (reason == END_REASON_VAD_DETECT) {
    EmitEvent(kEventEndOfSpeech, flutter::EncodableMap{});
    EmitEvent(kEventCompleted,
              flutter::EncodableMap{{flutter::EncodableValue("error"),
                                     flutter::EncodableMap{}},
                                    {flutter::EncodableValue("audioFilePath"),
                                     flutter::EncodableValue(audio_file_path_)}});
    return;
  }

  EmitEvent(kEventCompleted,
            flutter::EncodableMap{{flutter::EncodableValue("error"),
                                   BuildErrorPayload(reason, "windows sdk error")},
                                  {flutter::EncodableValue("audioFilePath"),
                                   flutter::EncodableValue(audio_file_path_)}});
}

bool TingpalVoicePlusPlugin::EnsureLoggedIn() {
  if (logged_in_) {
    return true;
  }
  if (app_id_windows_.empty()) {
    return false;
  }

  std::ostringstream login_params;
  login_params << "appid = " << app_id_windows_;
  const int err = MSPLogin(nullptr, nullptr, login_params.str().c_str());
  if (err != MSP_SUCCESS) {
    return false;
  }

  logged_in_ = true;
  return true;
}

bool TingpalVoicePlusPlugin::EnsureRecognizerReady() {
  if (recognizer_ready_) {
    return true;
  }

  notifier_.on_result = &TingpalVoicePlusPlugin::OnSdkResult;
  notifier_.on_speech_begin = &TingpalVoicePlusPlugin::OnSdkSpeechBegin;
  notifier_.on_speech_end = &TingpalVoicePlusPlugin::OnSdkSpeechEnd;

  const std::string params = BuildSessionParams();
  const int init_ret =
      sr_init(&recognizer_, params.c_str(), SR_MIC, DEFAULT_INPUT_DEVID, &notifier_);
  if (init_ret != 0) {
    return false;
  }

  recognizer_ready_ = true;
  return true;
}

void TingpalVoicePlusPlugin::ResetRecognizer() {
  if (!recognizer_ready_) {
    return;
  }

  sr_stop_listening(&recognizer_);
  sr_uninit(&recognizer_);
  std::memset(&recognizer_, 0, sizeof(recognizer_));
  recognizer_ready_ = false;
  is_listening_ = false;
  emit_completed_on_stop_ = false;
}

void TingpalVoicePlusPlugin::LogoutSdk() {
  if (!logged_in_) {
    return;
  }
  MSPLogout();
  logged_in_ = false;
}

std::string TingpalVoicePlusPlugin::BuildSessionParams() const {
  std::map<std::string, std::string> params = {
      {"sub", "iat"},
      {"domain", "iat"},
      {"language", "zh_cn"},
      {"accent", "mandarin"},
      {"sample_rate", "16000"},
      {"result_type", "plain"},
      {"result_encoding", "utf8"},
  };

  for (const auto &entry : voice_options_) {
    params[entry.first] = EncodableValueToString(entry.second);
  }

  std::ostringstream out;
  bool first = true;
  for (const auto &entry : params) {
    if (!first) {
      out << ", ";
    }
    out << entry.first << " = " << entry.second;
    first = false;
  }
  return out.str();
}

std::string TingpalVoicePlusPlugin::EncodableValueToString(
    const flutter::EncodableValue &value) const {
  if (std::holds_alternative<std::string>(value)) {
    return std::get<std::string>(value);
  }
  if (std::holds_alternative<bool>(value)) {
    return std::get<bool>(value) ? "true" : "false";
  }
  if (std::holds_alternative<int32_t>(value)) {
    return std::to_string(std::get<int32_t>(value));
  }
  if (std::holds_alternative<int64_t>(value)) {
    return std::to_string(std::get<int64_t>(value));
  }
  if (std::holds_alternative<double>(value)) {
    std::ostringstream out;
    out << std::get<double>(value);
    return out.str();
  }
  return "";
}

flutter::EncodableMap TingpalVoicePlusPlugin::BuildErrorPayload(
    int code, const std::string &desc) const {
  return flutter::EncodableMap{{flutter::EncodableValue("code"),
                                flutter::EncodableValue(code)},
                               {flutter::EncodableValue("desc"),
                                flutter::EncodableValue(desc)}};
}

void TingpalVoicePlusPlugin::EmitEvent(const std::string &event_name,
                                       flutter::EncodableMap payload) {
  if (event_sink_ == nullptr) {
    return;
  }
  payload[flutter::EncodableValue("event")] =
      flutter::EncodableValue(event_name);
  event_sink_->Success(flutter::EncodableValue(payload));
}

void TingpalVoicePlusPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare(kMethodInit) == 0) {
    if (method_call.arguments() != nullptr &&
        std::holds_alternative<flutter::EncodableMap>(*method_call.arguments())) {
      const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (args != nullptr) {
        auto app_id_it = args->find(flutter::EncodableValue("appIdWindows"));
        if (app_id_it != args->end() &&
            std::holds_alternative<std::string>(app_id_it->second)) {
          app_id_windows_ = std::get<std::string>(app_id_it->second);
        }
      }
    }

    if (!EnsureLoggedIn()) {
      result->Error("INIT_FAILED", "MSPLogin failed or appIdWindows is empty");
      return;
    }

    if (!EnsureRecognizerReady()) {
      result->Error("INIT_FAILED", "Recognizer init failed");
      return;
    }

    g_active_plugin = this;
    result->Success();
  } else if (method_call.method_name().compare(kMethodSetOptions) == 0) {
    voice_options_.clear();
    if (method_call.arguments() != nullptr &&
        std::holds_alternative<flutter::EncodableMap>(*method_call.arguments())) {
      const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (args != nullptr) {
        for (const auto &entry : *args) {
          if (std::holds_alternative<std::string>(entry.first)) {
            voice_options_[std::get<std::string>(entry.first)] = entry.second;
          }
        }
      }
    }

    auto audio_it = voice_options_.find("asr_audio_path");
    if (audio_it != voice_options_.end() &&
        std::holds_alternative<std::string>(audio_it->second)) {
      audio_file_path_ = std::get<std::string>(audio_it->second);
    } else {
      audio_file_path_.clear();
    }

    if (recognizer_ready_) {
      sr_stop_listening(&recognizer_);
      sr_uninit(&recognizer_);
      std::memset(&recognizer_, 0, sizeof(recognizer_));
      recognizer_ready_ = false;
      is_listening_ = false;
    }

    if (!EnsureRecognizerReady()) {
      result->Error("SET_OPTIONS_FAILED", "Failed to apply recognizer options");
      return;
    }

    result->Success();
  } else if (method_call.method_name().compare(kMethodStartListening) == 0) {
    if (!EnsureLoggedIn() || !EnsureRecognizerReady()) {
      result->Error("NOT_INITIALIZED", "Call init first");
      return;
    }

    if (is_listening_) {
      result->Success();
      return;
    }

    const int start_ret = sr_start_listening(&recognizer_);
    if (start_ret != 0) {
      result->Error("START_FAILED", "startListening failed", flutter::EncodableValue(start_ret));
      return;
    }

    is_listening_ = true;
    emit_completed_on_stop_ = true;
    result->Success();
  } else if (method_call.method_name().compare(kMethodStopListening) == 0) {
    if (!recognizer_ready_ || !is_listening_) {
      result->Success();
      return;
    }

    const int stop_ret = sr_stop_listening(&recognizer_);
    is_listening_ = false;
    EmitEvent(kEventEndOfSpeech, flutter::EncodableMap{});
    if (emit_completed_on_stop_) {
      EmitEvent(kEventCompleted,
                flutter::EncodableMap{{flutter::EncodableValue("error"),
                                       flutter::EncodableMap{}},
                                      {flutter::EncodableValue("audioFilePath"),
                                       flutter::EncodableValue(audio_file_path_)}});
    }
    emit_completed_on_stop_ = false;

    if (stop_ret != 0) {
      result->Error("STOP_FAILED", "stopListening failed", flutter::EncodableValue(stop_ret));
      return;
    }

    result->Success();
  } else if (method_call.method_name().compare(kMethodCancelListening) == 0) {
    if (recognizer_ready_ && is_listening_) {
      sr_stop_listening(&recognizer_);
      is_listening_ = false;
    }
    emit_completed_on_stop_ = false;
    EmitEvent(kEventCancel, flutter::EncodableMap{});
    result->Success();
  } else if (method_call.method_name().compare(kMethodDisposeClient) == 0) {
    ResetRecognizer();
    LogoutSdk();
    if (g_active_plugin == this) {
      g_active_plugin = nullptr;
    }
    app_id_windows_.clear();
    voice_options_.clear();
    audio_file_path_.clear();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace tingpal_voice_plus
