#ifndef FLUTTER_PLUGIN_MUSIC_LIB_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_MUSIC_LIB_WINDOWS_PLUGIN_H_
#include <Windows.h>
#include <flutter_plugin_registrar.h>
#include "../../CallbackManager.h"
#include <mmeapi.h>


#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void MusicLibWindowsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

FLUTTER_PLUGIN_EXPORT UINT getMidiDeviceIndexes();
FLUTTER_PLUGIN_EXPORT MIDIINCAPS getMidiInDeviceCapabilities(int i);
FLUTTER_PLUGIN_EXPORT MMRESULT openMidiInput(DWORD port, Dart_Port callbackPort);
FLUTTER_PLUGIN_EXPORT MMRESULT startMidiInput(DWORD port);
FLUTTER_PLUGIN_EXPORT MMRESULT stopMidiInput(DWORD port);
FLUTTER_PLUGIN_EXPORT MMRESULT closeMidiInput(DWORD port);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_MUSIC_LIB_WINDOWS_PLUGIN_H_
