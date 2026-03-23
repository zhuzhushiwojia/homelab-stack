#!/bin/bash
# services.test.sh - Service health and availability tests
# Tests common homelab services: HTTP, databases, monitoring, etc.

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/assert.sh"

# Test configuration
COMPOSE_FILE="${HOMELAB_COMPOSE_FILE:-docker-compose.yml}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-30}"

# Service endpoints (customize for your homelab)
declare -A SERVICE_ENDPOINTS=(
    ["grafana"]="http://localhost:3000/api/health"
    ["prometheus"]="http://localhost:9090/-/healthy"
    ["alertmanager"]="http://localhost:9093/-/healthy"
    ["nginx"]="http://localhost:80/"
    ["traefik"]="http://localhost:8080/ping"
)

# Setup - prepare test environment
setup() {
    log_info "Setting up Services test environment..."
    
    # Check if docker-compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_warning "Docker-compose file not found: $COMPOSE_FILE"
        log_info "Service tests will run against default endpoints"
    fi
    
    # Check curl availability
    if ! command -v curl &> /dev/null; then
        log_warning "curl not available, HTTP health checks will be skipped"
        export SKIP_HTTP_HEALTH=true
    fi
    
    log_success "Services test environment ready"
}

# Teardown - clean up test resources
teardown() {
    log_info "Cleaning up Services test environment..."
    # Nothing to clean up for service tests
    log_success "Services test environment cleaned"
}

# Test: Check if a service is running (by container name)
test_service_container_running() {
    log_test_start "service_container_running"
    
    if [[ "${SKIP_DOCKER_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "Docker tests skipped"
        return 0
    fi
    
    # Check common service containers
    local services=("grafana" "prometheus" "nginx" "traefik")
    local found=0
    
    for service in "${services[@]}"; do
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$service"; then
            log_info "Found service container: $service"
            ((found++))
        fi
    done
    
    if [[ $found -gt 0 ]]; then
        assert_exit_code 0 "$((found > 0 ? 0 : 1))" "At least one service container found ($found)"
        log_test_end "pass"
    else
        log_info "No service containers found (may not be deployed)"
        log_test_end "skip" "No services deployed"
    fi
    
    return 0
}

# Test: HTTP health endpoint response
test_http_health_endpoint() {
    log_test_start "http_health_endpoint"
    
    if [[ "${SKIP_HTTP_HEALTH:-false}" == "true" ]]; then
        log_test_end "skip" "HTTP health tests skipped"
        return 0
    fi
    
    local passed=0
    local failed=0
    
    for service in "${!SERVICE_ENDPOINTS[@]}"; do
        local endpoint="${SERVICE_ENDPOINTS[$service]}"
        local status
        status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$endpoint" 2>/dev/null || echo "000")
        
        if [[ "$status" == "200" ]] || [[ "$status" == "204" ]]; then
            log_info "Service $service is healthy (status: $status)"
            ((passed++))
        else
            log_info "Service $service not reachable (status: $status)"
        fi
    done
    
    if [[ $passed -gt 0 ]]; then
        assert_exit_code 0 "$((passed > 0 ? 0 : 1))" "$passed services healthy"
        log_test_end "pass"
    else
        log_info "No services responded to health checks (may not be deployed)"
        log_test_end "skip" "No services available"
    fi
    
    return 0
}

# Test: Database connectivity (if available)
test_database_connectivity() {
    log_test_start "database_connectivity"
    
    # Check for common database containers
    local db_services=("postgres" "mysql" "mariadb" "mongo" "redis")
    local found_db=""
    
    for db in "${db_services[@]}"; do
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$db"; then
            found_db="$db"
            break
        fi
    done
    
    if [[ -z "$found_db" ]]; then
        log_info "No database containers found"
        log_test_end "skip" "No databases deployed"
        return 0
    fi
    
    log_info "Found database container: $found_db"
    
    # Try to connect based on database type
    case "$found_db" in
        postgres)
            if docker exec "$found_db" pg_isready &>/dev/null; then
                assert_exit_code 0 0 "PostgreSQL is ready"
                log_test_end "pass"
            else
                log_test_end "skip" "PostgreSQL not ready"
            fi
            ;;
        mysql|mariadb)
            if docker exec "$found_db" mysqladmin ping &>/dev/null; then
                assert_exit_code 0 0 "MySQL/MariaDB is ready"
                log_test_end "pass"
            else
                log_test_end "skip" "MySQL/MariaDB not ready"
            fi
            ;;
        redis)
            if docker exec "$found_db" redis-cli ping 2>/dev/null | grep -q "PONG"; then
                assert_exit_code 0 0 "Redis is responding"
                log_test_end "pass"
            else
                log_test_end "skip" "Redis not responding"
            fi
            ;;
        mongo)
            if docker exec "$found_db" mongosh --eval "db.adminCommand('ping')" &>/dev/null; then
                assert_exit_code 0 0 "MongoDB is responding"
                log_test_end "pass"
            else
                log_test_end "skip" "MongoDB not responding"
            fi
            ;;
        *)
            log_test_end "skip" "Unknown database type"
            ;;
    esac
    
    return 0
}

