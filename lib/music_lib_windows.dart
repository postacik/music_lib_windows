// ignore_for_file: constant_identifier_names
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:isolate';
import 'dart:ffi';

final DynamicLibrary _nativeLib =
    DynamicLibrary.open('music_lib_windows_plugin.dll');

final _nRegisterPostCObject = _nativeLib.lookupFunction<
    Void Function(
        Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>>
            functionPointer),
    void Function(
        Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>>
            functionPointer)>('RegisterDart_PostCObject');

final _getMidiDeviceIndexes = _nativeLib
    .lookupFunction<Int32 Function(), int Function()>('getMidiDeviceIndexes');

final _getMidiInDeviceCapabilities = _nativeLib.lookupFunction<
    MIDIINCAPS Function(Int32 i),
    MIDIINCAPS Function(int i)>('getMidiInDeviceCapabilities');

final _nOpenMidiInput = _nativeLib.lookupFunction<
    Int32 Function(Int32 port, Int64 callbackPort),
    int Function(int port, int callbackPort)>('openMidiInput');

final _startMidiInput = _nativeLib
    .lookupFunction<Int32 Function(), int Function()>('startMidiInput');

final _stopMidiInput = _nativeLib
    .lookupFunction<Int32 Function(), int Function()>('stopMidiInput');

final _closeMidiInput = _nativeLib
    .lookupFunction<Int32 Function(), int Function()>('closeMidiInput');

class MusicLibWindows {
  //Put method channel functions in here
  static const MethodChannel _channel = MethodChannel('music_lib_windows');

  static Future<String?> get sayHello async {
    final String? version = await _channel.invokeMethod('sayHello');
    return version;
  }
  //Put method channel functions in here

  ReceivePort receivePort = ReceivePort('Win32MidiReceivePort');
  StreamSubscription<dynamic>? portSubscription;

  MusicLibWindows() {
    _nRegisterPostCObject(NativeApi.postCObject);
  }

  int getMidiDeviceIndexes() {
    return _getMidiDeviceIndexes();
  }

  MIDIINCAPS getMidiInDeviceCapabilities(int deviceIndex) {
    return _getMidiInDeviceCapabilities(deviceIndex);
  }

  int openMidiInput(
      int midiPort, void Function(int midiPort, MidiMessage message) callback) {
    portSubscription = receivePort.listen((message) {
      var port = midiPort;
      var messageList = message as List<dynamic>;
      var castList = messageList.cast<int>();
      callback(port, MidiMessage.fromNativeMessage(castList));
    });
    return _nOpenMidiInput(midiPort, receivePort.sendPort.nativePort);
  }

  int startMidiInput() {
    return _startMidiInput();
  }

  int stopMidiInput() {
    return _stopMidiInput();
  }

  int closeMidiInput() {
    portSubscription?.cancel();
    receivePort.close();
    return _closeMidiInput();
  }
}

enum MidiMessageType { OPEN, CLOSE, DATA, ERROR, UNKNOWN }

enum MidiStatusFlag {
  NoteOff,
  NoteOn,
  PolyAftertouch,
  CC,
  PC,
  MonoAftertouch,
  PitchBend,
  System
}

class MidiData {
  final MidiStatusFlag status;
  final int channel;
  final int? note;
  final int? value;
  final int? controller;
  final int? program;

  MidiData(this.status, this.channel,
      {this.note, this.value, this.controller, this.program});

