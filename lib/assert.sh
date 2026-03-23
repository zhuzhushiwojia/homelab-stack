#!/bin/bash
# assert.sh - Assertion library for integration tests
# Provides common assertion functions for test validation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Assertion counter
ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0

# assert_equals - Check if two values are equal
# Usage: assert_equals <expected> <actual> [message]
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo -e "  Expected: ${YELLOW}$expected${NC}"
        echo -e "  Actual:   ${RED}$actual${NC}"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_not_equals - Check if two values are not equal
# Usage: assert_not_equals <unexpected> <actual> [message]
assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"
    
    if [[ "$unexpected" != "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message (got unexpected value: $actual)"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_contains - Check if string contains substring
# Usage: assert_contains <string> <substring> [message]
assert_contains() {
    local string="$1"
    local substring="$2"
    local message="${3:-String should contain substring}"
    
    if [[ "$string" == *"$substring"* ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo -e "  Expected to contain: ${YELLOW}$substring${NC}"
        echo -e "  In string: ${RED}$string${NC}"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_not_contains - Check if string does not contain substring
# Usage: assert_not_contains <string> <substring> [message]
assert_not_contains() {
    local string="$1"
    local substring="$2"
    local message="${3:-String should not contain substring}"
    
    if [[ "$string" != *"$substring"* ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message (found unexpected: $substring)"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_file_exists - Check if file exists
# Usage: assert_file_exists <filepath> [message]
assert_file_exists() {
    local filepath="$1"
    local message="${2:-File should exist: $filepath}"
    
    if [[ -f "$filepath" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_dir_exists - Check if directory exists
# Usage: assert_dir_exists <dirpath> [message]
assert_dir_exists() {
    local dirpath="$1"
    local message="${2:-Directory should exist: $dirpath}"
    
    if [[ -d "$dirpath" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_file_not_exists - Check if file does not exist
# Usage: assert_file_not_exists <filepath> [message]
assert_file_not_exists() {
    local filepath="$1"
    local message="${2:-File should not exist: $filepath}"
    
    if [[ ! -f "$filepath" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message (file exists)"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_exit_code - Check command exit code
# Usage: assert_exit_code <expected> <actual> [message]
assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code should be $expected}"
    
    if [[ "$expected" -eq "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo -e "  Expected: ${YELLOW}$expected${NC}"
        echo -e "  Actual:   ${RED}$actual${NC}"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_command_exists - Check if command is available
# Usage: assert_command_exists <command> [message]
assert_command_exists() {
    local cmd="$1"
    local message="${2:-Command should exist: $cmd}"
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_http_status - Check HTTP response status code
# Usage: assert_http_status <expected> <url> [message]
assert_http_status() {
    local expected="$1"
    local url="$2"
    local message="${3:-HTTP status should be $expected}"
    
    local actual
    actual=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo -e "  Expected: ${YELLOW}$expected${NC}"
        echo -e "  Actual:   ${RED}$actual${NC}"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_port_open - Check if port is open
# Usage: assert_port_open <port> [host] [message]
assert_port_open() {
    local port="$1"
    local host="${2:-localhost}"
    local message="${3:-Port $port should be open on $host}"
    
    if nc -z "$host" "$port" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_port_closed - Check if port is closed
# Usage: assert_port_closed <port> [host] [message]
assert_port_closed() {
    local port="$1"
    local host="${2:-localhost}"
    local message="${3:-Port $port should be closed on $host}"
    
    if ! nc -z "$host" "$port" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message (port is open)"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_process_running - Check if process is running
# Usage: assert_process_running <process_name> [message]
assert_process_running() {
    local process="$1"
    local message="${2:-Process should be running: $process}"
    
    if pgrep -x "$process" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_docker_container_running - Check if Docker container is running
# Usage: assert_docker_container_running <container_name> [message]
assert_docker_container_running() {
    local container="$1"
    local message="${2:-Docker container should be running: $container}"
    
    local status
    status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "not_found")
    
    if [[ "$status" == "running" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message (status: $status)"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_docker_container_exists - Check if Docker container exists
# Usage: assert_docker_container_exists <container_name> [message]
assert_docker_container_exists() {
    local container="$1"
    local message="${2:-Docker container should exist: $container}"
    
    if docker inspect "$container" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_docker_image_exists - Check if Docker image exists
# Usage: assert_docker_image_exists <image_name> [message]
assert_docker_image_exists() {
    local image="$1"
    local message="${2:-Docker image should exist: $image}"
    
    if docker image inspect "$image" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_docker_volume_exists - Check if Docker volume exists
# Usage: assert_docker_volume_exists <volume_name> [message]
assert_docker_volume_exists() {
    local volume="$1"
    local message="${2:-Docker volume should exist: $volume}"
    
    if docker volume inspect "$volume" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_docker_network_exists - Check if Docker network exists
# Usage: assert_docker_network_exists <network_name> [message]
assert_docker_network_exists() {
    local network="$1"
    local message="${2:-Docker network should exist: $network}"
    
    if docker network inspect "$network" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_service_health - Check if service health endpoint responds
# Usage: assert_service_health <url> [message]
assert_service_health() {
    local url="$1"
    local message="${2:-Service health check should pass: $url}"
    
    local response
    response=$(curl -s -f "$url" 2>/dev/null || echo "")
    
    if [[ -n "$response" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_log_contains - Check if log file contains pattern
# Usage: assert_log_contains <logfile> <pattern> [message]
assert_log_contains() {
    local logfile="$1"
    local pattern="$2"
    local message="${3:-Log should contain: $pattern}"
    
    if grep -q "$pattern" "$logfile" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# assert_json_value - Check JSON value using jq
# Usage: assert_json_value <json_file> <jq_query> <expected> [message]
assert_json_value() {
    local json_file="$1"
    local jq_query="$2"
    local expected="$3"
    local message="${4:-JSON value should match}"
    
    local actual
    actual=$(jq -r "$jq_query" "$json_file" 2>/dev/null || echo "")
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((ASSERTIONS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        echo -e "  Expected: ${YELLOW}$expected${NC}"
        echo -e "  Actual:   ${RED}$actual${NC}"
        ((ASSERTIONS_FAILED++))
        return 1
    fi
}

# get_assertions_passed - Get count of passed assertions
get_assertions_passed() {
    echo "$ASSERTIONS_PASSED"
}

# get_assertions_failed - Get count of failed assertions
get_assertions_failed() {
    echo "$ASSERTIONS_FAILED"
}

# reset_assertions - Reset assertion counters
reset_assertions() {
    ASSERTIONS_PASSED=0
    ASSERTIONS_FAILED=0
}

# Export functions
export -f assert_equals
export -f assert_not_equals
export -f assert_contains
export -f assert_not_contains
export -f assert_file_exists
export -f assert_dir_exists
export -f assert_file_not_exists
export -f assert_exit_code
export -f assert_command_exists
export -f assert_http_status
export -f assert_port_open
export -f assert_port_closed
export -f assert_process_running
export -f assert_docker_container_running
export -f assert_docker_container_exists
export -f assert_docker_image_exists
export -f assert_docker_volume_exists
export -f assert_docker_network_exists
export -f assert_service_health
export -f assert_log_contains
export -f assert_json_value
export -f get_assertions_passed
export -f get_assertions_failed
export -f reset_assertions
