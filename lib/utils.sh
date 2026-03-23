#!/bin/bash
# utils.sh - Utility functions for integration tests
# Provides common helper functions for test setup and teardown

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Current test tracking
CURRENT_TEST=""
CURRENT_SUITE=""
TEST_START_TIME=0

# log_info - Print info message
# Usage: log_info <message>
log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

# log_success - Print success message
# Usage: log_success <message>
log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

# log_error - Print error message
# Usage: log_error <message>
log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

# log_warning - Print warning message
# Usage: log_warning <message>
log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

# log_section - Print section header
# Usage: log_section <title>
log_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $*${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# log_test_start - Log test start
# Usage: log_test_start <test_name>
log_test_start() {
    CURRENT_TEST="$1"
    TEST_START_TIME=$(date +%s)
    echo -e "\n${BLUE}▶${NC} Running: $CURRENT_TEST"
}

# log_test_end - Log test end with duration
# Usage: log_test_end <status> [message]
log_test_end() {
    local status="$1"
    local message="${2:-}"
    local end_time=$(date +%s)
    local duration=$((end_time - TEST_START_TIME))
    
    ((TESTS_RUN++))
    
    if [[ "$status" == "pass" ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}✓${NC} PASSED (${duration}s)"
    elif [[ "$status" == "fail" ]]; then
        ((TESTS_FAILED++))
        echo -e "${RED}✗${NC} FAILED (${duration}s) ${message}"
    elif [[ "$status" == "skip" ]]; then
        ((TESTS_SKIPPED++))
        echo -e "${YELLOW}⊘${NC} SKIPPED (${duration}s) ${message}"
    fi
}

# test_suite_start - Mark start of test suite
# Usage: test_suite_start <suite_name>
test_suite_start() {
    CURRENT_SUITE="$1"
    log_section "Test Suite: $CURRENT_SUITE"
    reset_assertions
}

# test_suite_end - Mark end of test suite and print summary
# Usage: test_suite_end
test_suite_end() {
    local passed=$(get_assertions_passed)
    local failed=$(get_assertions_failed)
    
    echo ""
    log_section "Suite Summary: $CURRENT_SUITE"
    echo -e "  Assertions Passed: ${GREEN}$passed${NC}"
    echo -e "  Assertions Failed: ${RED}$failed${NC}"
    echo ""
}

# wait_for_port - Wait for port to become available
# Usage: wait_for_port <port> [host] [timeout_seconds]
wait_for_port() {
    local port="$1"
    local host="${2:-localhost}"
    local timeout="${3:-30}"
    
    log_info "Waiting for port $port on $host (timeout: ${timeout}s)..."
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            log_success "Port $port is open"
            return 0
        fi
        sleep 1
        ((elapsed++))
    done
    
    log_error "Timeout waiting for port $port"
    return 1
}

# wait_for_http - Wait for HTTP endpoint to respond
# Usage: wait_for_http <url> [timeout_seconds] [expected_status]
wait_for_http() {
    local url="$1"
    local timeout="${2:-30}"
    local expected_status="${3:-200}"
    
    log_info "Waiting for HTTP endpoint: $url (timeout: ${timeout}s)..."
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local status
        status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
        
        if [[ "$status" == "$expected_status" ]]; then
            log_success "HTTP endpoint responding with status $status"
            return 0
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    log_error "Timeout waiting for HTTP endpoint (got status: $status)"
    return 1
}

# wait_for_container - Wait for Docker container to be running
# Usage: wait_for_container <container_name> [timeout_seconds]
wait_for_container() {
    local container="$1"
    local timeout="${2:-30}"
    
    log_info "Waiting for container $container to be running (timeout: ${timeout}s)..."
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local status
        status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "not_found")
        
        if [[ "$status" == "running" ]]; then
            log_success "Container $container is running"
            return 0
        elif [[ "$status" == "exited" || "$status" == "dead" ]]; then
            log_error "Container $container is $status"
            return 1
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    log_error "Timeout waiting for container $container"
    return 1
}

# wait_for_service - Wait for service to be healthy
# Usage: wait_for_service <health_url> [timeout_seconds]
wait_for_service() {
    local health_url="$1"
    local timeout="${2:-60}"
    
    log_info "Waiting for service health: $health_url (timeout: ${timeout}s)..."
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if curl -s -f "$health_url" &> /dev/null; then
            log_success "Service is healthy"
            return 0
        fi
        
        sleep 2
        ((elapsed+=2))
    done
    
    log_error "Timeout waiting for service health"
    return 1
}

# docker_compose_up - Start docker-compose services
# Usage: docker_compose_up [compose_file] [options]
docker_compose_up() {
    local compose_file="${1:-docker-compose.yml}"
    shift || true
    
    log_info "Starting docker-compose services from $compose_file..."
    
    if docker compose -f "$compose_file" up -d "$@"; then
        log_success "Docker-compose services started"
        return 0
    else
        log_error "Failed to start docker-compose services"
        return 1
    fi
}

# docker_compose_down - Stop docker-compose services
# Usage: docker_compose_down [compose_file] [options]
docker_compose_down() {
    local compose_file="${1:-docker-compose.yml}"
    shift || true
    
    log_info "Stopping docker-compose services from $compose_file..."
    
    if docker compose -f "$compose_file" down "$@"; then
        log_success "Docker-compose services stopped"
        return 0
    else
        log_error "Failed to stop docker-compose services"
        return 1
    fi
}

# docker_compose_logs - Get docker-compose logs
# Usage: docker_compose_logs [compose_file] [service]
docker_compose_logs() {
    local compose_file="${1:-docker-compose.yml}"
    local service="${2:-}"
    
    if [[ -n "$service" ]]; then
        docker compose -f "$compose_file" logs "$service"
    else
        docker compose -f "$compose_file" logs
    fi
}

# cleanup_container - Remove container if exists
# Usage: cleanup_container <container_name>
cleanup_container() {
    local container="$1"
    
    if docker inspect "$container" &> /dev/null; then
        log_info "Cleaning up container: $container"
        docker rm -f "$container" &> /dev/null || true
    fi
}

# cleanup_volume - Remove volume if exists
# Usage: cleanup_volume <volume_name>
cleanup_volume() {
    local volume="$1"
    
    if docker volume inspect "$volume" &> /dev/null; then
        log_info "Cleaning up volume: $volume"
        docker volume rm -f "$volume" &> /dev/null || true
    fi
}

# cleanup_network - Remove network if exists
# Usage: cleanup_network <network_name>
cleanup_network() {
    local network="$1"
    
    if docker network inspect "$network" &> /dev/null; then
        log_info "Cleaning up network: $network"
        docker network rm -f "$network" &> /dev/null || true
    fi
}

# get_container_ip - Get container IP address
# Usage: get_container_ip <container_name>
get_container_ip() {
    local container="$1"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null
}

# get_container_port - Get mapped port for container
# Usage: get_container_port <container_name> <container_port>
get_container_port() {
    local container="$1"
    local container_port="$2"
    docker inspect -f "{{(index (index .NetworkSettings.Ports \"$container_port/tcp\") 0).HostPort}}" "$container" 2>/dev/null
}

# exec_in_container - Execute command in container
# Usage: exec_in_container <container_name> <command>
exec_in_container() {
    local container="$1"
    shift
    docker exec "$container" "$@"
}

# copy_to_container - Copy file to container
# Usage: copy_to_container <source> <container>:<dest>
copy_to_container() {
    local source="$1"
    local dest="$2"
    docker cp "$source" "$dest"
}

# copy_from_container - Copy file from container
# Usage: copy_from_container <container>:<source> <dest>
copy_from_container() {
    local source="$1"
    local dest="$2"
    docker cp "$source" "$dest"
}

# create_temp_dir - Create temporary directory
# Usage: create_temp_dir [prefix]
create_temp_dir() {
    local prefix="${1:-homelab_test}"
    mktemp -d -t "${prefix}_XXXXXX"
}

# create_temp_file - Create temporary file
# Usage: create_temp_file [prefix] [extension]
create_temp_file() {
    local prefix="${1:-homelab_test}"
    local extension="${2:-.tmp}"
    mktemp -t "${prefix}_XXXXXX${extension}"
}

# is_command_available - Check if command is available
# Usage: is_command_available <command>
is_command_available() {
    command -v "$1" &> /dev/null
}

# is_docker_available - Check if Docker is available
# Usage: is_docker_available
is_docker_available() {
    is_command_available docker && docker info &> /dev/null
}

# is_docker_compose_available - Check if docker-compose is available
# Usage: is_docker_compose_available
is_docker_compose_available() {
    is_command_available docker && docker compose version &> /dev/null
}

# get_test_summary - Get test execution summary
# Usage: get_test_summary
get_test_summary() {
    echo ""
    log_section "Test Summary"
    echo -e "  Total Run:     ${TESTS_RUN}"
    echo -e "  Passed:        ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "  Failed:        ${RED}${TESTS_FAILED}${NC}"
    echo -e "  Skipped:       ${YELLOW}${TESTS_SKIPPED}${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# reset_test_counters - Reset test counters
# Usage: reset_test_counters
reset_test_counters() {
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0
}

# Export functions
export -f log_info
export -f log_success
export -f log_error
export -f log_warning
export -f log_section
export -f log_test_start
export -f log_test_end
export -f test_suite_start
export -f test_suite_end
export -f wait_for_port
export -f wait_for_http
export -f wait_for_container
export -f wait_for_service
export -f docker_compose_up
export -f docker_compose_down
export -f docker_compose_logs
export -f cleanup_container
export -f cleanup_volume
export -f cleanup_network
export -f get_container_ip
export -f get_container_port
export -f exec_in_container
export -f copy_to_container
export -f copy_from_container
export -f create_temp_dir
export -f create_temp_file
export -f is_command_available
export -f is_docker_available
export -f is_docker_compose_available
export -f get_test_summary
export -f reset_test_counters
