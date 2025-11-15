# Redis Implementation - Full Project Documentation

## Project Overview

This is a **C++ implementation of a Redis-like in-memory database server**. It provides:
- Multi-threaded TCP server accepting client connections
- In-memory storage for strings, lists, and hashes
- Persistence through dump/load functionality
- TTL (Time-To-Live) support for key expiration
- RESP (Redis Serialization Protocol) compatible command responses
- Thread-safe operations using mutex locks

**Language:** C++17  
**Build System:** Makefile with g++  
**Executable:** `my_redis_server`  
**Default Port:** 6379

---

## Project Structure

```
/Users/abhishek/Documents/Redis/
├── Makefile                 # Build configuration
├── my_redis_server          # Compiled executable (after make)
├── dump.my_rdb              # Persistence file (created on shutdown)
├── include/
│   ├── RedisServer.h        # TCP server class definition
│   ├── RedisDatabase.h      # In-memory database class definition
│   └── RedisCommandHandler.h # Command parser and processor
├── src/
│   ├── main.cpp             # Application entry point
│   ├── RedisServer.cpp      # TCP server implementation
│   ├── RedisDatabase.cpp    # Database implementation
│   ├── RedisCommandHandler.cpp # Command parsing & execution
│   └── UseCases.md          # Usage examples
└── build/
    ├── *.o                  # Compiled object files
    └── *.d                  # Dependency files
```

---

## Core Components

### 1. **RedisServer.h / RedisServer.cpp**

**Purpose:** TCP socket server that listens for client connections

**Key Members:**
- `port` — Server listening port (default: 6379)
- `server_socket` — Socket file descriptor
- `running` — Atomic boolean for graceful shutdown
- `globalServer` — Static pointer for signal handler access

**Key Methods:**

| Method | Purpose |
|--------|---------|
| `RedisServer(int port)` | Constructor; initializes port and signal handlers |
| `run()` | Main server loop: binds socket, listens, accepts clients |
| `shutdown()` | Gracefully closes server, dumps database to file |
| `setupSignalHandler()` | Registers SIGINT/SIGTERM handlers for Ctrl+C |

**Flow:**
1. Constructor sets up signal handlers (catches Ctrl+C)
2. `run()` creates a TCP socket, binds to port 6379
3. Enters accept loop; for each client, spawns a new thread
4. Each thread:
   - Receives raw command bytes from client
   - Strips newlines/carriage returns
   - Passes command to `RedisCommandHandler::processCommand()`
   - Sends RESP-formatted response back to client
5. On shutdown (Ctrl+C): calls `RedisDatabase::dump()` and closes sockets

**Code Snippet (Client Handler):**
```cpp
threads.emplace_back([client_socket, &cmdHandler](){
    char buffer[1024];
    while (true) {
        int bytes = recv(client_socket, buffer, sizeof(buffer) - 1, 0);
        if (bytes <= 0) break;
        std::string request(buffer, bytes);
        
        // Trim newlines
        while (!request.empty() && (request.back() == '\n' || request.back() == '\r')) {
            request.pop_back();
        }
        
        std::string response = cmdHandler.processCommand(request);
        if (!response.empty()) {
            send(client_socket, response.c_str(), response.size(), 0);
        }
    }
    close(client_socket);
});
```

---

### 2. **RedisDatabase.h / RedisDatabase.cpp**

**Purpose:** In-memory data storage engine with three data structure types

**Singleton Pattern:**
```cpp
static RedisDatabase& getInstance();  // Returns single global instance
```

**Internal Data Structures:**

| Store | Type | Purpose |
|-------|------|---------|
| `kv_store` | `unordered_map<string, string>` | Key-value pairs |
| `list_store` | `unordered_map<string, vector<string>>` | Lists (vectors) |
| `hash_store` | `unordered_map<string, unordered_map<string, string>>` | Hashes (nested maps) |
| `expiry_map` | `unordered_map<string, time_point>` | Expiration deadlines |
| `db_mutex` | `mutex` | Thread synchronization |

**Key-Value Operations:**

| Command | Method Signature | Purpose |
|---------|------------------|---------|
| SET | `void set(key, value)` | Store a string |
| GET | `bool get(key, value&)` | Retrieve a string |
| DEL | `bool del(key)` | Delete a key |
| KEYS | `vector<string> keys()` | List all keys |
| TYPE | `string type(key)` | Get data type |
| EXPIRE | `bool expire(key, seconds)` | Set TTL |
| TTL | (handled in CommandHandler) | Get remaining TTL |
| RENAME | `bool rename(oldKey, newKey)` | Rename a key |
| FLUSHALL | `bool flushAll()` | Clear all data |

