use serde::{Deserialize, Serialize};
use std::env;
use std::io::{self, Read, Write};

#[derive(Deserialize)]
struct Input {
    #[serde(default)]
    message: String,
}

#[derive(Serialize)]
struct Output {
    status: String,
    secret_value: Option<String>,
    secret_found: bool,
    message: String,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Read input from stdin (JSON)
    let mut input_string = String::new();
    io::stdin().read_to_string(&mut input_string)?;

    // Parse JSON input
    let input: Input = serde_json::from_str(&input_string).unwrap_or(Input {
        message: String::new(),
    });

    // Try to read SECRET from environment
    let (secret_found, secret_value, status, message) = match env::var("SECRET") {
        Ok(value) => (
            true,
            Some(value.clone()),
            "success".to_string(),
            format!("SECRET found! Value: {}", value),
        ),
        Err(_) => (
            false,
            None,
            "error".to_string(),
            "SECRET environment variable not found".to_string(),
        ),
    };

    // Create output
    let output = Output {
        status,
        secret_value,
        secret_found,
        message,
    };

    // Write JSON output to stdout
    let json = serde_json::to_string(&output)?;
    print!("{}", json);
    io::stdout().flush()?;

    Ok(())
}