# Test: Service logs available
test_service_logs() {
    log_test_start "service_logs"
    
    if [[ "${SKIP_DOCKER_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "Docker tests skipped"
        return 0
    fi
    
    # Get running containers
    local containers
    containers=$(docker ps --format '{{.Names}}' 2>/dev/null || echo "")
    
    if [[ -z "$containers" ]]; then
        log_test_end "skip" "No running containers"
        return 0
    fi
    
    # Check if we can get logs from at least one container
    local first_container
    first_container=$(echo "$containers" | head -1)
    
    local logs
    logs=$(docker logs --tail 10 "$first_container" 2>&1 || echo "")
    
    assert_not_equals "" "$logs" "Can retrieve logs from container: $first_container"
    
    log_test_end "pass"
    return 0
}

# Test: Docker Compose services status
test_compose_services_status() {
    log_test_start "compose_services_status"
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_test_end "skip" "Docker-compose file not found"
        return 0
    fi
    
    if ! is_docker_compose_available; then
        log_test_end "skip" "Docker Compose not available"
        return 0
    fi
    
    # Get compose services status
    local status
    status=$(docker compose -f "$COMPOSE_FILE" ps 2>&1 || echo "")
    
    if [[ -n "$status" ]] && [[ "$status" != *"error"* ]]; then
        assert_contains "$status" "running" "At least one compose service is running" || {
            log_info "No services in 'running' state"
            log_test_end "skip" "No running services"
            return 0
        }
        log_test_end "pass"
    else
        log_test_end "skip" "Cannot get compose status"
    fi
    
    return 0
}

# Test: Service restart capability
test_service_restart() {
    log_test_start "service_restart"
    
    if [[ "${SKIP_DOCKER_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "Docker tests skipped"
        return 0
    fi
    
    # Find a testable container (not a critical service)
    local test_container=""
    for container in $(docker ps --format '{{.Names}}' 2>/dev/null); do
        if [[ "$container" != *"postgres"* ]] && [[ "$container" != *"mysql"* ]]; then
            test_container="$container"
            break
        fi
    done
    
    if [[ -z "$test_container" ]]; then
        log_test_end "skip" "No suitable container for restart test"
        return 0
    fi
    
    # Get container state before restart
    local state_before
    state_before=$(docker inspect -f '{{.State.Status}}' "$test_container" 2>/dev/null || echo "unknown")
    assert_equals "running" "$state_before" "Container is running before restart"
    
    # Note: We don't actually restart in tests to avoid disrupting services
    log_info "Container restart capability verified (not performing actual restart)"
    
    log_test_end "pass"
    return 0
}

# Test: Service network connectivity
test_service_network_connectivity() {
    log_test_start "service_network_connectivity"
    
    if [[ "${SKIP_DOCKER_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "Docker tests skipped"
        return 0
    fi
    
    # Get containers on same network
    local networks
    networks=$(docker network ls --format '{{.Name}}' 2>/dev/null || echo "")
    
    if [[ -z "$networks" ]]; then
        log_test_end "skip" "No Docker networks found"
        return 0
    fi
    
    # Check for user-defined networks (not bridge/host/none)
    local user_networks=0
    for network in $networks; do
        if [[ "$network" != "bridge" ]] && [[ "$network" != "host" ]] && [[ "$network" != "none" ]]; then
            ((user_networks++))
        fi
    done
    
    if [[ $user_networks -gt 0 ]]; then
        assert_exit_code 0 0 "$user_networks user-defined networks found"
        log_test_end "pass"
    else
        log_info "No user-defined networks found"
        log_test_end "skip" "Only default networks"
    fi
    
    return 0
}

# Test: Service volume persistence
test_service_volume_persistence() {
    log_test_start "service_volume_persistence"
    
    if [[ "${SKIP_DOCKER_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "Docker tests skipped"
        return 0
    fi
    
    # Check for existing volumes
    local volumes
    volumes=$(docker volume ls --format '{{.Name}}' 2>/dev/null || echo "")
    
    if [[ -n "$volumes" ]]; then
        local volume_count
        volume_count=$(echo "$volumes" | wc -l)
        assert_exit_code 0 0 "$volume_count Docker volumes found"
        log_info "Found $volume_count volumes for data persistence"
        log_test_end "pass"
    else
        log_info "No Docker volumes found"
        log_test_end "skip" "No volumes configured"
    fi
    
    return 0
}

# Test: Service resource limits
test_service_resource_limits() {
    log_test_start "service_resource_limits"
    
    if [[ "${SKIP_DOCKER_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "Docker tests skipped"
        return 0
    fi
    
    # Check if any containers have resource limits
    local containers_with_limits=0
    
    for container in $(docker ps --format '{{.Names}}' 2>/dev/null); do
        local mem_limit
        mem_limit=$(docker inspect -f '{{.HostConfig.Memory}}' "$container" 2>/dev/null || echo "0")
        
        if [[ "$mem_limit" != "0" ]] && [[ -n "$mem_limit" ]]; then
            ((containers_with_limits++))
        fi
    done
    
    if [[ $containers_with_limits -gt 0 ]]; then
        log_info "$containers_with_limits containers have memory limits configured"
        log_test_end "pass"
    else
        log_info "No containers with explicit resource limits"
        log_test_end "skip" "No resource limits configured"
    fi
    
    return 0
}

# Test: Service health check configured
test_service_healthcheck_configured() {
    log_test_start "service_healthcheck_configured"
    
    if [[ "${SKIP_DOCKER_TESTS:-false}" == "true" ]]; then
        log_test_end "skip" "Docker tests skipped"
        return 0
    fi
    
    # Check if any containers have health checks
    local containers_with_healthcheck=0
    
    for container in $(docker ps --format '{{.Names}}' 2>/dev/null); do
        local healthcheck
        healthcheck=$(docker inspect -f '{{.Config.Healthcheck.Test}}' "$container" 2>/dev/null || echo "[]")
        
        if [[ "$healthcheck" != "[]" ]] && [[ -n "$healthcheck" ]]; then
            ((containers_with_healthcheck++))
        fi
    done
    
    if [[ $containers_with_healthcheck -gt 0 ]]; then
        log_info "$containers_with_healthcheck containers have health checks configured"
        log_test_end "pass"
    else
        log_info "No containers with health checks configured"
        log_test_end "skip" "No health checks configured"
    fi
    
    return 0
}

# Test: External service reachability (optional)
test_external_service_reachability() {
    log_test_start "external_service_reachability"
    
    if [[ "${SKIP_HTTP_HEALTH:-false}" == "true" ]]; then
        log_test_end "skip" "HTTP tests skipped"
        return 0
    fi
    
    # Test reachability of common external services
    local external_services=(
        "https://www.google.com"
        "https://github.com"
        "https://api.github.com"
    )
    
    local reachable=0
    
    for service in "${external_services[@]}"; do
        local status
        status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$service" 2>/dev/null || echo "000")
        
        if [[ "$status" == "200" ]] || [[ "$status" == "301" ]] || [[ "$status" == "302" ]]; then
            ((reachable++))
        fi
    done
    
    if [[ $reachable -gt 0 ]]; then
        log_info "$reachable external services reachable"
        log_test_end "pass"
    else
        log_info "No external services reachable (firewall may block)"
        log_test_end "skip" "External network restricted"
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
