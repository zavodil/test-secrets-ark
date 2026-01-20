//! Secrets Test Ark - Test suite for OutLayer secrets via environment variables
//!
//! Uses the `outlayer` SDK for env access.

use outlayer::env;
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
struct Input {
    #[serde(default)]
    message: String,
}

#[derive(Serialize)]
struct SecretInfo {
    key: String,
    found: bool,
    value: Option<String>,
}

#[derive(Serialize)]
struct Output {
    success: bool,
    status: String,
    secrets: Vec<SecretInfo>,
    found_count: usize,
    total_count: usize,
    message: String,
}

fn main() {
    let output = match env::input_json::<Input>() {
        Ok(Some(_input)) => check_secrets(),
        Ok(None) => check_secrets(), // No input is fine, just check secrets
        Err(e) => Output {
            success: false,
            status: "error".to_string(),
            secrets: vec![],
            found_count: 0,
            total_count: 0,
            message: format!("Failed to parse input: {}", e),
        },
    };

    let _ = env::output_json(&output);
}

fn check_secrets() -> Output {
    let keys = ["SECRET", "ANOTHER_SECRET", "PROTECTED_SECRET", "PROTECTED_ANOTHER_SECRET"];
    let mut secrets: Vec<SecretInfo> = Vec::new();

    // Try to read each key from environment
    for key in keys {
        let (found, value) = match std::env::var(key) {
            Ok(v) => (true, Some(v)),
            Err(_) => (false, None),
        };
        secrets.push(SecretInfo {
            key: key.to_string(),
            found,
            value,
        });
    }

    let found_count = secrets.iter().filter(|s| s.found).count();
    let total_count = secrets.len();

    let status = if found_count == total_count {
        "success"
    } else if found_count > 0 {
        "partial"
    } else {
        "not_found"
    };

    let message = format!(
        "Found {}/{} secrets: {}",
        found_count,
        total_count,
        secrets
            .iter()
            .map(|s| format!("{}={}", s.key, if s.found { "Y" } else { "N" }))
            .collect::<Vec<_>>()
            .join(", ")
    );

    Output {
        success: found_count > 0,
        status: status.to_string(),
        secrets,
        found_count,
        total_count,
        message,
    }
}