**List Operations (LIFO/FIFO queues):**

| Command | Method Signature | Purpose |
|---------|------------------|---------|
| LPUSH | `void lpush(key, value)` | Push to left end |
| RPUSH | `void rpush(key, value)` | Push to right end |
| LPOP | `bool lpop(key, value&)` | Pop from left end |
| RPOP | `bool rpop(key, value&)` | Pop from right end |
| LLEN | `ssize_t llen(key)` | Get list length |
| LINDEX | `bool lindex(key, index, value&)` | Get element at index |
| LSET | `bool lset(key, index, value)` | Set element at index |
| LREM | `int lrem(key, count, value)` | Remove elements |
| LRANGE | `vector<string> lget(key)` | Get all elements |

**Hash Operations (field-value pairs):**

| Command | Method Signature | Purpose |
|---------|------------------|---------|
| HSET | `bool hset(key, field, value)` | Set field in hash |
| HGET | `bool hget(key, field, value&)` | Get field from hash |
| HDEL | `bool hdel(key, field)` | Delete field |
| HEXISTS | `bool hexists(key, field)` | Check field exists |
| HGETALL | `map<string,string> hgetall(key)` | Get all fields/values |
| HKEYS | `vector<string> hkeys(key)` | Get all field names |
| HVALS | `vector<string> hvals(key)` | Get all values |
| HLEN | `ssize_t hlen(key)` | Get field count |
| HMSET | `bool hmset(key, fieldValues)` | Set multiple fields |

**Persistence:**

| Method | Purpose |
|--------|---------|
| `bool dump(filename)` | Serialize all data to text file |
| `bool load(filename)` | Deserialize data from text file |

**TTL & Expiration:**
- **Default:** Keys never expire unless `expire(key, seconds)` is called
- **Lazy Purging:** `purgeExpired()` removes expired keys when called by other operations
- **Storage:** Expiration times stored as `steady_clock::time_point` (absolute deadline)

**Thread Safety:**
- All public methods lock `db_mutex` before accessing stores
- Prevents race conditions in multi-threaded environment

---

### 3. **RedisCommandHandler.h / RedisCommandHandler.cpp**

**Purpose:** Parse client commands and dispatch to database operations

**Key Method:**
```cpp
std::string processCommand(const std::string& commandLine);
```

**Supported Command Formats:**

1. **Simple Text Format** (from `nc` or raw telnet):
   ```
   SET key value
   GET key
   LPUSH list a b c
   HSET hash field value
   ```

2. **RESP Array Format** (from redis-cli):
   ```
   *2\r\n$3\r\nGET\r\n$3\r\nkey\r\n
   ```

**Command Processing Pipeline:**
1. Parse command string into tokens
2. Extract command name (first token)
3. Validate argument count
4. Call appropriate `RedisDatabase` method
5. Format result as RESP response

**RESP Response Formats:**

| Type | Format | Example |
|------|--------|---------|
| Simple String | `+message\r\n` | `+OK\r\n` |
| Error | `-Error message\r\n` | `-ERR unknown command\r\n` |
| Integer | `:number\r\n` | `:42\r\n` |
| Bulk String | `$length\r\ndata\r\n` | `$3\r\nfoo\r\n` |
| Null Bulk | `$-1\r\n` | (missing key) |
| Array | `*count\r\n[elements]\r\n` | `*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n` |

**Supported Commands** (with arguments):

| Category | Commands |
|----------|----------|
| **String** | SET, GET, DEL, TYPE, EXPIRE, TTL, RENAME, KEYS |
| **List** | LPUSH, RPUSH, LPOP, RPOP, LLEN, LINDEX, LSET, LREM, LRANGE |
| **Hash** | HSET, HGET, HDEL, HEXISTS, HGETALL, HKEYS, HVALS, HLEN, HMSET |
| **Admin** | FLUSHALL, COMMAND, PING |

**Example Command Processing:**
```
Input:  "SET mykey hello"
Parse:  tokens = ["SET", "mykey", "hello"]
Call:   RedisDatabase::getInstance().set("mykey", "hello")
Return: "+OK\r\n"

Input:  "GET mykey"
Parse:  tokens = ["GET", "mykey"]
Call:   RedisDatabase::getInstance().get("mykey", value)
Return: "$5\r\nhello\r\n"
```

---

### 4. **main.cpp**

**Purpose:** Application entry point and initialization

**Startup Sequence:**

