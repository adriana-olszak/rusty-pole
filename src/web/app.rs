use crate::config::Config;
use axum_login::{
    login_required,
    tower_sessions::{ExpiredDeletion, Expiry, SessionManagerLayer},
    AuthManagerLayerBuilder,
};
use axum_messages::MessagesManagerLayer;
use sqlx::{sqlite::SqlitePoolOptions, Result, SqlitePool};
use time::Duration;
use tokio::{signal, task::AbortHandle};
use tower_sessions::cookie::Key;
use tower_sessions_sqlx_store::SqliteStore;

use crate::{
    users::Backend,
    web::{auth, protected},
};

pub struct App {
    db: SqlitePool,
    config: Config,
}

impl App {
    pub async fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let config = Config::load()?;
        println!("Configuration: {:?}", config);
        // We create a single connection pool for SQLx that's shared across the whole application.
        // This saves us from opening a new connection for every API call, which is wasteful.
        let db = SqlitePoolOptions::new()
            // SQLite doesn't really need many connections since it's file-based
            .max_connections(5)
            .connect(&config.database_url)
            .await
            .context("could not connect to database_url")?;

        // Enable foreign key support for SQLite
        sqlx::query("PRAGMA foreign_keys = ON")
            .execute(&db)
            .await
            .context("could not enable foreign keys")?;

        // This embeds database migrations in the application binary so we can ensure the database
        // is migrated correctly on startup
        sqlx::migrate!().run(&db).await?;

        Ok(Self { db, config })
    }

    pub async fn serve(self) -> Result<(), Box<dyn std::error::Error>> {
        // Session layer.
        //
        // This uses `tower-sessions` to establish a layer that will provide the session
        // as a request extension.
        let session_store = SqliteStore::new(self.db.clone());
        session_store.migrate().await?;

        let deletion_task = tokio::task::spawn(
            session_store
                .clone()
                .continuously_delete_expired(tokio::time::Duration::from_secs(60)),
        );

        // Generate a cryptographic key to sign the session cookie.
        let key = Key::generate();

        let session_layer = SessionManagerLayer::new(session_store)
            .with_secure(false)
            .with_expiry(Expiry::OnInactivity(Duration::days(1)))
            .with_signed(key);

        // Auth service.
        //
        // This combines the session layer with our backend to establish the auth
        // service which will provide the auth session as a request extension.
        let backend = Backend::new(self.db);
        let auth_layer = AuthManagerLayerBuilder::new(backend, session_layer).build();

        let app = protected::router()
            .route_layer(login_required!(Backend, login_url = "/login"))
            .merge(auth::router())
            .layer(MessagesManagerLayer)
            .layer(auth_layer);

        let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();

        // Ensure we use a shutdown signal to abort the deletion task.
        axum::serve(listener, app.into_make_service())
            .with_graceful_shutdown(shutdown_signal(deletion_task.abort_handle()))
            .await?;

        deletion_task.await??;

        Ok(())
    }
}

async fn shutdown_signal(deletion_task_abort_handle: AbortHandle) {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => { deletion_task_abort_handle.abort() },
        _ = terminate => { deletion_task_abort_handle.abort() },
    }
}
