use config::{Config as ConfigSource, ConfigError, Environment};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Config {
    pub database_url: String,
    pub server_port: u16,
    pub server_host: String,
    pub log_level: String,
    pub hmac_key: String,
}

impl Config {
    pub fn load() -> Result<Self, ConfigError> {
        // Load .env file if it exists
        dotenv::dotenv().ok();

        let config = ConfigSource::builder()
            // Start with default values
            .set_default("server_port", 8080)?
            // Add in settings from the environment
            // E.g. `APP_SERVER__PORT=8080` would set `server_port`
            .add_source(Environment::with_prefix("APP").separator("__"))
            .build()?;

        // Convert the config values into our Config struct
        let config: Config = config.try_deserialize()?;

        // Validate required values
        config.validate()?;

        Ok(config)
    }

    fn validate(&self) -> Result<(), ConfigError> {
        // Validate database_url is present
        if self.database_url.is_empty() {
            return Err(ConfigError::NotFound("database_url".into()));
        }

        // Validate port is in valid range
        if self.server_port == 0 {
            return Err(ConfigError::Message("server_port cannot be 0".into()));
        }

        Ok(())
    }
}
