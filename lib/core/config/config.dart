class Config {
  // 🔥 Set to TRUE if using a physical phone. Set to FALSE if using an emulator.
  static const bool isTestingOnPhone = true; 

  static const String physicalDeviceIP = '192.168.1.80'; 
  static const String emulatorIP = '10.0.2.2';

  static String get baseUrl {
    if (isTestingOnPhone) {
      return 'http://$physicalDeviceIP:5000';
    } else {
      return 'http://$emulatorIP:5000';
    }
  }
}