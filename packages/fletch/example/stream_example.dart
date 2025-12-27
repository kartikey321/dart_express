import 'dart:io';
import 'package:fletch/fletch.dart';

Future<void> main() async {
  final app = Fletch();

  // Example 1: Stream a file
  app.get('/video', (req, res) async {
    final file = File('example/assets/sample.mp4');
    if (await file.exists()) {
      await res.stream(
        file.openRead(),
        contentType: 'video/mp4',
      );
    } else {
      res.json({'error': 'File not found'}, statusCode: 404);
    }
  });

  // Example 2: Stream with flush-per-chunk (real-time)
  app.get('/real-time-stream', (req, res) async {
    final stream = Stream<List<int>>.periodic(
      Duration(seconds: 1),
      (count) {
        final message = 'Chunk $count\n';
        return message.codeUnits;
      },
    ).take(10);

    await res.stream(
      stream,
      contentType: 'text/plain',
      flushEachChunk: true, // Flush immediately for real-time delivery
    );
  });

  // Example 3: Stream generated data
  app.get('/data-stream', (req, res) async {
    Stream<List<int>> generateData() async* {
      for (var i = 0; i < 100; i++) {
        await Future.delayed(Duration(milliseconds: 100));
        final data = 'Data packet $i\n';
        yield data.codeUnits;
      }
    }

    await res.stream(
      generateData(),
      contentType: 'text/plain',
      flushEachChunk: true,
    );
  });

  // Example 4: Chunked JSON stream
  app.get('/json-stream', (req, res) async {
    Stream<List<int>> jsonStream() async* {
      yield '['.codeUnits;

      for (var i = 0; i < 10; i++) {
        if (i > 0) yield ','.codeUnits;
        await Future.delayed(Duration(milliseconds: 500));
        final json = '{"id":$i,"value":"Item $i"}';
        yield json.codeUnits;
      }

      yield ']'.codeUnits;
    }

    await res.stream(
      jsonStream(),
      contentType: 'application/json',
      flushEachChunk: true,
    );
  });

  // HTML page to test streaming
  app.get('/', (req, res) {
    res.html('''
<!DOCTYPE html>
<html>
<head>
  <title>Fletch Streaming Example</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; }
    .output { padding: 10px; margin: 10px 0; background: #f0f0f0; border-radius: 4px; 
              min-height: 100px; max-height: 300px; overflow-y: auto; }
    button { padding: 10px 20px; margin: 5px; cursor: pointer; }
    pre { margin: 0; white-space: pre-wrap; }
  </style>
</head>
<body>
  <h1>Fletch Streaming Examples</h1>
  
  <h2>Real-time Text Stream</h2>
  <button onclick="streamRealTime()">Start Real-time Stream</button>
  <div class="output" id="realtime"><pre></pre></div>
  
  <h2>Data Stream</h2>
  <button onclick="streamData()">Start Data Stream</button>
  <div class="output" id="data"><pre></pre></div>
  
  <h2>JSON Stream</h2>
  <button onclick="streamJSON()">Start JSON Stream</button>
  <div class="output" id="json"><pre></pre></div>
  
  <script>
    async function streamRealTime() {
      const output = document.querySelector('#realtime pre');
      output.textContent = 'Streaming...\\n';
      
      const response = await fetch('/real-time-stream');
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      
      while (true) {
        const {done, value} = await reader.read();
        if (done) break;
        output.textContent += decoder.decode(value);
      }
      
      output.textContent += '\\nStream complete!';
    }
    
    async function streamData() {
      const output = document.querySelector('#data pre');
      output.textContent = 'Streaming...\\n';
      
      const response = await fetch('/data-stream');
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      
      while (true) {
        const {done, value} = await reader.read();
        if (done) break;
        output.textContent += decoder.decode(value);
      }
      
      output.textContent += '\\nStream complete!';
    }
    
    async function streamJSON() {
      const output = document.querySelector('#json pre');
      output.textContent = 'Streaming...\\n';
      
      const response = await fetch('/json-stream');
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      
      while (true) {
        const {done, value} = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, {stream: true});
        output.textContent = buffer;
      }
      
      output.textContent += '\\nStream complete!';
    }
  </script>
</body>
</html>
    ''');
  });

  await app.listen(8080);
  print('Streaming example running on http://localhost:8080');
}
