class AuthService {
  static List<Map<String, String>> mockUserDb = [];

  static bool signUp(String name, String email, String password) {
    if (mockUserDb.any((user) => user['email'] == email)) return false;
    
    mockUserDb.add({
      'name': name,
      'email': email,
      'password': password,
    });
    return true;
  }

  static bool login(String email, String password) {
    return mockUserDb.any((user) => 
      user['email'] == email && user['password'] == password);
  }
}