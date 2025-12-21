import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:fletch/fletch.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../models/user.dart';

class AuthService {
  final Db _db;
  final String _jwtSecret;

  AuthService(this._db, this._jwtSecret);

  Future<User> register(String name, String email, String password) async {
    final users = _db.collection('users');

    // Check for existing user
    if (await users.findOne({'email': email}) != null) {
      throw DuplicateEmailError();
    }

    // Hash password
    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

    // Create new user
    final user = User(
      id: ObjectId().oid,
      name: name,
      email: email,
      passwordHash: hashedPassword,
    );

    await users.insert(user.toJson());
    return user;
  }

  Future<String> login(String email, String password) async {
    final users = _db.collection('users');
    final userJson = await users.findOne({'email': email});

    if (userJson == null) throw InvalidCredentialsError();

    final user = User.fromJson(userJson);

    if (!BCrypt.checkpw(password, user.passwordHash)) {
      throw InvalidCredentialsError();
    }

    return _generateToken(user);
  }

  String _generateToken(User user) {
    final jwt = JWT(
      {
        'id': user.id,
        'name': user.name,
        'email': user.email,
      },
      issuer: 'dart_express',
    );

    return jwt.sign(SecretKey(_jwtSecret), expiresIn: Duration(hours: 24));
  }

  static final bearerTokenRegExp = RegExp(r'Bearer (?<token>.+)');

  static MiddlewareHandler verifyToken(String secret) {
    return (req, res, next) async {
      final authHeader =
          req.headers.value(HttpHeaders.authorizationHeader) ?? '';
      final match = bearerTokenRegExp.firstMatch(authHeader);
      final token = match?.namedGroup('token');
      if (token == null) {
        return res.json({'error': 'No token provided'}, statusCode: 401);
      }

      try {
        final jwt = JWT.verify(token, SecretKey(secret));
        req.headers.add('userId', jwt.payload['id']);
        await next();
      } on JWTException catch (e) {
        res.json({'error': 'Invalid token', 'details': e.message},
            statusCode: 401);
      }
    };
  }
}

class DuplicateEmailError extends Error {
  final statusCode = 400;
  final message = 'Email already registered';
}

class InvalidCredentialsError extends Error {
  final statusCode = 401;
  final message = 'Invalid email or password';
}
