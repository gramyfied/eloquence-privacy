#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint piper_tts_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'piper_tts_plugin'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  # Inclure les classes Swift/ObjC ET les sources C++ de piper et de notre pont
  s.source_files = 'Classes/**/*', '../cpp/**/*.cpp', '../native/piper/src/cpp/include/**/*.hpp', '../native/piper/src/cpp/piper/*.cpp', '../native/piper/src/cpp/phonemize/*.cpp' # Adapter les chemins selon la structure de piper
  # Inclure les en-têtes C++
  s.public_header_files = '../cpp/**/*.h', '../native/piper/src/cpp/include/**/*.hpp'
  # Spécifier que le pod contient du C++
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17', # Piper utilise C++17
    'CLANG_ENABLE_MODULES' => 'YES',
    # Exclure i386 pour le simulateur
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  # Ajouter les frameworks nécessaires (AVFoundation pour l'audio)
  s.frameworks = 'AVFoundation', 'Accelerate' # Accelerate peut être utile pour ONNX

  # Dépendance à onnxruntime (à gérer)
  # Option 1: Si onnxruntime est disponible comme Pod
  # s.dependency 'onnxruntime-objc', '~> 1.15.0' # Exemple, vérifier le nom et version exacts
  # Option 2: Si onnxruntime est inclus manuellement (ex: comme .xcframework)
  # s.vendored_frameworks = 'path/to/onnxruntime.xcframework'
  # s.prepare_command = <<-CMD
  #   # Commandes pour télécharger/configurer onnxruntime si nécessaire
  # CMD

  s.dependency 'Flutter'
  s.platform = :ios, '13.0' # Piper/ONNX peuvent nécessiter une version plus récente

  # Flutter.framework does not contain a i386 slice. (Déjà géré)
  # s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' } # Redondant
  s.swift_version = '5.0'
  s.compiler_flags = '-ObjC++' # Nécessaire pour le pont ObjC++
  s.libraries = 'c++' # Lier à la bibliothèque standard C++

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'piper_tts_plugin_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
