import 'dart:io';

import 'package:dart_express/dart_express.dart';

class CookieParser {
  static MiddlewareHandler middleware({
    bool decodeValues = true,
    bool allowEmptyValues = false,
  }) {
    return (Request req, Response res, NextFunction next) async {
      try {
        req.cookies = _parseCookies(
          req.headers.value(HttpHeaders.cookieHeader),
          decodeValues: decodeValues,
          allowEmptyValues: allowEmptyValues,
        );
        await next();
      } catch (e) {
        await next(); // Could throw error if desired
      }
    };
  }

  static List<Cookie> _parseCookies(
    String? cookieHeader, {
    required bool decodeValues,
    required bool allowEmptyValues,
  }) {
    final cookies = <Cookie>[];
    if (cookieHeader == null || cookieHeader.isEmpty) {
      return cookies;
    }

    final pairs = cookieHeader.split(RegExp(r';\s*'));
    for (final pair in pairs) {
      if (pair.isEmpty) continue;

      final parts = pair.split('=');
      if (parts.isEmpty) continue;

      final name = parts[0].trim();
      if (name.isEmpty) continue;

      String value = parts.length > 1 ? parts.sublist(1).join('=').trim() : '';
      
      if (!allowEmptyValues && value.isEmpty) continue;

      if (decodeValues) {
        try {
          value = Uri.decodeComponent(value);
        } catch (e) {
          continue;
        }
      }

      final cookie = Cookie(name, value);
      cookies.add(cookie);
    }

    return cookies;
  }
}