  factory MidiData.fromFourByteInt(int fourByteInt) {
    final statusByte = getByteFromPosition(fourByteInt, 0);
    final statusInt = statusByte >> 4;
    final channel = statusByte & 0x0F;
    final firstByte = getByteFromPosition(fourByteInt, 1);
    final secondByte = getByteFromPosition(fourByteInt, 2);
    MidiStatusFlag status;
    int? note;
    int? value;
    int? controller;
    int? program;
    switch (statusInt) {
      case 0x8:
        {
          status = MidiStatusFlag.NoteOff;
          note = firstByte;
          value = secondByte;
          break;
        }
      case 0x9:
        {
          status = MidiStatusFlag.NoteOn;
          note = firstByte;
          value = secondByte;
          break;
        }
      case 0xA:
        {
          status = MidiStatusFlag.PolyAftertouch;
          note = firstByte;
          value = secondByte;
          break;
        }
      case 0xB:
        {
          status = MidiStatusFlag.CC;
          controller = firstByte;
          value = secondByte;
          break;
        }
      case 0xC:
        {
          status = MidiStatusFlag.PC;
          program = firstByte;
          break;
        }
      case 0xD:
        {
          status = MidiStatusFlag.MonoAftertouch;
          value = firstByte;
          break;
        }
      case 0xE:
        {
          status = MidiStatusFlag.PitchBend;
          value = (secondByte * 128) + firstByte;
          break;
        }
      default:
        {
          status = MidiStatusFlag.System;
        }
    }
    return MidiData(status, channel,
        note: note, value: value, controller: controller, program: program);
  }

  @override
  String toString() {
    return 'MidiData: status: $status, channel: $channel, note: $note, value: $value controller: $controller, program: $program';
  }
}

class MidiMessage {
  final MidiMessageType type;
  final int instance;
  final int timestamp;
  final MidiData? data;

  MidiMessage(this.type, this.instance, this.timestamp, {this.data});

  factory MidiMessage.fromNativeMessage(List<int> message) {
    return MidiMessage(
      messageEnumMap.containsKey(message[0])
          ? messageEnumMap[message[0]]!
          : MidiMessageType.UNKNOWN,
      message[1],
      message[3],
      data: MidiData.fromFourByteInt(message[2]),
    );
  }

  @override
  String toString() {
    return 'MidiMessage: type: $type, instance: $instance, time: $timestamp, data: {$data}';
  }
}

/// MIDI time.
const TIME_MIDI = 0x0010;

/// Ticks within a MIDI stream.
const TIME_TICKS = 0x0020;

/// The dwCallback parameter is a callback procedure address.
const CALLBACK_FUNCTION = 0x00030000;

/// The MM_MIM_OPEN message is sent to a window when a MIDI input device is
/// opened.
const MM_MIM_OPEN = 0x3C1;

/// The MM_MIM_CLOSE message is sent to a window when a MIDI input device is
/// closed.
const MM_MIM_CLOSE = 0x3C2;

/// The MM_MIM_DATA message is sent to a window when a complete MIDI message is
/// received by a MIDI input device.
const MM_MIM_DATA = 0x3C3;

/// The MM_MIM_LONGDATA message is sent to a window when either a complete MIDI
/// system-exclusive message is received or when a buffer has been filled with
/// system-exclusive data.
const MM_MIM_LONGDATA = 0x3C4;

/// The MM_MIM_ERROR message is sent to a window when an invalid MIDI message is
/// received.
const MM_MIM_ERROR = 0x3C5;

/// The MM_MIM_LONGERROR message is sent to a window when an invalid or
/// incomplete MIDI system-exclusive message is received.
const MM_MIM_LONGERROR = 0x3C6;

/// The MM_MOM_OPEN message is sent to a window when a MIDI output device is
/// opened.
const MM_MOM_OPEN = 0x3C7;

/// The MM_MOM_CLOSE message is sent to a window when a MIDI output device is
/// closed.
const MM_MOM_CLOSE = 0x3C8;

/// The MM_MOM_DONE message is sent to a window when the specified MIDI
/// system-exclusive or stream buffer has been played and is being returned to
/// the application.
const MM_MOM_DONE = 0x3C9;

/// The MM_MOM_POSITIONCB message is sent to a window when an MEVT_F_CALLBACK
/// event is reached in the MIDI output stream.
const MM_MOM_POSITIONCB = 0x3CA;

/// The MM_MCISIGNAL message is sent to a window to notify an application that
/// an MCI device has reached a position defined in a previous signal (
/// MCI_SIGNAL) command.
const MM_MCISIGNAL = 0x3CB;

/// The MM_MIM_MOREDATA message is sent to a callback window when a MIDI message
/// is received by a MIDI input device but the application is not processing
/// MIM_DATA messages fast enough to keep up with the input device driver. The
/// window receives this message only when the application specifies
/// MIDI_IO_STATUS in the call to the midiInOpen function.
const MM_MIM_MOREDATA = 0x3CC;

