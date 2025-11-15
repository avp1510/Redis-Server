# Redis-Server (C++ Educational Implementation)

This repository contains a small Redis-like in-memory database server implemented in C++17.

Summary
- Multi-threaded TCP server (port 6379 by default)
- Supports Strings, Lists, and Hashes
- RESP-formatted responses for compatibility with redis-cli / raw clients
- Persistence via `dump.my_rdb` (periodic + shutdown dump)
- TTL/expiration support per-key

Build
```bash
make
```

Run
```bash
./my_redis_server
```

Connect (example with netcat)
```bash
nc localhost 6379
SET name Alice
GET name
```

See `PROJECT_DOCUMENTATION.md` for full details.
