# Installation

Get started with dart_express in minutes.

## Requirements

- **Dart SDK**: 3.6.0 or later
- **Platform**: Windows, macOS, Linux

## Install via Pub

Add dart_express to your `pubspec.yaml`:

```yaml
dependencies:
  dart_express: ^1.0.0
```

Then install dependencies:

```bash
dart pub get
```

## Create Your First Server

Create `bin/server.dart`:

```dart
import 'package:dart_express/dart_express.dart';

void main() async {
  final app = DartExpress();
  
  app.get('/', (req, res) {
    res.text('Hello from dart_express!');
  });
  
  await app.listen(3000);
  print('🚀 Server running on http://localhost:3000');
}
```

## Run Your Server

```bash
dart run bin/server.dart
```

Visit [http://localhost:3000](http://localhost:3000) to see your server in action!

## Verify Installation

Test that everything works:

```bash
curl http://localhost:3000
# Output: Hello from dart_express!
```

## Optional Dependencies

### For MongoDB Support
```yaml
dependencies:
  mongo_dart: ^0.9.0
```

### For Testing
```yaml
dev_dependencies:
  test: ^1.24.0
  http: ^1.1.0
```

## Project Structure

A typical dart_express project:

```
my_api/
├── bin/
│   └── server.dart          # Entry point
├── lib/
│   ├── controllers/         # Route controllers
│   ├── models/              # Data models
│   ├── services/            # Business logic
│   └── middleware/          # Custom middleware
├── test/
│   └── server_test.dart
└── pubspec.yaml
```

## Next Steps

- **[Quick Start](/about)** - Build a complete API
- **[Routing](/about)** - Learn about path parameters and routing
- **[Middleware](/about)** - Understand the middleware pipeline

<Info>
**Pro Tip**: Use `dart run --observe` to enable debugging with Dart DevTools!
</Info>
