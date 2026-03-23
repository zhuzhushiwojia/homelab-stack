#!/bin/bash
# run-tests.sh - Main test runner for Homelab Integration Tests
# Usage: ./tests/run-tests.sh [options] [test_files...]
#
# Options:
#   -v, --verbose     Enable verbose output
#   -q, --quiet       Quiet mode (only show failures)
#   -s, --suite       Run specific test suite
#   -h, --help        Show this help message
#   --setup           Run setup only
#   --teardown        Run teardown only
#   --list            List all available tests

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source libraries
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/assert.sh"

# Configuration
VERBOSE=false
QUIET=false
SPECIFIC_SUITE=""
RUN_SETUP_ONLY=false
RUN_TEARDOWN_ONLY=false
LIST_TESTS=false

# Test configuration
TESTS_DIR="$SCRIPT_DIR"
STACKS_DIR="$PROJECT_ROOT/stacks"
LIB_DIR="$PROJECT_ROOT/lib"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Print help message
print_help() {
    cat << EOF
Homelab Integration Test Runner

Usage: $0 [options] [test_files...]

Options:
  -v, --verbose     Enable verbose output
  -q, --quiet       Quiet mode (only show failures)
  -s, --suite       Run specific test suite (e.g., docker, network, service)
  -h, --help        Show this help message
  --setup           Run setup only
  --teardown        Run teardown only
  --list            List all available tests

Examples:
  $0                          # Run all tests
  $0 -v                       # Run all tests with verbose output
  $0 -s docker                # Run only docker test suite
  $0 stacks/docker.test.sh    # Run specific test file
  $0 --list                   # List all available tests

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -s|--suite)
                SPECIFIC_SUITE="$2"
                shift 2
                ;;
            --setup)
                RUN_SETUP_ONLY=true
                shift
                ;;
            --teardown)
                RUN_TEARDOWN_ONLY=true
                shift
                ;;
            --list)
                LIST_TESTS=true
                shift
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                # Treat as test file
                TEST_FILES+=("$1")
                shift
                ;;
        esac
    done
}

