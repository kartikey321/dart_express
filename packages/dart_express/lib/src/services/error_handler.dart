import 'dart:io';

import '../../dart_express.dart';

typedef ErrorHandler = Future<void> Function(
    dynamic error, Request request, Response response);

class HttpError implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;

  HttpError(this.statusCode, this.message, [this.data]);

  @override
  String toString() => 'HttpError: $statusCode - $message';
}

class ValidationError extends HttpError {
  ValidationError(String message, [dynamic data])
      : super(HttpStatus.badRequest, message, data);
}

class NotFoundError extends HttpError {
  NotFoundError(String message, [dynamic data])
      : super(HttpStatus.notFound, message, data);
}

class UnauthorizedError extends HttpError {
  UnauthorizedError(String message, [dynamic data])
      : super(HttpStatus.unauthorized, message, data);
}
class RouteConflictError extends HttpError {
  RouteConflictError(String message, [dynamic data])
      : super(HttpStatus.conflict, message, data);
}