```cpp
int main(int argc, char** argv) {
    // 1. Load existing database from dump file
    if (RedisDatabase::getInstance().load("dump.my_rdb"))
        std::cout << "Database loaded from dump.my_rdb.\n";
    else
        std::cout << "No dump found or load failed; starting with an empty database.\n";

    // 2. Start background persistence thread
    std::thread persistenceThread([](){
        while (true) {
            std::this_thread::sleep_for(std::chrono::seconds(300)); // 5 minutes
            RedisDatabase::getInstance().dump("dump.my_rdb");
        }
    });
    persistenceThread.detach();

    // 3. Create and run server
    RedisServer server(6379);
    server.run();  // Blocks until shutdown

    return 0;
}
```

**Key Features:**
- Restores data from previous session (if `dump.my_rdb` exists)
- Spawns background thread that saves database every 5 minutes
- Creates server on port 6379 and blocks in `run()` loop
- On Ctrl+C, signal handler calls `shutdown()` which dumps database

---

### 5. **Makefile**

**Purpose:** Automate compilation and linking

**Build Process:**

```makefile
CXX = g++
CXXFLAGS = -std=c++17 -Wall -pthread -MMD -MP -O2

# Compile all .cpp files to .o files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp
    $(CXX) $(CXXFLAGS) -c $< -o $@

# Link all .o files into executable
$(TARGET): $(OBJS)
    $(CXX) $(CXXFLAGS) $(OBJS) -o $(TARGET)
```

**Key Commands:**
| Command | Purpose |
|---------|---------|
| `make` | Compile all files and link into `my_redis_server` |
| `make clean` | Remove build directory and executable |
| `make rebuild` | Clean + make + run server |

**Flags Explained:**
- `-std=c++17` — Use C++17 standard
- `-Wall` — Enable all warnings
- `-pthread` — Link pthread library for threads
- `-O2` — Optimization level 2
- `-MMD -MP` — Generate dependency files automatically

---

## Data Flow Diagrams

### Request-Response Flow

```
Client (nc localhost 6379)
    ↓
[User types: "SET key value" + Enter]
    ↓
TCP Socket recv() in RedisServer thread
    ↓
Strip newlines from input
    ↓
RedisCommandHandler::processCommand("SET key value")
    ↓
Parse tokens: ["SET", "key", "value"]
    ↓
Call RedisDatabase::getInstance().set("key", "value")
    ↓
Lock db_mutex, add to kv_store
    ↓
Format RESP response: "+OK\r\n"
    ↓
Send back to client via TCP
    ↓
Client sees: +OK
```

### Startup Flow

```
./my_redis_server
    ↓
main() called
    ↓
RedisDatabase::getInstance().load("dump.my_rdb")
    ↓ (if file exists)
Restore kv_store, list_store, hash_store
    ↓
Spawn persistenceThread (saves every 300 seconds)
    ↓
RedisServer server(6379)
    ↓
server.run()
    ↓
Create socket, bind to :6379, listen
    ↓
Accept client connections in loop
    ↓ (for each client)
Spawn new thread, recv/process/send
```

### Shutdown Flow

```
User presses Ctrl+C
    ↓
signalHandler() called
    ↓
globalServer->shutdown()
    ↓
Set running = false (exits main loop)
    ↓
RedisDatabase::getInstance().dump("dump.my_rdb")
    ↓
Serialize all stores to file
    ↓
Close server socket
    ↓
Wait for all client threads to finish (join)
    ↓
Print "Server Shutdown Complete!"
    ↓
Exit program
```

---

## Persistence Format

**dump.my_rdb** is a text file with this structure:

```
KV [count]
key1 value1
key2 value2
...

LIST [count]
listkey1 size elem1 elem2 ...
listkey2 size elem1 elem2 ...
...

HASH [count]
hashkey1 fieldcount field1 value1 field2 value2 ...
hashkey2 fieldcount field1 value1 field2 value2 ...
...

EXPIRY [count]
key1 timestamp_seconds
key2 timestamp_seconds
...
```

**Example:**
```
KV 2
name Alice
age 30

LIST 1
colors 3 red green blue

HASH 1
user:1 2 email alice@example.com phone 555-1234

EXPIRY 0
```

---

## How to Use

### 1. Build
```bash
cd /Users/abhishek/Documents/Redis
make
```

### 2. Run Server
```bash
./my_redis_server
```

Expected output:
```
Database loaded from dump.my_rdb.
Redis Server Listening On Port 6379
```

### 3. Connect Client (Terminal 2)
```bash
nc localhost 6379
```

### 4. Execute Commands

**String Operations:**
```
SET name Alice
GET name
DEL name
EXPIRE key 300
TTL key
```

