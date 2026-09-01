import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    print('❌ Error: Please provide a new app name.');
    print('Usage: dart run change_name.dart "Your New App Name"');
    return;
  }

  final newName = args.first;
  print('🔄 Changing app name to: "$newName"...');

  // 1. Update AndroidManifest.xml
  final androidManifest = File('android/app/src/main/AndroidManifest.xml');
  if (androidManifest.existsSync()) {
    String content = androidManifest.readAsStringSync();
    
    // Replaces the android:label value
    content = content.replaceAll(
      RegExp(r'android:label="[^"]*"'), 
      'android:label="$newName"'
    );
    
    androidManifest.writeAsStringSync(content);
    print('✅ Updated AndroidManifest.xml');
  } else {
    print('⚠️ AndroidManifest.xml not found.');
  }

  // 2. Update iOS Info.plist
  final iosPlist = File('ios/Runner/Info.plist');
  if (iosPlist.existsSync()) {
    String content = iosPlist.readAsStringSync();
    
    // Replaces CFBundleDisplayName
    content = content.replaceAll(
      RegExp(r'<key>CFBundleDisplayName</key>\s*<string>[^<]*</string>'), 
      '<key>CFBundleDisplayName</key>\n\t<string>$newName</string>'
    );
    
    // CFBundleName strictly shouldn't have spaces (used internally)
    final internalBundleName = newName.replaceAll(' ', '');
    content = content.replaceAll(
      RegExp(r'<key>CFBundleName</key>\s*<string>[^<]*</string>'), 
      '<key>CFBundleName</key>\n\t<string>$internalBundleName</string>'
    );

    iosPlist.writeAsStringSync(content);
    print('✅ Updated iOS Info.plist');
  } else {
    print('⚠️ iOS Info.plist not found.');
  }

  print('\n🎉 App name updated successfully!');
  print('👉 Reminder: Stop the app and run "flutter clean" before rebuilding.');
}