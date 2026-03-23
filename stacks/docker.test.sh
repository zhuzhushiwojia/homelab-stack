#!/bin/bash
# docker.test.sh - Docker integration tests
# Tests Docker daemon, container management, and basic operations

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/assert.sh"

# Test containers
TEST_CONTAINER="homelab_test_container"
TEST_IMAGE="alpine:3.19"
TEST_NETWORK="homelab_test_network"
TEST_VOLUME="homelab_test_volume"

# Setup - prepare test environment
setup() {
    log_info "Setting up Docker test environment..."
    
    # Clean up any existing test resources
    teardown
    
    # Pull test image
    log_info "Pulling test image: $TEST_IMAGE"
    docker pull "$TEST_IMAGE" > /dev/null 2>&1
    
    # Create test network
    log_info "Creating test network: $TEST_NETWORK"
    docker network create "$TEST_NETWORK" > /dev/null 2>&1 || true
    
    # Create test volume
    log_info "Creating test volume: $TEST_VOLUME"
    docker volume create "$TEST_VOLUME" > /dev/null 2>&1 || true
    
    log_success "Docker test environment ready"
}

# Teardown - clean up test resources
teardown() {
    log_info "Cleaning up Docker test environment..."
    
    # Remove test container
    cleanup_container "$TEST_CONTAINER"
    
    # Remove test network
    cleanup_network "$TEST_NETWORK"
    
    # Remove test volume
    cleanup_volume "$TEST_VOLUME"
    
    log_success "Docker test environment cleaned"
}

# Test: Docker daemon is running
test_docker_daemon_running() {
    log_test_start "docker_daemon_running"
    
    assert_command_exists "docker" "Docker command exists"
    assert_exit_code 0 "$(docker info > /dev/null 2>&1; echo $?)" "Docker daemon is running"
    
    log_test_end "pass"
    return 0
}

# Test: Docker version is available
test_docker_version() {
    log_test_start "docker_version"
    
    local version
    version=$(docker --version 2>&1)
    assert_contains "$version" "Docker" "Docker version string contains 'Docker'"
    
    log_test_end "pass"
    return 0
}

# Test: Docker Compose is available
test_docker_compose_available() {
    log_test_start "docker_compose_available"
    
    if is_docker_compose_available; then
        local version
        version=$(docker compose version 2>&1)
        assert_contains "$version" "Docker Compose" "Docker Compose version string"
        log_test_end "pass"
        return 0
    else
        log_test_end "skip" "Docker Compose not available"
        return 0
    fi
}

# Test: Pull image successfully
test_docker_pull_image() {
    log_test_start "docker_pull_image"
    
    local test_image="alpine:3.19"
    log_info "Pulling image: $test_image"
    
    assert_exit_code 0 "$(docker pull "$test_image" > /dev/null 2>&1; echo $?)" "Image pull successful"
    assert_docker_image_exists "$test_image" "Image exists locally"
    
    log_test_end "pass"
    return 0
}

# Test: Create and run container
test_docker_run_container() {
    log_test_start "docker_run_container"
    
    log_info "Creating test container: $TEST_CONTAINER"
    docker run -d --name "$TEST_CONTAINER" "$TEST_IMAGE" sleep 3600 > /dev/null 2>&1
    
    assert_docker_container_exists "$TEST_CONTAINER" "Container exists"
    assert_docker_container_running "$TEST_CONTAINER" "Container is running"
    
    log_test_end "pass"
    return 0
}

# Test: Container exec command
test_docker_exec() {
    log_test_start "docker_exec"
    
    # Ensure container is running
    if ! docker inspect -f '{{.State.Status}}' "$TEST_CONTAINER" 2>/dev/null | grep -q "running"; then
        docker run -d --name "$TEST_CONTAINER" "$TEST_IMAGE" sleep 3600 > /dev/null 2>&1
        wait_for_container "$TEST_CONTAINER" 10
    fi
    
    local output
    output=$(docker exec "$TEST_CONTAINER" echo "Hello from test" 2>&1)
    assert_equals "Hello from test" "$output" "Container exec output matches"
    
    log_test_end "pass"
    return 0
}

# Test: Container logs
test_docker_logs() {
    log_test_start "docker_logs"
    
    # Create container with output
    local log_container="homelab_test_logs"
    cleanup_container "$log_container"
    
    docker run -d --name "$log_container" "$TEST_IMAGE" sh -c "echo 'test log message'; sleep 3600" > /dev/null 2>&1
    sleep 1
    
    local logs
    logs=$(docker logs "$log_container" 2>&1)
    assert_contains "$logs" "test log message" "Container logs contain expected message"
    
    cleanup_container "$log_container"
    
    log_test_end "pass"
    return 0
}

# Test: Docker network create
test_docker_network_create() {
    log_test_start "docker_network_create"
    
    local test_net="homelab_test_net_create"
    cleanup_network "$test_net"
    
    log_info "Creating test network: $test_net"
    docker network create "$test_net" > /dev/null 2>&1
    
    assert_docker_network_exists "$test_net" "Network exists"
    
    cleanup_network "$test_net"
    
    log_test_end "pass"
    return 0
}

