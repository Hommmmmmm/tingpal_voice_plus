#include "include/tingpal_voice_plus/tingpal_voice_plus_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "tingpal_voice_plus_plugin.h"

void TingpalVoicePlusPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  tingpal_voice_plus::TingpalVoicePlusPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
