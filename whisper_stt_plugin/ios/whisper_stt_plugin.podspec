#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint whisper_stt_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'whisper_stt_plugin'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  # Inclure les classes Swift/ObjC ET les sources C++
  s.source_files = 'Classes/**/*', '../cpp/**/*.cpp', '../native/whisper.cpp/*.cpp', '../native/whisper.cpp/ggml*.c'
  # Inclure les en-têtes C++
  s.public_header_files = '../cpp/**/*.h', '../native/whisper.cpp/*.h'
  # Spécifier que le pod contient du C++
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11', # Standard C++ requis par whisper.cpp
    'CLANG_ENABLE_MODULES' => 'YES',
    # Exclure i386 pour le simulateur
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  # Ajouter les frameworks nécessaires (AudioToolbox est souvent requis, Accelerate pour les optimisations BLAS)
  s.frameworks = 'AudioToolbox', 'Accelerate'

  s.dependency 'Flutter'
  s.platform = :ios, '13.0' # Augmenter si nécessaire pour les dépendances ou whisper.cpp

  # Flutter.framework does not contain a i386 slice. (Déjà géré dans pod_target_xcconfig)
  # s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' } # Ligne redondante
  s.swift_version = '5.0'
  # Assurer la compatibilité avec Objective-C++ si nécessaire
  s.compiler_flags = '-ObjC++'
  s.libraries = 'c++' # Lier à la bibliothèque standard C++

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'whisper_stt_plugin_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