# List all available tests
list_tests() {
    log_section "Available Tests"
    
    echo "Test Suites:"
    echo "============"
    
    if [[ -d "$STACKS_DIR" ]]; then
        for test_file in "$STACKS_DIR"/*.test.sh; do
            if [[ -f "$test_file" ]]; then
                local suite_name=$(basename "$test_file" .test.sh)
                echo "  - $suite_name"
            fi
        done
    fi
    
    echo ""
    echo "Test Files:"
    echo "==========="
    
    if [[ -d "$STACKS_DIR" ]]; then
        find "$STACKS_DIR" -name "*.test.sh" -type f | sort | while read -r file; do
            echo "  - $(basename "$file")"
        done
    fi
    
    echo ""
}

# Run setup for all tests
run_global_setup() {
    log_section "Global Setup"
    log_info "Running global test setup..."
    
    # Check prerequisites
    if ! is_docker_available; then
        log_warning "Docker is not available, skipping Docker-related tests"
        export SKIP_DOCKER_TESTS=true
    fi
    
    if ! is_docker_compose_available; then
        log_warning "Docker Compose is not available"
        export SKIP_COMPOSE_TESTS=true
    fi
    
    # Create test artifacts directory
    mkdir -p "$PROJECT_ROOT/artifacts"
    
    log_success "Global setup complete"
}

# Run teardown for all tests
run_global_teardown() {
    log_section "Global Teardown"
    log_info "Running global test teardown..."
    
    # Clean up test artifacts older than 24 hours
    if [[ -d "$PROJECT_ROOT/artifacts" ]]; then
        find "$PROJECT_ROOT/artifacts" -type f -mmin +1440 -delete 2>/dev/null || true
    fi
    
    log_success "Global teardown complete"
}

# Run a single test file
run_test_file() {
    local test_file="$1"
    
    if [[ ! -f "$test_file" ]]; then
        log_error "Test file not found: $test_file"
        return 1
    fi
    
    log_section "Running: $(basename "$test_file")"
    
    # Source the test file (it should define test functions)
    source "$test_file"
    
    # Run setup if defined
    if declare -f setup &> /dev/null; then
        log_info "Running setup..."
        setup || {
            log_error "Setup failed"
            return 1
        }
    fi
    
    # Run all test_* functions
    local test_count=0
    local pass_count=0
    local fail_count=0
    
    for test_func in $(declare -F | awk '/^declare -f test_/ {print $3}'); do
        if [[ -n "$SPECIFIC_SUITE" ]] && [[ "$test_func" != *"${SPECIFIC_SUITE}"* ]]; then
            continue
        fi
        
        ((test_count++))
        reset_assertions
        
        log_test_start "$test_func"
        
        if $test_func; then
            ((pass_count++))
            log_test_end "pass"
        else
            ((fail_count++))
            log_test_end "fail"
        fi
    done
    
    # Run teardown if defined
    if declare -f teardown &> /dev/null; then
        log_info "Running teardown..."
        teardown || log_warning "Teardown had errors"
    fi
    
    # Print summary
    echo ""
    log_section "Test Results: $(basename "$test_file")"
    echo -e "  Total Tests:  $test_count"
    echo -e "  Passed:       ${GREEN}$pass_count${NC}"
    echo -e "  Failed:       ${RED}$fail_count${NC}"
    
    return $fail_count
}

# Run all tests in stacks directory
run_all_tests() {
    local total_files=0
    local total_passed=0
    local total_failed=0
    
    if [[ ${#TEST_FILES[@]} -gt 0 ]]; then
        # Run specific test files
        for test_file in "${TEST_FILES[@]}"; do
            ((total_files++))
            if run_test_file "$test_file"; then
                ((total_passed++))
            else
                ((total_failed++))
            fi
        done
    elif [[ -d "$STACKS_DIR" ]]; then
        # Run all test files in stacks directory
        for test_file in "$STACKS_DIR"/*.test.sh; do
            if [[ -f "$test_file" ]]; then
                ((total_files++))
                if run_test_file "$test_file"; then
                    ((total_passed++))
                else
                    ((total_failed++))
                fi
            fi
        done
    fi
    
    # Print final summary
    echo ""
    log_section "Final Summary"
    echo -e "  Test Files:   $total_files"
    echo -e "  Passed:       ${GREEN}$total_passed${NC}"
    echo -e "  Failed:       ${RED}$total_failed${NC}"
    echo ""
    
    if [[ $total_failed -eq 0 ]]; then
        echo -e "${GREEN}════════════════════════════════════════${NC}"
        echo -e "${GREEN}  All tests passed! ✓${NC}"
        echo -e "${GREEN}════════════════════════════════════════${NC}"
        return 0
    else
        echo -e "${RED}════════════════════════════════════════${NC}"
        echo -e "${RED}  Some tests failed! ✗${NC}"
        echo -e "${RED}════════════════════════════════════════${NC}"
        return 1
    fi
}

# Main function
main() {
    parse_args "$@"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Handle list tests
    if [[ "$LIST_TESTS" == true ]]; then
        list_tests
        exit 0
    fi
    
    # Handle setup only
    if [[ "$RUN_SETUP_ONLY" == true ]]; then
        run_global_setup
        exit 0
    fi
    
    # Handle teardown only
    if [[ "$RUN_TEARDOWN_ONLY" == true ]]; then
        run_global_teardown
        exit 0
    fi
    
    # Print banner
    log_section "Homelab Integration Tests"
    echo -e "  Project Root: ${CYAN}$PROJECT_ROOT${NC}"
    echo -e "  Test Dir:     ${CYAN}$TESTS_DIR${NC}"
    echo -e "  Stacks Dir:   ${CYAN}$STACKS_DIR${NC}"
    echo -e "  Verbose:      ${VERBOSE}"
    echo ""
    
    # Run global setup
    run_global_setup
    
    # Run tests
    local exit_code=0
    run_all_tests || exit_code=$?
    
    # Run global teardown
    run_global_teardown
    
    exit $exit_code
}

# Run main function
main "$@"
