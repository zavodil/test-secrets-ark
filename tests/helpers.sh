#!/bin/bash
# Helper functions for test scripts

# Normalize repo URL (same logic as keystore)
# Removes https://, http://, converts git@ format
normalize_repo_url() {
    local repo=$1

    # Remove https:// or http://
    repo=$(echo "$repo" | sed 's|^https://||' | sed 's|^http://||')

    # Convert git@github.com:user/repo.git to github.com/user/repo
    if [[ "$repo" =~ ^git@github.com: ]]; then
        repo=$(echo "$repo" | sed 's|^git@github.com:|github.com/|' | sed 's|\.git$||')
    fi

    # Ensure it starts with github.com/
    if [[ ! "$repo" =~ ^github.com/ ]]; then
        repo="github.com/$repo"
    fi

    echo "$repo"
}

# Load environment variables
load_env() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local env_file="$script_dir/../.env"

    if [ ! -f "$env_file" ]; then
        echo "Error: .env file not found at $env_file" >&2
        echo "Please copy .env.example to .env and configure it" >&2
        exit 1
    fi

    # Load .env file
    set -a
    source "$env_file"
    set +a

    # Validate required variables
    if [ -z "$KEYSTORE_BASE_URL" ]; then
        echo "Error: KEYSTORE_BASE_URL not set in .env" >&2
        exit 1
    fi

    if [ -z "$KEYSTORE_AUTH_TOKEN" ]; then
        echo "Error: KEYSTORE_AUTH_TOKEN not set in .env" >&2
        exit 1
    fi
}

# Encrypt secrets using keystore API directly
encrypt_secrets_json() {
    local repo=$1
    local owner=$2
    local branch=$3
    local secrets_json=$4

    # Normalize repo URL
    if [[ "$repo" =~ ^https://github.com/ ]]; then
        repo=$(echo "$repo" | sed 's|https://github.com/|github.com/|')
    elif [[ "$repo" =~ ^git@github.com: ]]; then
        repo=$(echo "$repo" | sed 's|git@github.com:|github.com/|' | sed 's|\.git$||')
    elif [[ ! "$repo" =~ ^github.com/ ]]; then
        repo="github.com/$repo"
    fi

    # Build seed: repo:owner[:branch]
    local seed="$repo:$owner"
    if [ -n "$branch" ]; then
        seed="$seed:$branch"
    fi

    echo "🔑 Seed: $seed" >&2

    # Get public key from keystore
    local pubkey_response
    pubkey_response=$(curl -s -H "Authorization: Bearer $KEYSTORE_AUTH_TOKEN" \
        "$KEYSTORE_BASE_URL/pubkey?seed=$(printf %s "$seed" | jq -sRr @uri)")

    if [ $? -ne 0 ]; then
        echo "Error: Failed to connect to keystore at $KEYSTORE_BASE_URL" >&2
        return 1
    fi

    local pubkey
    pubkey=$(echo "$pubkey_response" | jq -r '.pubkey' 2>/dev/null)

    if [ -z "$pubkey" ] || [ "$pubkey" = "null" ]; then
        echo "Error: Failed to get public key from keystore" >&2
        echo "Response: $pubkey_response" >&2
        return 1
    fi

    echo "✅ Got pubkey: ${pubkey:0:16}..." >&2

    # Encrypt using Python inline script (same XOR logic as keystore)
    local encrypted_base64
    encrypted_base64=$(python3 -c "
import sys
import hashlib
import base64

pubkey_hex = '$pubkey'
plaintext = '''$secrets_json'''

# Derive symmetric key (same as keystore)
key_material = bytes.fromhex(pubkey_hex)
hasher = hashlib.sha256()
hasher.update(key_material)
hasher.update(b'keystore-encryption-v1')
derived_key = hasher.digest()

# XOR encryption
plaintext_bytes = plaintext.encode('utf-8')
ciphertext = bytes(
    b ^ derived_key[i % len(derived_key)]
    for i, b in enumerate(plaintext_bytes)
)

# Output base64
print(base64.b64encode(ciphertext).decode('ascii'))
" 2>&1)

    if [ $? -ne 0 ]; then
        echo "Error: Failed to encrypt secrets" >&2
        echo "$encrypted_base64" >&2
        return 1
    fi

    echo "$encrypted_base64"
}
