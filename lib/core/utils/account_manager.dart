import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAccount {
  final String email;
  final String password;
  final String displayName;

  SavedAccount({
    required this.email,
    required this.password,
    required this.displayName,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'displayName': displayName,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        email: json['email'] ?? '',
        password: json['password'] ?? '',
        displayName: json['displayName'] ?? '',
      );
}

class AccountManager {
  static const _key = 'saved_accounts';

  static Future<List<SavedAccount>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) => SavedAccount.fromJson(jsonDecode(e)))
        .toList();
  }

  static Future<void> saveAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getSavedAccounts();

    // Remove existing account with same email
    accounts.removeWhere((a) => a.email == email);

    // Add to top
    accounts.insert(
      0,
      SavedAccount(email: email, password: password, displayName: displayName),
    );

    final raw = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }

  static Future<void> removeAccount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getSavedAccounts();
    accounts.removeWhere((a) => a.email == email);
    final raw = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
