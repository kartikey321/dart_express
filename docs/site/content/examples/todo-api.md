# TODO API Example

A complete REST API for managing TODO items, demonstrating CRUD operations, validation, and error handling.

## Overview

This example shows:
- ✅ RESTful API design
- ✅ In-memory data storage
- ✅ Request validation
- ✅ Error handling
- ✅ CORS support

## Complete Code

```dart
import 'package:dart_express/dart_express.dart';

class Todo {
  final String id;
  String title;
  bool completed;
  DateTime createdAt;
  
  Todo({
    required this.id,
    required this.title,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
    'createdAt': createdAt.toIso8601String(),
  };
}

void main() async {
  final app = DartExpress();
  
  // In-memory storage
  final todos = <String, Todo>{};
  var nextId = 1;
  
  // CORS
  app.use(app.cors());
  
  // GET /todos - List all todos
  app.get('/todos', (req, res) {
    res.json({
      'todos': todos.values.map((t) => t.toJson()).toList(),
      'count': todos.length,
    });
  });
  
  // GET /todos/:id - Get single todo
  app.get('/todos/:id', (req, res) {
    final todo = todos[req.params['id']];
    
    if (todo == null) {
      return res.status(404).json({'error': 'Todo not found'});
    }
    
    res.json(todo.toJson());
  });
  
  // POST /todos - Create todo
  app.post('/todos', (req, res) async {
    final body = await req.body;
    
    // Validation
    if (body['title'] == null || body['title'].toString().trim().isEmpty) {
      return res.status(400).json({'error': 'Title is required'});
    }
    
    // Create todo
    final id = (nextId++).toString();
    final todo = Todo(
      id: id,
      title: body['title'].toString().trim(),
    );
    
    todos[id] = todo;
    
    res.status(201).json(todo.toJson());
  });
  
  // PUT /todos/:id - Update todo
  app.put('/todos/:id', (req, res) async {
    final todo = todos[req.params['id']];
    
    if (todo == null) {
      return res.status(404).json({'error': 'Todo not found'});
    }
    
    final body = await req.body;
    
    // Update fields
    if (body['title'] != null) {
      todo.title = body['title'].toString().trim();
    }
    if (body['completed'] != null) {
      todo.completed = body['completed'] as bool;
    }
    
    res.json(todo.toJson());
  });
  
  // DELETE /todos/:id - Delete todo
  app.delete('/todos/:id', (req, res) {
    final todo = todos.remove(req.params['id']);
    
    if (todo == null) {
      return res.status(404).json({'error': 'Todo not found'});
    }
    
    res.status(204).send();
  });
  
  await app.listen(3000);
  print('🚀 TODO API running on http://localhost:3000');
}
```

## API Endpoints

### List Todos
```bash
GET /todos
```

Response:
```json
{
  "todos": [
    {
      "id": "1",
      "title": "Buy groceries",
      "completed": false,
      "createdAt": "2024-01-01T10:00:00.000Z"
    }
  ],
  "count": 1
}
```

### Get Todo
```bash
GET /todos/:id
```

Response:
```json
{
  "id": "1",
  "title": "Buy groceries",
  "completed": false,
  "createdAt": "2024-01-01T10:00:00.000Z"
}
```

### Create Todo
```bash
POST /todos
Content-Type: application/json

{
  "title": "Buy groceries"
}
```

Response (201):
```json
{
  "id": "1",
  "title": "Buy groceries",
  "completed": false,
  "createdAt": "2024-01-01T10:00:00.000Z"
}
```

### Update Todo
```bash
PUT /todos/:id
Content-Type: application/json

{
  "completed": true
}
```

Response:
```json
{
  "id": "1",
  "title": "Buy groceries",
  "completed": true,
  "createdAt": "2024-01-01T10:00:00.000Z"
}
```

### Delete Todo
```bash
DELETE /todos/:id
```

Response: 204 No Content

## Testing with cURL

```bash
# Create a todo
curl -X POST http://localhost:3000/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Buy milk"}'

# List all todos
curl http://localhost:3000/todos

# Get specific todo
curl http://localhost:3000/todos/1

# Update todo
curl -X PUT http://localhost:3000/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"completed":true}'

# Delete todo
curl -X DELETE http://localhost:3000/todos/1
```

## Extensions

### Add Filtering

```dart
app.get('/todos', (req, res) {
  var filtered = todos.values;
  
  // Filter by completion status
  final completed = req.query['completed'];
  if (completed != null) {
    final isCompleted = completed == 'true';
    filtered = filtered.where((t) => t.completed == isCompleted);
  }
  
  res.json({
    'todos': filtered.map((t) => t.toJson()).toList(),
  });
});
```

### Add Sorting

```dart
app.get('/todos', (req, res) {
  var list = todos.values.toList();
  
  // Sort by creation date
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  
  res.json({'todos': list.map((t) => t.toJson()).toList()});
});
```

### Add Pagination

```dart
app.get('/todos', (req, res) {
  final page = int.tryParse(req.query['page'] ?? '1') ?? 1;
  final limit = int.tryParse(req.query['limit'] ?? '10') ?? 10;
  
  final list = todos.values.toList();
  final start = (page - 1) * limit;
  final end = start + limit;
  
  res.json({
    'todos': list.skip(start).take(limit).map((t) => t.toJson()).toList(),
    'page': page,
    'totalPages': (list.length / limit).ceil(),
    'total': list.length,
  });
});
```

## Running the Example

The full example is available at:
```
/apps/dart_express_examples/todo_api_example
```

Run it:
```bash
cd apps/dart_express_examples/todo_api_example
dart run bin/server.dart
```

<div style="display:flex;justify-content:space-between;gap:1rem;align-items:center;margin:2rem 0;">
  <a href="/deployment/docker" style="display:flex;align-items:center;gap:0.4rem;text-decoration:none;color:inherit;">
    <span aria-hidden="true">‹</span>
    <span>🐳 Docker</span>
  </a>
  <a href="/advanced/isolated-containers" style="display:flex;align-items:center;gap:0.4rem;text-decoration:none;color:inherit;">
    <span>🧱 Isolated Containers</span>
    <span aria-hidden="true">›</span>
  </a>
</div>
