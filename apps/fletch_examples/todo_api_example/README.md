# TODO REST API Example

Simple REST API built with fletch.

## Quick Start

```bash
dart pub get
dart run bin/server.dart
```

Server runs on `http://localhost:3000`

## API Endpoints

### List Todos
```bash
curl http://localhost:3000/todos
```

### Create Todo
```bash
curl -X POST http://localhost:3000/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Buy groceries", "completed": false}'
```

### Get Todo
```bash
curl http://localhost:3000/todos/{id}
```

### Update Todo
```bash
curl -X PUT http://localhost:3000/todos/{id} \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'
```

### Delete Todo
```bash
curl -X DELETE http://localhost:3000/todos/{id}
```

## Test with HTTPie

```bash
# Create
http POST :3000/todos title="Learn Dart"

# List
http :3000/todos

# Update
http PUT :3000/todos/{id} completed:=true

# Delete
http DELETE :3000/todos/{id}
```

## Features

✅ RESTful API design  
✅ JSON request/response  
✅ Input validation  
✅ Error handling  
✅ CORS enabled  
✅ Health check endpoint  

## Next Steps

- Add database (see `mongo_example`)
- Add authentication (see `session_security_example`)
- Add pagination and filtering
- Add tests
