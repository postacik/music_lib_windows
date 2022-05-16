#include "include/music_lib_windows/music_lib_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <sstream>

#include <thread>
#include "CallbackManager.h"

#include <stdio.h>

#include <mmsystem.h>
#pragma comment(lib, "winmm.lib")

namespace
{

class MusicLibWindowsPlugin : public flutter::Plugin
{
public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

    MusicLibWindowsPlugin();

    virtual ~MusicLibWindowsPlugin();

private:
    // Called when a method is called on this plugin's channel from Dart.
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

// static
void MusicLibWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar)
{
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "music_lib_windows",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<MusicLibWindowsPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result) {
            plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
}

MusicLibWindowsPlugin::MusicLibWindowsPlugin() {}

MusicLibWindowsPlugin::~MusicLibWindowsPlugin() {}

void MusicLibWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
{
    if (method_call.method_name().compare("sayHello") == 0)
    {
        result->Success(flutter::EncodableValue("hello"));
    }
    else
    {
        result->NotImplemented();
    }
}

} // namespace

void MusicLibWindowsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
    MusicLibWindowsPlugin::RegisterWithRegistrar(
        flutter::PluginRegistrarManager::GetInstance()
            ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

//Midi functions buried into plugin dll

UINT getMidiDeviceIndexes()
{
    return midiInGetNumDevs();
}

MIDIINCAPS getMidiInDeviceCapabilities(int i)
{
    MIDIINCAPS caps;
    midiInGetDevCaps(i, &caps, sizeof(MIDIINCAPS));
    return caps;
}

std::map<DWORD, HMIDIIN> midiInHandles{};
std::map<HMIDIIN, DWORD> midiInPorts{};
std::map<DWORD, Dart_Port> callbackPorts{};

void CALLBACK MidiInProc(HMIDIIN hMidiIn, UINT wMsg, DWORD dwInstance, DWORD dwParam1, DWORD dwParam2)
{
    DWORD port = midiInPorts[hMidiIn];
    unsigned long values[5];
    values[0] = port;
    values[1] = wMsg;
    values[2] = dwInstance;
    values[3] = dwParam1;
    values[4] = dwParam2;

    callbackToDartInt32Array(callbackPorts[port], 5, values);
    return;
}

MMRESULT openMidiInput(DWORD port, Dart_Port callbackPort)
{
    HMIDIIN hMidiDevice{NULL};
    MMRESULT result = midiInOpen(&hMidiDevice, port, (DWORD_PTR)(void *)MidiInProc, 0, CALLBACK_FUNCTION);
    midiInHandles[port] = hMidiDevice;
    midiInPorts[hMidiDevice] = port;
    callbackPorts[port] = callbackPort;
    return result;
}

MMRESULT startMidiInput(DWORD port)
{
    return midiInStart(midiInHandles[port]);
}

MMRESULT stopMidiInput(DWORD port)
{
    return midiInStop(midiInHandles[port]);
}

MMRESULT closeMidiInput(DWORD port)
{
    MMRESULT result = midiInClose(midiInHandles[port]);
    HMIDIIN handle = midiInHandles[port];
    midiInHandles.erase(port);
    midiInPorts.erase(handle);
    callbackPorts.erase(port);
    return result;
}