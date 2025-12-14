# Dart Express Benchmarks

Performance benchmarking tools for the dart_express framework.

## Quick Start

```bash
# Terminal 1: Start test server
dart run bin/test_server.dart

# Terminal 2: Run load test
dart run bin/load_test.dart http://localhost:3000 1000 10
```

## Tools

### 1. Framework Benchmarks (`run_benchmarks.dart`)

Micro-benchmarks testing specific framework features:

- **Routing**: Route matching performance with varying numbers of routes
- **Middleware**: Overhead of middleware pipeline execution
- **Sessions**: Session read/write performance
- **JSON**: Request/response JSON parsing and serialization

**Usage:**
```bash
cd benchmark
dart pub get
dart run bin/run_benchmarks.dart
```

**Sample Output:**
```
🔀 Routing Performance:
Routing-10routes(RunTime): 125.5 us.
Routing-50routes(RunTime): 134.2 us.
Routing-100routes(RunTime): 142.8 us.

⚙️  Middleware Performance:
Middleware-1layers(RunTime): 89.3 us.
Middleware-5layers(RunTime): 156.7 us.
Middleware-10layers(RunTime): 245.1 us.
```

### 2. Load Testing Tool (`load_test.dart`)

HTTP load testing tool with detailed metrics:

**Usage:**
```bash
# Start your server first
dart run bin/server.dart

# In another terminal, run load test
cd benchmark
dart run bin/load_test.dart <url> [total_requests] [concurrent]

# Examples:
dart run bin/load_test.dart http://localhost:3000 1000 10
dart run bin/load_test.dart http://localhost:3000/api/users 5000 50
```

**Metrics Reported:**
- Total requests & success rate
- Requests per second (throughput)
- Response times: avg, min, max
- Percentiles: P50, P95, P99

**Sample Output:**
```
📊 Load Test Results
============================================================

📈 Summary:
   Total Requests: 1000
   Successful: 998
   Failed: 2
   Success Rate: 99.80%
   Duration: 2453ms
   Requests/sec: 407.68

⏱️  Response Times (ms):
   Average: 24
   Min: 12
   Max: 156
   P50 (median): 23
   P95: 45
   P99: 78
```

## Interpreting Results

### Routing Benchmarks
- **<200 μs**: Excellent
- **200-500 μs**: Good
- **>500 μs**: Consider route optimization

### Middleware Benchmarks
- **<100 μs per layer**: Excellent
- **100-200 μs per layer**: Acceptable
- **>200 μs per layer**: Review middleware logic

### Load Testing
- **Requests/sec**: Higher is better (compare with other frameworks)
- **P95/P99**: Should be <2x the average for consistent performance
- **Success Rate**: Should be >99% under normal load

## Tips

1. **Warm-up**: Run benchmarks multiple times; first run may be slower
2. **System Load**: Close other applications for accurate results
3. **Production Mode**: Use `dart compile exe` for production benchmarks
4. **Baseline**: Benchmark before/after changes to measure impact

## Comparing with Other Frameworks

To benchmark against Express.js, Fastify, etc.:

```bash
# Install wrk or Apache Bench
brew install wrk

# Benchmark dart_express
wrk -t4 -c100 -d30s http://localhost:3000

# Benchmark Express.js
wrk -t4 -c100 -d30s http://localhost:3001
```
