/// App-wide configuration.
///
/// CHANGE THIS ONE LINE to point the app at your backend.
///
///   Physical phone on same Wi-Fi ... http://192.168.1.5:3000
///   Android emulator ............... http://10.0.2.2:3000
///   Flutter web / desktop .......... http://localhost:3000
///
/// If the phone cannot connect, check:
///   1. `npm run dev` is running on the PC
///   2. The PC's IP is still 192.168.1.5 (run `ipconfig`)
///   3. Windows Firewall allows inbound TCP on port 3000
///   4. Phone and PC are on the same Wi-Fi network
class Config {
  static const String baseUrl = 'http://192.168.1.5:3000';
}
