# MySQL Dart Workspace

[![Build Status](https://github.com/kevmoo/mysql.dart/actions/workflows/validate.yaml/badge.svg)](https://github.com/kevmoo/mysql.dart/actions/workflows/validate.yaml)

A Dart workspace housing [`mysql_client`](pkgs/mysql_client), a pure-Dart MySQL
wire protocol driver tested against MySQL, MariaDB, Apache Doris, and
[Dolt](https://www.dolthub.com/).

---

## Packages

| Package                               | Version   | Description                                                                                                                           |
| :------------------------------------ | :-------- | :------------------------------------------------------------------------------------------------------------------------------------ |
| [**mysql_client**](pkgs/mysql_client) | `private` | Native MySQL & MariaDB client in Dart. Supports TLS, connection pooling, multi-statement queries, and streaming iterable result sets. |

---

## Architectural Highlights

- **Pure Dart Implementation:** Communicates natively over the MySQL 4.1+ wire
  protocol without external C dependencies.
- **Robust Connection Management:** Features `MySQLConnectionPool` for automated
  connection recycling, transaction savepoints, Unix domain sockets, and TLS
  authentication.
- **Broad Database Compatibility:** Tested against MySQL Percona Server (5.7,
  8.4), MariaDB (10), Apache Doris, and Dolt SQL servers.

---

## Development & Testing

This project is structured as a standard Dart workspace
(`resolution: workspace`). Requires Dart SDK **v3.13.0-0** or higher.

### Quick Start

```bash
# Resolve dependencies across the workspace
dart pub get

# Run static analysis across the workspace
dart analyze --fatal-infos

# Verify code formatting against the latest Dart dev style
dart format --set-exit-if-changed .
```
