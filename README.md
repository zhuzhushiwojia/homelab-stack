# Homelab Integration Testing Framework

A comprehensive Bash-based integration testing framework for Homelab deployments. This framework provides automated testing for Docker containers, network connectivity, and service health checks.

## 🎯 Features

- **Pure Bash** - No external dependencies beyond standard Unix tools
- **Docker Testing** - Container lifecycle, networking, volumes, and resource management
- **Network Testing** - DNS, HTTP, TCP connectivity, and interface verification
- **Service Health** - Health endpoint checks, database connectivity, and compose status
- **Rich Assertions** - 20+ assertion functions for comprehensive validation
- **Color Output** - Clear pass/fail/skip indicators with timing information
- **Modular Design** - Easy to extend with custom test suites

## 📁 Project Structure

```
homelab-integration-tests/
├── tests/
│   └── run-tests.sh          # Main test runner
├── stacks/
│   ├── docker.test.sh        # Docker daemon & container tests
│   ├── network.test.sh       # Network connectivity tests
│   └── services.test.sh      # Service health & availability tests
├── lib/
│   ├── assert.sh             # Assertion library
│   └── utils.sh              # Utility functions
├── artifacts/                 # Test artifacts (auto-created)
├── docker-compose.yml        # Example compose config
├── .env.example              # Environment template
└── README.md                 # This file
```

## 🚀 Quick Start

### Prerequisites

- Bash 4.0+
- Docker (optional, for Docker tests)
- Docker Compose (optional, for compose tests)
- curl (optional, for HTTP tests)
- netcat (optional, for port tests)

### Running Tests

```bash
# Run all tests
./tests/run-tests.sh

# Run with verbose output
./tests/run-tests.sh -v

# Run specific test suite
./tests/run-tests.sh -s docker
./tests/run-tests.sh -s network
./tests/run-tests.sh -s services

# Run specific test file
./tests/run-tests.sh stacks/docker.test.sh

# List available tests
./tests/run-tests.sh --list

# Show help
./tests/run-tests.sh --help
```

### Test Output Example

```
═══════════════════════════════════════════════════════════
  Homelab Integration Tests
═══════════════════════════════════════════════════════════

  Project Root: /path/to/homelab-integration-tests
  Test Dir:     /path/to/homelab-integration-tests/tests
  Stacks Dir:   /path/to/homelab-integration-tests/stacks
  Verbose:      false

═══════════════════════════════════════════════════════════
  Global Setup
═══════════════════════════════════════════════════════════

ℹ Running global test setup...
✓ Global setup complete

═══════════════════════════════════════════════════════════
  Running: docker.test.sh
═══════════════════════════════════════════════════════════

▶ Running: test_docker_daemon_running
✓ Docker command exists
✓ Docker daemon is running
✓ PASSED (0s)

▶ Running: test_docker_run_container
✓ Container exists
✓ Container is running
✓ PASSED (2s)

═══════════════════════════════════════════════════════════
  Final Summary
═══════════════════════════════════════════════════════════

  Test Files:   3
  Passed:       3
  Failed:       0

═══════════════════════════════════════════════════════════
  All tests passed! ✓
═══════════════════════════════════════════════════════════
```

## 📋 Test Suites

### Docker Tests (`docker.test.sh`)

| Test | Description |
|------|-------------|
| `docker_daemon_running` | Verify Docker daemon is running |
| `docker_version` | Check Docker version availability |
| `docker_compose_available` | Verify Docker Compose installation |
| `docker_pull_image` | Test image pull functionality |
| `docker_run_container` | Create and run a container |
| `docker_exec` | Execute commands in container |
| `docker_logs` | Retrieve container logs |
| `docker_network_create` | Create Docker networks |
| `docker_volume_create` | Create Docker volumes |
| `docker_volume_mount` | Test volume mount read/write |
| `docker_port_mapping` | Verify port mapping |
| `docker_network_connectivity` | Test container network connectivity |
| `docker_image_cleanup` | Test container cleanup |
| `docker_system_info` | Verify Docker system info |
| `docker_prune_available` | Check prune command availability |

### Network Tests (`network.test.sh`)

| Test | Description |
|------|-------------|
| `localhost_reachable` | Verify localhost connectivity |
| `dns_resolution` | Test DNS resolution |
| `loopback_interface` | Verify loopback interface |
| `port_listen` | Test port listening capability |
| `http_get` | HTTP GET request test |
| `http_timeout` | HTTP timeout handling |
| `ssl_connectivity` | HTTPS/SSL connectivity |
| `network_interfaces` | List network interfaces |
| `routing_table` | Verify routing table |
| `etc_hosts` | Check /etc/hosts file |
| `etc_resolv_conf` | Check /etc/resolv.conf |
| `socket_statistics` | Socket statistics (ss/netstat) |
| `tcp_connection` | TCP connection test |
| `network_namespace` | Network namespace (container) |
| `ipv6_availability` | IPv6 availability check |

### Services Tests (`services.test.sh`)

