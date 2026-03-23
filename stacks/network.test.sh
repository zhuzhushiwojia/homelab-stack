#!/bin/bash
# network.test.sh - Network integration tests
# Tests network connectivity, DNS, ports, and HTTP endpoints

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/assert.sh"

# Test configuration
TEST_HTTP_PORT="18888"
TEST_HTTP_HOST="localhost"

# Setup - prepare test environment
setup() {
    log_info "Setting up Network test environment..."
    
    # Check network tools availability
    if ! command -v curl &> /dev/null; then
        log_warning "curl not available, some HTTP tests will be skipped"
        export SKIP_HTTP_TESTS=true
    fi
    
    if ! command -v nc &> /dev/null; then
        log_warning "netcat not available, port tests will be limited"
        export SKIP_PORT_TESTS=true
    fi
    
    log_success "Network test environment ready"
}

# Teardown - clean up test resources
teardown() {
    log_info "Cleaning up Network test environment..."
    # Nothing to clean up for network tests
    log_success "Network test environment cleaned"
}

# Test: Localhost is reachable
test_localhost_reachable() {
    log_test_start "localhost_reachable"
    
    # Try to ping localhost (may not have ping, so use alternative)
    if command -v ping &> /dev/null; then
        local ping_result
        ping_result=$(ping -c 1 localhost 2>&1 || echo "ping_failed")
        assert_contains "$ping_result" "1 packets transmitted" "Localhost ping successful"
    else
        # Alternative: try to connect to a local port
        log_info "Ping not available, skipping localhost ping test"
        log_test_end "skip" "Ping not available"
        return 0
    fi
    
    log_test_end "pass"
    return 0
}

# Test: DNS resolution works
test_dns_resolution() {
    log_test_start "dns_resolution"
    
    # Test DNS resolution for common domains
    if command -v host &> /dev/null; then
        local dns_result
        dns_result=$(host google.com 2>&1 || echo "dns_failed")
        assert_not_contains "$dns_result" "NXDOMAIN" "DNS resolution works for google.com"
    elif command -v nslookup &> /dev/null; then
        local dns_result
        dns_result=$(nslookup google.com 2>&1 || echo "dns_failed")
        assert_not_contains "$dns_result" "** server can't find" "DNS resolution works"
    elif command -v getent &> /dev/null; then
        local dns_result
        dns_result=$(getent hosts google.com 2>&1 || echo "dns_failed")
        assert_not_equals "" "$dns_result" "DNS resolution via getent works"
    else
        log_info "No DNS tools available, skipping DNS test"
        log_test_end "skip" "No DNS tools available"
        return 0
    fi
    
    log_test_end "pass"
    return 0
}

# Test: Loopback interface exists
test_loopback_interface() {
    log_test_start "loopback_interface"
    
    # Check for loopback interface
    if command -v ip &> /dev/null; then
        local iface_info
        iface_info=$(ip addr show lo 2>&1 || echo "not_found")
        assert_contains "$iface_info" "lo" "Loopback interface exists"
        assert_contains "$iface_info" "127.0.0.1" "Loopback has 127.0.0.1"
    elif command -v ifconfig &> /dev/null; then
        local iface_info
        iface_info=$(ifconfig lo 2>&1 || echo "not_found")
        assert_contains "$iface_info" "lo" "Loopback interface exists"
    else
        # Try reading /proc
        if [[ -f /proc/net/dev ]]; then
            assert_contains "$(cat /proc/net/dev)" "lo:" "Loopback interface in /proc/net/dev"
        else
            log_test_end "skip" "Cannot verify loopback interface"
            return 0
        fi
    fi
    
    log_test_end "pass"
    return 0
}

