#
# PepoConnect fast lane: the Rust engine in ../rust is built by cargokit as a
# static library and force-loaded into the app, so pepo_core can reach its
# symbols through DynamicLibrary.process().
#
Pod::Spec.new do |s|
  s.name             = 'pepo_native'
  s.version          = '0.3.0'
  s.summary          = 'PepoConnect encrypted bulk transfer engine (Rust).'
  s.description      = <<-DESC
Encrypted bulk file transfers over TCP (AES-256-GCM, xxh3) for PepoConnect, written in Rust.
                       DESC
  s.homepage         = 'https://github.com/pepitolas13/PepoConnect'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'PepoTech' => 'danimeyt5@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  s.script_phase = {
    :name => 'Build Rust library',
    :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../rust pepo_native',
    :execution_position => :before_compile,
    :input_files => ['${BUILT_PRODUCTS_DIR}/cargokit_phony'],
    :output_files => ["${BUILT_PRODUCTS_DIR}/libpepo_native.a"],
  }
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load ${BUILT_PRODUCTS_DIR}/libpepo_native.a',
  }
end
