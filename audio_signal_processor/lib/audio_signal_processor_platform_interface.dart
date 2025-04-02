import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audio_signal_processor_method_channel.dart';

abstract class AudioSignalProcessorPlatform extends PlatformInterface {
  /// Constructs a AudioSignalProcessorPlatform.
  AudioSignalProcessorPlatform() : super(token: _token);

  static final Object _token = Object();

  static AudioSignalProcessorPlatform _instance = MethodChannelAudioSignalProcessor();

  /// The default instance of [AudioSignalProcessorPlatform] to use.
  ///
  /// Defaults to [MethodChannelAudioSignalProcessor].
  static AudioSignalProcessorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AudioSignalProcessorPlatform] when
  /// they register themselves.
  static set instance(AudioSignalProcessorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
