import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_signal_processor_platform_interface.dart';

/// An implementation of [AudioSignalProcessorPlatform] that uses method channels.
class MethodChannelAudioSignalProcessor extends AudioSignalProcessorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('audio_signal_processor');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