| Test | Description |
|------|-------------|
| `service_container_running` | Check service containers |
| `http_health_endpoint` | HTTP health endpoint checks |
| `database_connectivity` | Database connection tests |
| `service_logs` | Service log availability |
| `compose_services_status` | Docker Compose status |
| `service_restart` | Service restart capability |
| `service_network_connectivity` | Service network connectivity |
| `service_volume_persistence` | Volume persistence check |
| `service_resource_limits` | Resource limits verification |
| `service_healthcheck_configured` | Health check configuration |
| `external_service_reachability` | External service access |

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOMELAB_COMPOSE_FILE` | `docker-compose.yml` | Path to docker-compose file |
| `HEALTH_TIMEOUT` | `30` | Health check timeout (seconds) |
| `SKIP_DOCKER_TESTS` | `false` | Skip Docker tests |
| `SKIP_HTTP_TESTS` | `false` | Skip HTTP tests |
| `SKIP_HTTP_HEALTH` | `false` | Skip HTTP health checks |
| `SKIP_PORT_TESTS` | `false` | Skip port tests |

### Custom Service Endpoints

Edit `stacks/services.test.sh` to customize service health endpoints:

```bash
declare -A SERVICE_ENDPOINTS=(
    ["grafana"]="http://localhost:3000/api/health"
    ["prometheus"]="http://localhost:9090/-/healthy"
    ["alertmanager"]="http://localhost:9093/-/healthy"
    ["nginx"]="http://localhost:80/"
    ["traefik"]="http://localhost:8080/ping"
)
```

## 📝 Writing Custom Tests

### Test File Structure

```bash
#!/bin/bash
# mytest.test.sh - Custom test suite

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/assert.sh"

# Setup (optional)
setup() {
    log_info "Setting up test environment..."
}

# Teardown (optional)
teardown() {
    log_info "Cleaning up test environment..."
}

# Test functions (must start with test_)
test_my_feature() {
    log_test_start "my_feature"
    
    # Your test logic here
    assert_equals "expected" "actual" "Description"
    
    log_test_end "pass"
    return 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    for test_func in $(declare -F | awk '/^declare -f test_/ {print $3}'); do
        reset_assertions
        echo "Running $test_func..."
        $test_func || echo "FAILED: $test_func"
    done
    get_test_summary
fi
```

### Available Assertions

| Assertion | Description |
|-----------|-------------|
| `assert_equals` | Check equality |
| `assert_not_equals` | Check inequality |
| `assert_contains` | Check string contains substring |
| `assert_not_contains` | Check string doesn't contain |
| `assert_file_exists` | Check file exists |
| `assert_dir_exists` | Check directory exists |
| `assert_exit_code` | Check exit code |
| `assert_command_exists` | Check command available |
| `assert_http_status` | Check HTTP status code |
| `assert_port_open` | Check port is open |
| `assert_port_closed` | Check port is closed |
| `assert_process_running` | Check process is running |
| `assert_docker_container_running` | Check container running |
| `assert_docker_image_exists` | Check image exists |
| `assert_docker_volume_exists` | Check volume exists |
| `assert_docker_network_exists` | Check network exists |
| `assert_service_health` | Check service health endpoint |
| `assert_log_contains` | Check log contains pattern |
| `assert_json_value` | Check JSON value (requires jq) |

## 🐳 Docker Compose Example

```yaml
version: '3.8'

services:
  # Example service with health check
  web:
    image: nginx:1.25-alpine
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html:ro
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - homelab
    deploy:
      resources:
        limits:
          memory: 256M

  # Database with persistence
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD:-secret}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - homelab

volumes:
  postgres_data:

networks:
  homelab:
    driver: bridge
```

## 🔍 Troubleshooting

### Common Issues

**Tests failing with "command not found"**
- Ensure required tools are installed: `docker`, `curl`, `nc`
- Check PATH environment variable

**Docker tests failing**
- Verify Docker daemon is running: `docker info`
- Check user permissions: `sudo usermod -aG docker $USER`

**HTTP tests timing out**
- Check network connectivity
- Verify firewall rules
- Increase timeout: `export HEALTH_TIMEOUT=60`

**Permission denied errors**
- Run tests with appropriate permissions
- For Docker: ensure user is in docker group

### Debug Mode

Enable verbose output for detailed debugging:

```bash
./tests/run-tests.sh -v
```

## 📊 CI/CD Integration

### GitHub Actions

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Docker
        uses: docker/setup-buildx-action@v3
      
      - name: Run Integration Tests
        run: |
          chmod +x tests/run-tests.sh
          ./tests/run-tests.sh -v
```

### GitLab CI

```yaml
integration-tests:
  image: docker:24-dind
  services:
    - docker:24-dind
  script:
    - chmod +x tests/run-tests.sh
    - ./tests/run-tests.sh -v
```

## 📈 Test Coverage

The framework provides comprehensive coverage for:

- ✅ Docker daemon and CLI operations
- ✅ Container lifecycle management
- ✅ Docker networking and volumes
- ✅ HTTP/HTTPS connectivity
- ✅ DNS resolution
- ✅ Port availability
- ✅ Service health endpoints
- ✅ Database connectivity
- ✅ Resource limits
- ✅ Health check configurations

## 📄 License

MIT License - See LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📞 Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation
- Review test examples in `stacks/` directory

---

**Built for Homelab** 🏠 | **Pure Bash** 🐚 | **No Dependencies** ✅
