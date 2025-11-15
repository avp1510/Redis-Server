CXX = g++
# Changed -2 to -O2 (Optimization Level 2), which is common for builds.
CXXFLAGS = -std=c++17 -Wall -pthread -MMD -MP -O2

SRC_DIR = src
BUILD_DIR = build

# Finds all .cpp files in the src directory
SRCS := $(wildcard $(SRC_DIR)/*.cpp)
# Converts src/file.cpp to build/file.o
OBJS := $(patsubst $(SRC_DIR)/%.cpp, $(BUILD_DIR)/%.o, $(SRCS))

TARGET = my_redis_server

.PHONY: all clean rebuild

# Default target
all: $(TARGET)

# Rule to create the build directory (dependency for object files)
$(BUILD_DIR):
# NOTE: The line below must be indented with a literal TAB character.
	mkdir -p $(BUILD_DIR)

# Pattern rule for compiling source files into object files.
# Fix: The prerequisite pattern was changed from '%(SRC_DIR)/%.cpp' to '$(SRC_DIR)/%.cpp'.
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp | $(BUILD_DIR)
# NOTE: The line below must be indented with a literal TAB character.
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Rule for linking all object files into the final executable
$(TARGET): $(OBJS)
# NOTE: The line below must be indented with a literal TAB character.
	$(CXX) $(CXXFLAGS) $(OBJS) -o $(TARGET)

# Cleanup rule
clean:
# NOTE: The line below must be indented with a literal TAB character.
	rm -rf $(BUILD_DIR) $(TARGET)

# Rebuild and run rule
rebuild: clean all
# NOTE: The line below must be indented with a literal TAB character.
	./$(TARGET)