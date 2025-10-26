#!/bin/bash
# Read secrets from contract
# Usage: ./read_secrets.sh [test_numbers...]
# Example: ./read_secrets.sh 1 2 3  # Read secrets for tests 1, 2, 3
#          ./read_secrets.sh         # Read all secrets

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load helpers
source "$SCRIPT_DIR/helpers.sh"

# Load test configuration
source "$SCRIPT_DIR/test_config.sh"

# Normalize repo URL (same as keystore does)
REPO=$(normalize_repo_url "$REPO")

# Parse command line arguments
if [ $# -eq 0 ]; then
    # No arguments - read all tests
    TESTS_TO_READ=(1 2 3 4 5 6 7 8 9 10 11 12 13)
else
    # Read specified tests
    TESTS_TO_READ=("$@")
fi

echo "═══════════════════════════════════════════════════════════════"
echo "Reading Secrets from Contract"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Configuration:"
echo "  Contract: $CONTRACT"
echo "  Repo: $REPO"
echo "  Branch: $BRANCH"
echo "  Owner: $OWNER"
echo "  Tests to read: ${TESTS_TO_READ[@]}"
echo ""

# -------------------------------------------------------------------
# Helper function to read secret
# -------------------------------------------------------------------
read_secret() {
    local test_num=$1
    local profile=$2
    local description=$3

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Test $test_num: $description"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Profile: $profile"
    echo ""

    # Call contract view method
    echo "📖 Reading from contract..."

    # Build JSON args
    local json_args
    json_args=$(cat <<EOF
{
  "repo": "$REPO",
  "branch": "$BRANCH",
  "profile": "$profile",
  "owner": "$OWNER"
}
EOF
)

    echo "Query: near contract call-function as-read-only $CONTRACT get_secrets ..."
    echo ""

    # Disable exit on error for this command
    set +e
    local output
    output=$(near contract call-function as-read-only "$CONTRACT" get_secrets \
        json-args "$json_args" \
        network-config testnet \
        now 2>&1)
    local exit_code=$?
    set -e

    if [ $exit_code -eq 0 ]; then
        echo "$output"
        echo ""

        # Check if secrets exist
        if echo "$output" | grep -q "encrypted_secrets"; then
            echo "✅ Secret exists"

            # Extract encrypted data
            local encrypted=$(echo "$output" | jq -r '.encrypted_secrets' 2>/dev/null || echo "")
            if [ -n "$encrypted" ] && [ "$encrypted" != "null" ]; then
                echo "📦 Encrypted data length: ${#encrypted} chars"
            fi

            # Extract access condition
            local access=$(echo "$output" | jq -r '.access' 2>/dev/null || echo "")
            if [ -n "$access" ] && [ "$access" != "null" ]; then
                echo "🔐 Access condition:"
                echo "$access" | jq '.' 2>/dev/null || echo "$access"
            fi
        else
            echo "❌ Secret not found or error reading"
        fi
    else
        echo "❌ Error reading from contract:"
        echo "$output"
    fi
    echo ""
}

# -------------------------------------------------------------------
# Helper function to get profile name for test
# -------------------------------------------------------------------
get_profile_for_test() {
    local test_num=$1
    case $test_num in
        1) echo "test1_allow_all" ;;
        2) echo "test2_whitelist" ;;
        3) echo "test3_pattern_testnet" ;;
        4) echo "test4_pattern_a" ;;
        5) echo "test5_pattern_length" ;;
        6) echo "test6_near_balance" ;;
        7) echo "test7_ft_balance" ;;
        8) echo "test8_nft_token" ;;
        9) echo "test9_nft_any" ;;
        10) echo "test10_logic_and" ;;
        11) echo "test11_logic_or" ;;
        12) echo "test12_logic_not" ;;
        13) echo "test13_complex" ;;
        *) echo "" ;;
    esac
}

# Helper function to get description for test
get_description_for_test() {
    local test_num=$1
    case $test_num in
        1) echo "AllowAll" ;;
        2) echo "Whitelist" ;;
        3) echo "AccountPattern *.testnet" ;;
        4) echo "AccountPattern a*" ;;
        5) echo "AccountPattern length >= 10" ;;
        6) echo "NearBalance >= 5 NEAR" ;;
        7) echo "FtBalance >= 1000 tokens" ;;
        8) echo "NftOwned specific token" ;;
        9) echo "NftOwned any token" ;;
        10) echo "Logic AND" ;;
        11) echo "Logic OR" ;;
        12) echo "Logic NOT" ;;
        13) echo "Complex Logic" ;;
        *) echo "Unknown" ;;
    esac
}

# -------------------------------------------------------------------
# Read secrets for selected tests
# -------------------------------------------------------------------

for test_num in "${TESTS_TO_READ[@]}"; do
    profile=$(get_profile_for_test "$test_num")
    description=$(get_description_for_test "$test_num")

    if [ -z "$profile" ]; then
        echo "Unknown test number: $test_num (valid: 1-13)"
        continue
    fi

    read_secret "$test_num" "$profile" "$description"
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Reading complete!"
echo "═══════════════════════════════════════════════════════════════"
