#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint kaldi_gop_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'kaldi_gop_plugin'
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
  # Le chemin vers les sources Kaldi/GOP dépendra de l'intégration choisie
  s.source_files = 'Classes/**/*', '../cpp/**/*.cpp' # Ajouter '../native/kaldi_gop_app/src/**/*.cpp', '../native/kaldi/src/.../*.cc' etc.
  # Inclure les en-têtes C++
  s.public_header_files = '../cpp/**/*.h' # Ajouter '../native/kaldi_gop_app/include/**/*.h', '../native/kaldi/src/.../*.h' etc.
  # Préserver les chemins pour les includes Kaldi
  s.preserve_paths = '../native/kaldi/**/*', '../native/kaldi_gop_app/**/*' # Adapter si nécessaire

  # Spécifier que le pod contient du C++
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11', # Ou c++14/17 selon les besoins de Kaldi
    'CLANG_ENABLE_MODULES' => 'YES',
    # Exclure i386 pour le simulateur
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # Chemins d'inclusion pour les en-têtes Kaldi (exemple)
    # 'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../native/kaldi/src" "$(PODS_TARGET_SRCROOT)/../native/kaldi/tools/openfst/include" ...'
  }
  # Ajouter les frameworks nécessaires (Accelerate pour BLAS/LAPACK souvent utilisé par Kaldi)
  s.frameworks = 'Accelerate', 'AudioToolbox'

  # Dépendances Kaldi (très complexe, souvent géré par script externe)
  # s.libraries = 'kaldi-base', 'kaldi-util', ... # Lier les bibliothèques Kaldi compilées
  # s.vendored_libraries = 'path/to/compiled/kaldi/libs/*.a' # Si pré-compilées
  # s.prepare_command = <<-CMD
  #    # Script pour compiler Kaldi pour iOS (peut être très long)
  #    # cd ../native/kaldi/tools && make openfst && cd ../src && ./configure --static --ios && make depend && make -j $(sysctl -n hw.ncpu)
  # CMD

  s.dependency 'Flutter'
  s.platform = :ios, '13.0' # Kaldi peut nécessiter une version iOS plus récente

  # Flutter.framework does not contain a i386 slice. (Déjà géré)
  # s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' } # Redondant
  s.swift_version = '5.0'
  s.compiler_flags = '-ObjC++' # Nécessaire pour le pont ObjC++
  s.libraries = 'c++' # Lier à la bibliothèque standard C++

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'kaldi_gop_plugin_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
