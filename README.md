# Redis-Server

Redis-Server is an educational Redis-inspired in-memory database server written in C++17. It implements a threaded TCP server, RESP-style command handling, core data structures, TTL expiration, and persistence to disk.

## Features

- Multi-threaded TCP server
- RESP-compatible request/response flow
- String, List, and Hash data types
- Per-key TTL / expiration handling
- Persistence through local dump files
- Usable from raw TCP clients and Redis-style command flows

## Tech Stack

- C++17
- POSIX sockets / TCP networking
- Multithreading with `pthread`
- Custom command parsing and storage logic
- Make-based build system

## Project Structure

- `src/` - server, database, command handler, and entrypoint implementation
- `include/` or header files in root - public class definitions
- `Makefile` - build and rebuild workflow
- `PROJECT_DOCUMENTATION.md` - deeper project write-up
- `UseCases.md` - example command scenarios

## Build

```bash
make
```

## Run

```bash
./my_redis_server
```

## Example Usage

```bash
nc localhost 6379
SET name Alice
GET name
LPUSH tasks task1
HSET user email alice@example.com
```

## Skills Demonstrated

- Systems programming in C++
- TCP server implementation
- In-memory data structure design
- Concurrency and synchronization
- Persistence and protocol parsing

## Notes

This project is designed as a learning-oriented server implementation rather than a production Redis replacement. For deeper design notes, see `PROJECT_DOCUMENTATION.md`.
