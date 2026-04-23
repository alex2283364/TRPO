mod models;
mod state;
mod handlers;   // модуль handlers ожидает файл handlers/mod.rs

use actix_files as fs;
use actix_web::{web, App, HttpServer};
use dotenvy::dotenv;
use sqlx::postgres::{PgPool, PgPoolOptions};
use std::env;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();
    env_logger::init();

    // Пул для операций с правами public
    let public_pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&env::var("DATABASE_URL_PUBLIC").expect("DATABASE_URL_PUBLIC not set"))
        .await
        .expect("Failed to connect with public user");

    // Пул для операций с правами student
    let student_pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&env::var("DATABASE_URL_STUDENT").expect("DATABASE_URL_STUDENT not set"))
        .await
        .expect("Failed to connect with student user");

    let state = web::Data::new(state::AppState {
        public_pool,
        student_pool,
    });

    println!("Сервер запущен на http://127.0.0.1:8080");

    HttpServer::new(move || {
        App::new()
            .app_data(state.clone())
            .route("/users", web::post().to(handlers::user::create_user))
            .route("/login", web::post().to(handlers::user::authenticate))
            .route("/bind-role", web::post().to(handlers::user::bind_role))
            .route("/user-info", web::post().to(handlers::user::get_user_info))
            .route("/courses", web::post().to(handlers::course::get_courses))
            .route(
                "/course-content/{course_id}",
                web::get().to(handlers::course::get_course_content),
            )
            .route("/file/{file_id}", web::get().to(handlers::course::get_file))
            .route(
                "/task/{task_id}/{time_id}",
                web::get().to(handlers::course::get_task_details),
            )
            .route("/set-answer", web::post().to(handlers::answer::set_answer))
            .route("/upload", web::post().to(handlers::answer::upload_file))
            .service(fs::Files::new("/", "./static").index_file("index.html"))
    })
    .bind(("127.0.0.1", 8080))?
    .run()
    .await
}