import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Instancia del almacenamiento seguro
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  // Guardar el token al iniciar sesión con éxito
  static Future<void> guardarToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Leer el token para enviarlo en las peticiones HTTP
  static Future<String?> obtenerToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Eliminar el token (Cerrar sesión)
  static Future<void> cerrarSesion() async {
    await _storage.delete(key: _tokenKey);
  }
}