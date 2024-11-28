use crate::config::Config;
use anyhow::Context;
use axum::{Extension, Router};
use sqlx::SqlitePool;
use std::sync::Arc;
use tower::ServiceBuilder;

// Utility modules
mod error;
mod extractor;
mod types;
mod users;

pub use error::{Error, ResultExt};
pub type Result<T, E = Error> = std::result::Result<T, E>;
use tower_http::trace::TraceLayer;

#[derive(Clone)]
struct ApiContext {
    config: Arc<Config>,
    db: SqlitePool,
}

pub async fn serve(config: Config, db: SqlitePool) -> anyhow::Result<()> {
    let context = ApiContext {
        config: Arc::new(config),
        db,
    };

    // Create the router with state
    let app = api_router().layer(
        ServiceBuilder::new()
            .layer(Extension(context))
            .layer(TraceLayer::new_for_http()),
    );

    // Updated server binding
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await?;
    println!("Server listening on {}", listener.local_addr()?);

    axum::serve(listener, app)
        .await
        .context("error running HTTP server")
}

fn api_router() -> Router {
    Router::new().merge(users::router())
}
