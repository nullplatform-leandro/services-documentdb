{
  "name": "Connect",
  "slug": "connect",
  "unique": false,
  "assignable_to": "any",
  "use_default_actions": true,
  "selectors": {
    "category": "Database",
    "imported": false,
    "provider": "AWS",
    "sub_category": "Document Database"
  },
  "attributes": {
    "schema": {
      "type": "object",
      "$schema": "http://json-schema.org/draft-07/schema#",
      "required": ["db_name", "access_level"],
      "properties": {
        "db_name": {
          "type": "string",
          "title": "Database Name",
          "pattern": "^[a-zA-Z_][a-zA-Z0-9_-]{0,62}$",
          "description": "Database inside the cluster this link gets access to. MongoDB creates a database lazily, on first write, so the name is reserved here and materialises when the app writes to it.",
          "editableOn": ["create"],
          "order": 1
        },
        "access_level": {
          "enum": ["read", "write", "read-write"],
          "type": "string",
          "title": "Access Level",
          "default": "read-write",
          "description": "Permission level on that database: read (find), write (insert/update/remove, no reads), read-write (both).",
          "editableOn": ["create", "update"],
          "order": 2
        },
        "username": {
          "type": "string",
          "title": "Username",
          "export": true,
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "MongoDB user created for this link (auto-populated after link creation)",
          "order": 3
        },
        "password": {
          "type": "string",
          "title": "Password",
          "export": {"type": "environment_variable", "secret": true},
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "Password for that user (auto-populated, delivered as a secret env var)",
          "order": 4
        },
        "database_name": {
          "type": "string",
          "title": "Database",
          "export": true,
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "Database this link is scoped to (auto-populated after link creation)",
          "order": 5
        },
        "connection_string": {
          "type": "string",
          "title": "Connection String",
          "export": {"type": "environment_variable", "secret": true},
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "Ready-to-use mongodb:// URI with credentials, TLS and retryWrites=false already set (auto-populated, delivered as a secret env var)",
          "order": 6
        }
      }
    },
    "values": {}
  }
}
