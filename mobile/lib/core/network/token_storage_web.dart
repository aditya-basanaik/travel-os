import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  const TokenStorage();

  Future<String?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  Future<void> write(String key, String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, value);
  }

  Future<void> delete(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}
