{
  "name": "AWS DocumentDB Database",
  "slug": "documentdb-database",
  "type": "dependency",
  "unique": false,
  "assignable_to": "any",
  "use_default_actions": true,
  "available_links": [
    "connect"
  ],
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
      "required": [],
      "properties": {
        "db_name": {
          "type": "string",
          "title": "Database Name",
          "pattern": "^[a-zA-Z_][a-zA-Z0-9_-]{0,62}$",
          "description": "Name of the database to create inside the cluster. Left empty, it is derived from the application ID as app_<application_id>.",
          "editableOn": [
            "create"
          ],
          "order": 1
        },
        "cluster_service_id": {
          "type": "string",
          "title": "Cluster Service ID",
          "description": "Pin this database to a specific documentdb-cluster service. Leave empty to auto-discover the cluster in this namespace \u2014 which only works when there is exactly one.",
          "editableOn": [
            "create"
          ],
          "order": 2
        },
        "drop_on_delete": {
          "type": "boolean",
          "title": "Drop Database On Delete",
          "default": false,
          "description": "Whether deleting this service also drops the database and its data from the cluster. Off by default: the service disappears and the data stays, which is recoverable. Turning it on makes deletion irreversible.",
          "editableOn": [
            "create",
            "update"
          ],
          "order": 3
        },
        "database_name": {
          "type": "string",
          "title": "Database",
          "export": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Database that was created (auto-populated after creation)",
          "order": 4
        },
        "endpoint": {
          "type": "string",
          "title": "Cluster Endpoint",
          "export": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Writer endpoint of the cluster hosting this database (auto-populated, inherited from the cluster service)",
          "order": 5
        },
        "reader_endpoint": {
          "type": "string",
          "title": "Reader Endpoint",
          "export": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Load-balanced read endpoint of the hosting cluster (auto-populated)",
          "order": 6
        },
        "port": {
          "type": "number",
          "title": "Port",
          "export": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "Cluster port (auto-populated). DocumentDB always listens on 27017.",
          "order": 7
        },
        "tls_ca_url": {
          "type": "string",
          "title": "TLS CA Bundle URL",
          "export": true,
          "visibleOn": [
            "read"
          ],
          "editableOn": [],
          "description": "URL of the Amazon RDS global CA bundle, needed by clients to verify the cluster certificate",
          "order": 8
        },
        "resolved_cluster_service_id": {
          "type": "string",
          "export": false,
          "visibleOn": [],
          "editableOn": [],
          "description": "ID of the cluster service this database was actually placed in. Recorded on create and reused on every later action, so auto-discovery never re-runs and cannot drift to a different cluster."
        },
        "cluster_identifier": {
          "type": "string",
          "export": false,
          "visibleOn": [],
          "editableOn": [],
          "description": "Internal AWS DocumentDB cluster identifier of the hosting cluster"
        },
        "master_secret_arn": {
          "type": "string",
          "export": false,
          "visibleOn": [],
          "editableOn": [],
          "description": "ARN of the hosting cluster's master credentials secret (read by link actions to provision users)"
        }
      }
    },
    "values": {}
  }
}