# Test: Docker volume create
test_docker_volume_create() {
    log_test_start "docker_volume_create"
    
    local test_vol="homelab_test_vol_create"
    cleanup_volume "$test_vol"
    
    log_info "Creating test volume: $test_vol"
    docker volume create "$test_vol" > /dev/null 2>&1
    
    assert_docker_volume_exists "$test_vol" "Volume exists"
    
    cleanup_volume "$test_vol"
    
    log_test_end "pass"
    return 0
}

# Test: Container with volume mount
test_docker_volume_mount() {
    log_test_start "docker_volume_mount"
    
    local vol_container="homelab_test_vol_mount"
    cleanup_container "$vol_container"
    
    log_info "Creating container with volume mount"
    docker run -d --name "$vol_container" -v "$TEST_VOLUME:/data" "$TEST_IMAGE" sleep 3600 > /dev/null 2>&1
    
    wait_for_container "$vol_container" 10
    
    # Write to volume
    docker exec "$vol_container" sh -c "echo 'test data' > /data/test.txt" 2>&1
    
    # Read from volume
    local output
    output=$(docker exec "$vol_container" cat /data/test.txt 2>&1)
    assert_equals "test data" "$output" "Volume mount read/write successful"
    
    cleanup_container "$vol_container"
    
    log_test_end "pass"
    return 0
}

# Test: Container port mapping
test_docker_port_mapping() {
    log_test_start "docker_port_mapping"
    
    local port_container="homelab_test_port"
    local host_port="18080"
    local container_port="80"
    cleanup_container "$port_container"
    
    log_info "Creating container with port mapping: $host_port->$container_port"
    docker run -d --name "$port_container" -p "$host_port:$container_port" "$TEST_IMAGE" sleep 3600 > /dev/null 2>&1
    
    wait_for_container "$port_container" 10
    
    # Verify port mapping
    local mapped_port
    mapped_port=$(get_container_port "$port_container" "$container_port")
    assert_equals "$host_port" "$mapped_port" "Port mapping is correct"
    
    cleanup_container "$port_container"
    
    log_test_end "pass"
    return 0
}

# Test: Container network connectivity
test_docker_network_connectivity() {
    log_test_start "docker_network_connectivity"
    
    local net_container1="homelab_test_net_c1"
    local net_container2="homelab_test_net_c2"
    cleanup_container "$net_container1"
    cleanup_container "$net_container2"
    
    # Create two containers on same network
    docker run -d --name "$net_container1" --network "$TEST_NETWORK" "$TEST_IMAGE" sleep 3600 > /dev/null 2>&1
    docker run -d --name "$net_container2" --network "$TEST_NETWORK" "$TEST_IMAGE" sleep 3600 > /dev/null 2>&1
    
    wait_for_container "$net_container1" 10
    wait_for_container "$net_container2" 10
    
    # Test connectivity (ping by container name)
    local ping_result
    ping_result=$(docker exec "$net_container1" ping -c 1 "$net_container2" 2>&1 || echo "ping_failed")
    
    # Note: Alpine may not have ping, so we check for either success or command not found
    if [[ "$ping_result" != *"ping_failed"* ]] || [[ "$ping_result" == *"command not found"* ]]; then
        log_info "Network connectivity test skipped (ping not available in alpine)"
        log_test_end "skip" "Ping not available"
    else
        assert_contains "$ping_result" "1 packets transmitted" "Container network connectivity"
        log_test_end "pass"
    fi
    
    cleanup_container "$net_container1"
    cleanup_container "$net_container2"
    
    return 0
}

# Test: Docker image cleanup
test_docker_image_cleanup() {
    log_test_start "docker_image_cleanup"
    
    # Create and remove a container
    local cleanup_container="homelab_test_cleanup"
    docker run --name "$cleanup_container" "$TEST_IMAGE" echo "test" > /dev/null 2>&1
    
    assert_docker_container_exists "$cleanup_container" "Container exists after run"
    
    # Remove container
    docker rm "$cleanup_container" > /dev/null 2>&1
    sleep 1
    
    assert_exit_code 1 "$(docker inspect "$cleanup_container" > /dev/null 2>&1; echo $?)" "Container removed successfully"
    
    log_test_end "pass"
    return 0
}

# Test: Docker system info
test_docker_system_info() {
    log_test_start "docker_system_info"
    
    local info
    info=$(docker info 2>&1)
    
    assert_contains "$info" "Containers:" "Docker info contains Containers"
    assert_contains "$info" "Images:" "Docker info contains Images"
    
    log_test_end "pass"
    return 0
}

# Test: Docker prune (dry run check)
test_docker_prune_available() {
    log_test_start "docker_prune_available"
    
    # Check if prune commands are available (don't actually prune)
    assert_command_exists "docker" "Docker command exists"
    
    # Verify prune help is available
    local prune_help
    prune_help=$(docker container prune --help 2>&1 || echo "")
    assert_contains "$prune_help" "prune" "Docker prune command available"
    
    log_test_end "pass"
    return 0
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # If run directly, execute all test_* functions
    for test_func in $(declare -F | awk '/^declare -f test_/ {print $3}'); do
        reset_assertions
        echo "Running $test_func..."
        $test_func || echo "FAILED: $test_func"
        echo ""
    done
    
    get_test_summary
fi
