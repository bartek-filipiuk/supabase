# Supabase API Tutorial

This tutorial explains how to interact with your Supabase REST API at `mybases.pl:8443`. It covers basic CRUD operations and more advanced features.

## Prerequisites

- A Supabase instance running at `mybases.pl:8443`
- Your Supabase API key (found in your `.env` file)

## Authentication

All requests to the Supabase API require authentication headers:

```bash
# Required headers
-H "apikey: YOUR_ANON_KEY"  # Found in .env as ANON_KEY
-H "Authorization: Bearer YOUR_ANON_KEY"  # Same key, with "Bearer " prefix
```

## Basic CRUD Operations

### 1. Read Data

#### Fetch all rows from a table

```bash
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

#### Fetch specific columns

```bash
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=id,title" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

#### Filter data

```bash
# Get completed todos
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*&completed=eq.true" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"

# Get todos with specific IDs
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*&id=eq.1" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

#### Ordering results

```bash
# Order by ID in ascending order
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*&order=id.asc" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"

# Order by title in descending order
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*&order=title.desc" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

#### Pagination

```bash
# Limit to 2 results
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*&limit=2" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"

# Limit to 2 results, offset by 2 (get items 3-4)
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*&limit=2&offset=2" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

### 2. Create Data

#### Insert a single row

```bash
curl -X POST "https://mybases.pl:8443/rest/v1/todos" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title": "New task", "completed": false}'
```

#### Insert multiple rows

```bash
curl -X POST "https://mybases.pl:8443/rest/v1/todos" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '[
    {"title": "Task 1", "completed": false},
    {"title": "Task 2", "completed": false}
  ]'
```

### 3. Update Data

#### Update a single row

```bash
curl -X PATCH "https://mybases.pl:8443/rest/v1/todos?id=eq.1" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'
```

#### Update multiple rows

```bash
curl -X PATCH "https://mybases.pl:8443/rest/v1/todos?completed=eq.false" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'
```

### 4. Delete Data

#### Delete a single row

```bash
curl -X DELETE "https://mybases.pl:8443/rest/v1/todos?id=eq.1" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

#### Delete multiple rows

```bash
curl -X DELETE "https://mybases.pl:8443/rest/v1/todos?completed=eq.true" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## Advanced Queries

### 1. Full-Text Search

If your table has text columns and PostgreSQL text search enabled:

```bash
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*&title=fts.groceries" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

### 2. Count Rows

```bash
# Count all rows
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=count" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"

# Count filtered rows
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=count&completed=eq.true" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

### 3. Range Operations

```bash
# Get todos with IDs between 1 and 3
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*&id=gte.1&id=lte.3" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

### 4. Pattern Matching (LIKE)

```bash
# Find todos containing "Super" in the title
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*&title=like.*Super*" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## Working with Related Tables

If you have related tables with foreign keys:

### 1. Fetch related data

```bash
# Assuming a users table with user_id as foreign key in todos
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*,users(*)" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

### 2. Filter by related data

```bash
# Get todos for users with a specific email
curl -X GET "https://mybases.pl:8443/rest/v1/todos?select=*&users.email=eq.user@example.com" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## Using Custom Procedures/Functions

If you have SQL functions in your database:

```bash
# Call a function named get_completed_todos
curl -X POST "https://mybases.pl:8443/rest/v1/rpc/get_completed_todos" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"

# Call a function with parameters
curl -X POST "https://mybases.pl:8443/rest/v1/rpc/get_todos_by_status" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"status": true}'
```

## Working with Supabase in Programming Languages

### JavaScript (Fetch API)

```javascript
const fetchTodos = async () => {
  const response = await fetch('https://mybases.pl:8443/rest/v1/todos?select=*', {
    headers: {
      'apikey': 'YOUR_ANON_KEY',
      'Authorization': 'Bearer YOUR_ANON_KEY'
    }
  });
  
  const data = await response.json();
  console.log(data);
};

fetchTodos();
```

### Python (Requests)

```python
import requests

headers = {
    'apikey': 'YOUR_ANON_KEY',
    'Authorization': 'Bearer YOUR_ANON_KEY'
}

response = requests.get('https://mybases.pl:8443/rest/v1/todos?select=*', headers=headers)
data = response.json()
print(data)
```

### PHP (cURL)

```php
<?php
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'https://mybases.pl:8443/rest/v1/todos?select=*');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'apikey: YOUR_ANON_KEY',
    'Authorization: Bearer YOUR_ANON_KEY'
]);

$response = curl_exec($ch);
curl_close($ch);

$data = json_decode($response, true);
print_r($data);
?>
```

## Using the Supabase JavaScript Client

If you prefer using the Supabase client library instead of raw HTTP requests:

```javascript
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://mybases.pl:8443';
const supabaseKey = 'YOUR_ANON_KEY';
const supabase = createClient(supabaseUrl, supabaseKey);

// Fetch all todos
const getTodos = async () => {
  const { data, error } = await supabase
    .from('todos')
    .select('*');
  
  if (error) console.error('Error fetching todos:', error);
  else console.log('Todos:', data);
};

// Insert a new todo
const addTodo = async (title) => {
  const { data, error } = await supabase
    .from('todos')
    .insert([{ title, completed: false }]);
  
  if (error) console.error('Error adding todo:', error);
  else console.log('Added todo:', data);
};

// Update a todo
const updateTodo = async (id, completed) => {
  const { data, error } = await supabase
    .from('todos')
    .update({ completed })
    .eq('id', id);
  
  if (error) console.error('Error updating todo:', error);
  else console.log('Updated todo:', data);
};

// Delete a todo
const deleteTodo = async (id) => {
  const { error } = await supabase
    .from('todos')
    .delete()
    .eq('id', id);
  
  if (error) console.error('Error deleting todo:', error);
  else console.log('Todo deleted successfully');
};
```

## Conclusion

This tutorial covered the basics of interacting with the Supabase REST API. Remember to always:

1. Include the proper authentication headers with each request
2. Format your request data according to the API's requirements
3. Handle errors appropriately in your application

For more detailed information, refer to the [official Supabase documentation](https://supabase.com/docs/reference/javascript/introduction).