**List Operations:**
```
LPUSH fruits apple banana
RPUSH fruits orange
LPOP fruits
LLEN fruits
LRANGE fruits 0 -1
```

**Hash Operations:**
```
HSET user:1 name Alice age 30
HGET user:1 name
HGETALL user:1
HKEYS user:1
HVALS user:1
HDEL user:1 age
```

**Admin:**
```
KEYS
PING
FLUSHALL
```

### 5. Shutdown Server
Press `Ctrl+C` in server terminal
```
Caught signal 2, shutting down...
Database Dumped to dump.my_rdb
Server Shutdown Complete!
```

### 6. Verify Persistence
Restart server:
```bash
./my_redis_server
```

Should show: "Database loaded from dump.my_rdb"

---

## Threading Model

**Main Thread:**
- Runs `RedisServer::run()` in accept loop
- Spawns new thread per client
- Joins all threads on shutdown

**Client Handler Threads:**
- One per connected client
- Blocks on `recv()` waiting for commands
- Executes command and sends response
- Exits when client disconnects

**Persistence Thread:**
- Background daemon thread
- Sleeps 300 seconds (5 minutes)
- Calls `dump()` periodically
- Detached (doesn't block shutdown)

**Thread Safety:**
- `RedisDatabase::db_mutex` protects all stores
- `RedisServer::running` is `std::atomic<bool>` (lock-free)
- Signal handler uses global pointer (safe with atomics)

---

## Error Handling

**RESP Error Format:**
```
-ERR wrong number of arguments for 'command' command
-ERR syntax error
-ERR unknown command
-ERR key is not a list
-ERR index out of range
```

**Common Errors:**
| Error | Cause | Fix |
|-------|-------|-----|
| "Error Creating Server Socket" | Port already in use | Change port or kill process using port 6379 |
| "Error Binding Server Socket" | Permission denied | Use port > 1024 or run as admin |
| "Error Dumping Database" | File permissions | Ensure write access to current directory |
| Command returns `-ERR` | Wrong arguments | Check command syntax |

---

## Performance Characteristics

| Operation | Time Complexity | Notes |
|-----------|-----------------|-------|
| SET/GET | O(1) | Hash map lookup |
| DEL | O(1) | Hash map deletion |
| KEYS | O(n) | Iterates all keys |
| LPUSH/RPUSH | O(1) | Vector push_back |
| LPOP/RPOP | O(1) | Vector erase at end |
| LINDEX | O(n) | Linear search in vector |
| HSET/HGET | O(1) | Nested hash map lookup |
| EXPIRE/purge | O(n) | Scans expiry_map |
| DUMP | O(n) | Serializes all data |
| LOAD | O(n) | Deserializes all data |

---

## Limitations & Future Enhancements

**Current Limitations:**
- No persistence on every write (only periodic + shutdown)
- No password/authentication
- No replication or clustering
- No Lua scripting
- Limited command set (core operations only)
- No pub/sub support
- No transactions/MULTI/EXEC
- Simple text persistence (not optimized for speed)

**Possible Enhancements:**
1. AOF (Append-Only File) for immediate persistence
2. Redis Cluster protocol support
3. More data types (sets, sorted sets)
4. Pub/Sub messaging
5. Transactions with WATCH/MULTI/EXEC
6. Scripting with Lua
7. Performance optimization (memory pooling, better serialization)
8. Authentication and ACLs
9. Monitoring/stats commands
10. Binary protocol optimization

---

## Troubleshooting

**Issue: "Address already in use"**
```bash
# Find process using port 6379
lsof -i :6379
# Kill it
kill -9 <PID>
```

**Issue: Commands return empty responses**
- Check newline trimming is in place (should be after recent fix)
- Verify RedisCommandHandler is returning proper RESP format
- Use `nc -l 6379` to debug raw bytes received

**Issue: Data not persisting**
- Check `dump.my_rdb` exists after shutdown
- Verify read/write permissions in current directory
- Ensure shutdown signal is caught (Ctrl+C, not kill -9)

**Issue: Server crashes**
- Compile with debugging: `g++ -g ...`
- Run under gdb: `gdb ./my_redis_server`
- Check for memory leaks: `valgrind ./my_redis_server`

---

## Conclusion

This Redis implementation demonstrates:
✅ Multi-threaded TCP server architecture  
✅ Thread-safe data structures with mutex synchronization  
✅ RESP protocol compliance  
✅ Three data types (strings, lists, hashes)  
✅ Persistence and recovery  
✅ TTL/expiration support  
✅ Graceful shutdown with signal handling  
✅ Clean separation of concerns (server, database, command handler)

Perfect for learning Redis internals or as a foundation for further development!
