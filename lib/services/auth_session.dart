import 'package:get/get.dart';
import '../models/user.dart'; // your User class

class AuthSession extends GetxService {
  User? _user;

  User? get user => _user;

  int? get userId => _user?.id;
  String? get username => _user?.name;
  String? get email => _user?.email;
  String? get role => _user?.role;
  String? get token => _user?.token;

  // For collectors
  int? get businessUnitId => _user?.businessUnitId;
  int? get sectorId => _user?.sectorId;
  String? get businessUnitName => _user?.businessUnitName;
  String? get sectorName => _user?.sectorName;

  Future<AuthSession> init() async {
    // Optionally load from SharedPreferences here
    return this;
  }

  void setUser(User user) {
    _user = user;
    // Optionally persist to SharedPreferences
  }

  void clear() {
    _user = null;
    // Optionally clear from SharedPreferences
  }

  bool get isLoggedIn => _user != null;
}