/// The MM_MIXM_LINE_CHANGE message is sent by a mixer device to notify an
/// application that the state of an audio line on the specified device has
/// changed. The application should refresh its display and cached values for
/// the specified audio line.
const MM_MIXM_LINE_CHANGE = 0x3D0;

/// The MM_MIXM_CONTROL_CHANGE message is sent by a mixer device to notify an
/// application that the state of a control associated with an audio line has
/// changed. The application should refresh its display and cached values for
/// the specified control.
const MM_MIXM_CONTROL_CHANGE = 0x3D1;

/// The MIM_OPEN message is sent to a MIDI input callback function when a MIDI
/// input device is opened.
const MIM_OPEN = MM_MIM_OPEN;

/// The MIM_CLOSE message is sent to a MIDI input callback function when a MIDI
/// input device is closed.
const MIM_CLOSE = MM_MIM_CLOSE;

/// The MIM_DATA message is sent to a MIDI input callback function when a MIDI
/// message is received by a MIDI input device.
const MIM_DATA = MM_MIM_DATA;

/// The MIM_LONGDATA message is sent to a MIDI input callback function when a
/// system-exclusive buffer has been filled with data and is being returned to
/// the application.
const MIM_LONGDATA = MM_MIM_LONGDATA;

/// The MIM_ERROR message is sent to a MIDI input callback function when an
/// invalid MIDI message is received.
const MIM_ERROR = MM_MIM_ERROR;

/// The MIM_LONGERROR message is sent to a MIDI input callback function when an
/// invalid or incomplete MIDI system-exclusive message is received.
const MIM_LONGERROR = MM_MIM_LONGERROR;

/// The MOM_OPEN message is sent to a MIDI output callback function when a MIDI
/// output device is opened.
const MOM_OPEN = MM_MOM_OPEN;

/// The MOM_CLOSE message is sent to a MIDI output callback function when a MIDI
/// output device is closed.
const MOM_CLOSE = MM_MOM_CLOSE;

/// The MOM_DONE message is sent to a MIDI output callback function when the
/// specified system-exclusive or stream buffer has been played and is being
/// returned to the application.
const MOM_DONE = MM_MOM_DONE;

/// The MIM_MOREDATA message is sent to a MIDI input callback function when a
/// MIDI message is received by a MIDI input device but the application is not
/// processing MIM_DATA messages fast enough to keep up with the input device
/// driver. The callback function receives this message only when the
/// application specifies MIDI_IO_STATUS in the call to the midiInOpen function.
const MIM_MOREDATA = MM_MIM_MOREDATA;

final Map<int, MidiMessageType> messageEnumMap = {
  MIM_OPEN: MidiMessageType.OPEN,
  MIM_CLOSE: MidiMessageType.CLOSE,
  MIM_DATA: MidiMessageType.DATA,
  MIM_ERROR: MidiMessageType.ERROR,
};

/// The MIDIINCAPS structure describes the capabilities of a MIDI input
/// device.
///
/// {@category Struct}
@Packed(1)
class MIDIINCAPS extends Struct {
  @Uint16()
  external int wMid;
  @Uint16()
  external int wPid;
  @Uint32()
  external int vDriverVersion;
  @Array(32)
  external Array<Uint16> _szPname;

  String get szPname {
    final charCodes = <int>[];
    for (var i = 0; i < 32; i++) {
      charCodes.add(_szPname[i]);
      if (_szPname[i] == 0) break;
    }
    return String.fromCharCodes(charCodes);
  }

  set szPname(String value) {
    final stringToStore = value.padRight(32, '\x00');
    for (var i = 0; i < 32; i++) {
      _szPname[i] = stringToStore.codeUnitAt(i);
    }
  }

  @Uint32()
  external int dwSupport;
}

int getByteFromPosition(int fourByteNumber, int pos) {
  int mask = 0xff << (pos * 8);
  int result = fourByteNumber & mask;
  return result >> (pos * 8);
}
