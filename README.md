# Fletch Monorepo

> Express-inspired HTTP framework for Dart

This is a Melos-managed monorepo containing the Fletch framework and related packages.

## Packages

### 🚀 [Fletch](./packages/fletch)

Express-inspired HTTP framework for Dart with SSE, streaming, and production-ready features.

- **Version:** 2.0.2
- **Pub.dev:** https://pub.dev/packages/fletch
- **Documentation:** https://docs.fletch.mahawarkartikey.in/

**Features:**
- Express-like API (`app.get()`, `app.post()`, middleware)
- Server-Sent Events (SSE) for real-time streaming
- Generic streaming support
- Full HTTP method support (GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS)
- HMAC-signed sessions, CORS, rate limiting
- Dependency injection with GetIt
- Controllers and isolated containers

## Quick Start

```bash
# Install Melos
dart pub global activate melos

# Bootstrap the monorepo
melos bootstrap

# Run tests
melos run test
```

## Development

### Project Structure

```
dart_express/
├── packages/
│   └── fletch/          # Main framework package
├── apps/
│   └── fletch_examples/ # Example applications
├── docs/                # Documentation site
└── melos.yaml           # Monorepo configuration
```

### Common Commands

```bash
# Get dependencies for all packages
melos run get

# Run all tests
melos run test

# Analyze all packages
melos run analyze

# Format code
dart format .

# Publish fletch package
cd packages/fletch && ./tool/publish.sh
```

### Working on Fletch

```bash
# Navigate to the package
cd packages/fletch

# Run tests
dart test

# Run specific test file
dart test test/sse_stream_integration_test.dart

# Analyze
dart analyze

# Dry-run publish
dart pub publish --dry-run
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Run `dart format .` and `dart analyze`
4. Add tests for new features
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

MIT License - see [LICENSE](./LICENSE)

## Links

- **Documentation:** https://docs.fletch.mahawarkartikey.in/
- **Pub.dev:** https://pub.dev/packages/fletch
- **Issues:** https://github.com/kartikey321/fletch/issues
- **Discussions:** https://github.com/kartikey321/fletch/discussions
