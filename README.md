# MySQL & Dolt Dart Workspace

[![Build Status](https://github.com/kevmoo/mysql.dart/actions/workflows/validate.yaml/badge.svg)](https://github.com/kevmoo/mysql.dart/actions/workflows/validate.yaml)

A modular, multi-package Dart workspace housing native MySQL wire protocol
drivers, serverless [Dolt](https://www.dolthub.com/) database orchestration
hooks, and type-safe SQL adapters.

---

## Packages

| Package | Version | Description |
| :--- | :--- | :--- |
| [**mysql_client**](pkgs/mysql_client) | `private` | Native MySQL & MariaDB client in Dart. Supports TLS, connection pooling, multi-statement queries, and streaming iterable result sets. |
| [**dolt**](pkgs/dolt) | `0.1.0-wip` | Modular serverless Dolt database hooks, `typed_sql` adapter bindings, local SQL daemon lifecycle management, and Shelf web middleware. |

---

## Architectural Highlights

### 1. High-Performance MySQL Driver (`mysql_client`)
* **Pure Dart Implementation:** Communicates natively over the MySQL 4.1+ wire
  protocol without external C dependencies.
* **Robust Connection Management:** Features `MySQLConnectionPool` for automated
  connection recycling, transaction savepoints, and TLS authentication.
* **Broad Database Compatibility:** Tested against MySQL Percona Server
  (5.7, 8.4), MariaDB (10), Apache Doris, and Dolt SQL servers.

### 2. Serverless Dolt Orchestration (`dolt`)
* **Zero-Lock Concurrency (`DoltProcess`):** Spawns and lifecycle-manages a
  lightweight background `dolt sql-server` on an unused loopback TCP port
  (`127.0.0.1:0`). Multiple local utilities or autonomous agents can query
  simultaneously via MVCC without hitting disk file lock contention
  (`SQLITE_BUSY` or `.dolt` lock files).
* **SQL-Procedure Sync (`DoltSyncClient`):** Executes Git-like version control
  operations and backup pushes directly through SQL procedures
  (`CALL dolt_add('.')`, `CALL dolt_commit(...)`, `CALL dolt_push(...)`) without
  shelling out to OS subprocesses.
* **Type-Safe & Dual-Engine Ready (`DoltMysqlAdapter`):** Implements a native
  adapter for `typed_sql`. Applications can seamlessly switch between embedded
  SQLite (for offline work or hermetic test sandboxes) and networked
  MySQL-flavored Dolt without changing domain SQL queries.

---

## Development & Testing

This project is structured as a standard Dart multi-package workspace
(`resolution: workspace`). Requires Dart SDK **v3.13.0-0** or higher.

### Quick Start
```bash
# Resolve dependencies across all member packages
dart pub get

# Run static analysis across the entire workspace
dart analyze --fatal-infos

# Verify code formatting against the latest Dart dev style
dart format --set-exit-if-changed .
```
