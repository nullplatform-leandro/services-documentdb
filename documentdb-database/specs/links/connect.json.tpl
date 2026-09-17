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
      "required": ["access_level"],
      "properties": {
        "access_level": {
          "enum": ["read", "write", "read-write"],
          "type": "string",
          "title": "Access Level",
          "default": "read-write",
          "description": "Permission level on this service's database: read (find), write (insert/update/remove, no reads), read-write (both). Unlike the cluster service, the database is fixed — it is the one this service owns.",
          "editableOn": ["create", "update"],
          "order": 1
        },
        "username": {
          "type": "string",
          "title": "Username",
          "export": true,
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "MongoDB user created for this link (auto-populated after link creation)",
          "order": 2
        },
        "password": {
          "type": "string",
          "title": "Password",
          "export": {"type": "environment_variable", "secret": true},
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "Password for that user (auto-populated, delivered as a secret env var)",
          "order": 3
        },
        "connection_string": {
          "type": "string",
          "title": "Connection String",
          "export": {"type": "environment_variable", "secret": true},
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "Ready-to-use mongodb:// URI with credentials, TLS and retryWrites=false already set (auto-populated, delivered as a secret env var)",
          "order": 4
        }
      }
    },
    "values": {}
  }
}