# Test: Port can be opened (using Python or netcat)
test_port_listen() {
    log_test_start "port_listen"
    
    if [[ "${SKIP_PORT_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "Port tests skipped (netcat not available)"
        return 0
    fi
    
    # Start a simple listener in background
    local cleanup=false
    
    if command -v python3 &> /dev/null; then
        python3 -c "import socket; s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(('127.0.0.1', $TEST_HTTP_PORT)); s.listen(1); print('listening'); import time; time.sleep(10)" &
        cleanup=true
    elif command -v nc &> /dev/null; then
        nc -l -p "$TEST_HTTP_PORT" &
        cleanup=true
    else
        log_test_end "skip" "No tool available to open port"
        return 0
    fi
    
    local listener_pid=$!
    sleep 2
    
    # Test port is open
    assert_port_open "$TEST_HTTP_PORT" "localhost" "Test port is open"
    
    # Cleanup
    if [[ "$cleanup" == true ]]; then
        kill $listener_pid 2>/dev/null || true
        wait $listener_pid 2>/dev/null || true
    fi
    
    log_test_end "pass"
    return 0
}

# Test: HTTP GET request (using curl)
test_http_get() {
    log_test_start "http_get"
    
    if [[ "${SKIP_HTTP_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "HTTP tests skipped (curl not available)"
        return 0
    fi
    
    # Test against a public endpoint (httpbin or similar)
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" https://httpbin.org/status/200 2>/dev/null || echo "000")
    
    if [[ "$response" == "200" ]]; then
        assert_equals "200" "$response" "HTTP GET to httpbin.org returns 200"
        log_test_end "pass"
    else
        log_info "External HTTP test failed (network may be restricted)"
        log_test_end "skip" "External network not available"
    fi
    
    return 0
}

# Test: HTTP timeout handling
test_http_timeout() {
    log_test_start "http_timeout"
    
    if [[ "${SKIP_HTTP_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "HTTP tests skipped (curl not available)"
        return 0
    fi
    
    # Test that curl handles timeout properly
    local start_time=$(date +%s)
    local response
    response=$(curl -s --connect-timeout 2 http://10.255.255.1/nonexistent 2>&1 || echo "timeout_expected")
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Should timeout within reasonable time (not hang forever)
    assert_exit_code 0 "$((duration < 10 ? 0 : 1))" "HTTP request times out within 10 seconds (took ${duration}s)"
    
    log_test_end "pass"
    return 0
}

# Test: SSL/TLS connectivity
test_ssl_connectivity() {
    log_test_start "ssl_connectivity"
    
    if [[ "${SKIP_HTTP_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "HTTP tests skipped (curl not available)"
        return 0
    fi
    
    # Test HTTPS connection
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" https://httpbin.org/get 2>/dev/null || echo "000")
    
    if [[ "$response" == "200" ]]; then
        assert_equals "200" "$response" "HTTPS connection successful"
        log_test_end "pass"
    else
        log_info "External HTTPS test failed (network may be restricted)"
        log_test_end "skip" "External network not available"
    fi
    
    return 0
}

# Test: Network interface info
test_network_interfaces() {
    log_test_start "network_interfaces"
    
    # Get network interfaces
    local interfaces=""
    if command -v ip &> /dev/null; then
        interfaces=$(ip -o link show | awk -F': ' '{print $2}')
    elif command -v ifconfig &> /dev/null; then
        interfaces=$(ifconfig -a | grep -E '^[a-z]' | awk '{print $1}' | tr -d ':')
    elif [[ -d /sys/class/net ]]; then
        interfaces=$(ls /sys/class/net)
    fi
    
    assert_not_equals "" "$interfaces" "Network interfaces found"
    assert_contains "$interfaces" "lo" "Loopback interface present"
    
    log_test_end "pass"
    return 0
}

# Test: Routing table exists
test_routing_table() {
    log_test_start "routing_table"
    
    local routes=""
    if command -v ip &> /dev/null; then
        routes=$(ip route show 2>&1 || echo "")
    elif command -v route &> /dev/null; then
        routes=$(route -n 2>&1 || echo "")
    elif [[ -f /proc/net/route ]]; then
        routes=$(cat /proc/net/route 2>&1 || echo "")
    fi
    
    assert_not_equals "" "$routes" "Routing table exists"
    
    log_test_end "pass"
    return 0
}

# Test: /etc/hosts file exists and is readable
test_etc_hosts() {
    log_test_start "etc_hosts"
    
    assert_file_exists "/etc/hosts" "/etc/hosts file exists"
    assert_contains "$(cat /etc/hosts)" "localhost" "/etc/hosts contains localhost"
    
    log_test_end "pass"
    return 0
}

# Test: /etc/resolv.conf exists and has DNS servers
test_etc_resolv_conf() {
    log_test_start "etc_resolv_conf"
    
    assert_file_exists "/etc/resolv.conf" "/etc/resolv.conf file exists"
    
    local resolv_content
    resolv_content=$(cat /etc/resolv.conf 2>&1)
    assert_contains "$resolv_content" "nameserver" "/etc/resolv.conf contains nameserver entries"
    
    log_test_end "pass"
    return 0
}

# Test: Socket statistics
test_socket_statistics() {
    log_test_start "socket_statistics"
    
    if command -v ss &> /dev/null; then
        local sock_info
        sock_info=$(ss -tuln 2>&1 || echo "")
        assert_not_equals "" "$sock_info" "Socket statistics available"
    elif command -v netstat &> /dev/null; then
        local sock_info
        sock_info=$(netstat -tuln 2>&1 || echo "")
        assert_not_equals "" "$sock_info" "Netstat output available"
    else
        log_info "No socket statistics tools available"
        log_test_end "skip" "No ss or netstat available"
        return 0
    fi
    
    log_test_end "pass"
    return 0
}

# Test: TCP connection to common port (if available)
test_tcp_connection() {
    log_test_start "tcp_connection"
    
    if [[ "${SKIP_PORT_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "Port tests skipped (netcat not available)"
        return 0
    fi
    
    # Try to connect to a well-known public service (with timeout)
    if command -v nc &> /dev/null; then
        # Test connection to a public DNS server (may be blocked by firewall)
        local result
        result=$(nc -z -w 2 8.8.8.8 53 2>&1 || echo "connection_failed")
        
        if [[ "$result" != *"connection_failed"* ]]; then
            log_info "External TCP connection successful"
            log_test_end "pass"
        else
            log_info "External TCP connection failed (firewall may block)"
            log_test_end "skip" "External network restricted"
        fi
    else
        log_test_end "skip" "Netcat not available"
    fi
    
    return 0
}

# Test: Network namespace (if in container)
test_network_namespace() {
    log_test_start "network_namespace"
    
    # Check if we're in a container (simplified check)
    if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        log_info "Running in container, network namespace test passed"
        log_test_end "pass"
    else
        log_info "Not running in container, skipping namespace test"
        log_test_end "skip" "Not in container"
    fi
    
    return 0
}

# Test: IPv6 availability (optional)
test_ipv6_availability() {
    log_test_start "ipv6_availability"
    
    local has_ipv6=false
    
    if command -v ip &> /dev/null; then
        if ip -6 addr show lo 2>/dev/null | grep -q "::1"; then
            has_ipv6=true
        fi
    elif [[ -f /proc/net/if_inet6 ]]; then
        if [[ -s /proc/net/if_inet6 ]]; then
            has_ipv6=true
        fi
    fi
    
    if [[ "$has_ipv6" == true ]]; then
        log_info "IPv6 is available"
        log_test_end "pass"
    else
        log_info "IPv6 not available (optional)"
        log_test_end "skip" "IPv6 not configured"
    fi
    
    return 0
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    for test_func in $(declare -F | awk '/^declare -f test_/ {print $3}'); do
        reset_assertions
        echo "Running $test_func..."
        $test_func || echo "FAILED: $test_func"
        echo ""
    done
    
    get_test_summary
fi
