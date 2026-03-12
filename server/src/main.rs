mod models;

use actix_web::{web, App, HttpServer, Responder, HttpResponse};
use actix_files as fs;
use sqlx::postgres::{PgPool, PgPoolOptions};
use dotenvy::dotenv;
use std::env;
use crate::models::{User, CreateUserRequest};
use crate::models::{LoginRequest, LoginResponse, BindRoleRequest,
StudentInfo, UserInfoRequest, Course
};

// Обработчик для получения списка пользователей
async fn get_users(state: web::Data<AppState>) -> impl Responder {
    let pool = &state.public_pool;
    let result = sqlx::query_as::<_, User>("SELECT * FROM base.users")
        .fetch_all(pool)
        .await;

    match result {
        Ok(users) => HttpResponse::Ok().json(users),
        Err(e) => {
            eprintln!("Ошибка: {}", e); // всё равно логируем
            HttpResponse::InternalServerError().body(format!("Ошибка базы данных: {}", e))
        }
    }
}

// Обработчик для создания нового пользователя
async fn create_user(
    state: web::Data<AppState>,
    user_req: web::Json<CreateUserRequest>,
) -> impl Responder {
    let pool = &state.public_pool;
    // Начинаем транзакцию
    let mut tx = match pool.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            eprintln!("Ошибка начала транзакции: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка сервера");
        }
    };
    // Вызываем хранимую процедуру add_user
    let call_result = sqlx::query("CALL base.add_user($1, $2, $3)")
        .bind(&user_req.username)
        .bind(&user_req.email)
        .bind(&user_req.password)
        .execute(&mut *tx) // выполняем в контексте транзакции
        .await;

    // Обрабатываем ошибки вызова процедуры
    if let Err(e) = call_result {
        let _ = tx.rollback().await; // откатываем транзакцию
        match e {
            sqlx::Error::Database(db_err) => {
                // Проверяем нарушения уникальности (имена индексов могут отличаться)
                if db_err.constraint() == Some("users_user_name_key") {
                    return HttpResponse::Conflict().body("Пользователь с таким именем уже существует");
                }
                if db_err.constraint() == Some("users_email_key") {
                    return HttpResponse::Conflict().body("Пользователь с таким email уже существует");
                }
                eprintln!("Ошибка базы данных: {:?}", db_err);
                HttpResponse::InternalServerError().body("Ошибка базы данных")
            }
            _ => {
                eprintln!("Неизвестная ошибка: {:?}", e);
                HttpResponse::InternalServerError().body("Внутренняя ошибка сервера")
            }
        }
    } else {
        // Процедура выполнена успешно – получаем созданного пользователя по user_name
        let user = sqlx::query_as::<_, User>(
            "SELECT id, user_name, email, create_at FROM base.users WHERE user_name = $1"
        )
        .bind(&user_req.username)
        .fetch_one(&mut *tx)
        .await;

        match user {
            Ok(user) => {
                // Фиксируем транзакцию
                if let Err(e) = tx.commit().await {
                    eprintln!("Ошибка коммита: {:?}", e);
                    return HttpResponse::InternalServerError().body("Ошибка при сохранении");
                }
                HttpResponse::Created().json(user)
            }
            Err(e) => {
                let _ = tx.rollback().await;
                eprintln!("Ошибка при получении созданного пользователя: {:?}", e);
                HttpResponse::InternalServerError().body("Пользователь создан, но не удалось получить данные")
            }
        }
    }
}

async fn authenticate(
    state: web::Data<AppState>,
    creds: web::Json<LoginRequest>,
) -> impl Responder {
    let pool = &state.public_pool;
    // 1. Проверка пароля через authenticate_user
    let auth_result = sqlx::query_scalar::<_, bool>("SELECT base.authenticate_user($1, $2)")
        .bind(&creds.login)
        .bind(&creds.password)
        .fetch_one(pool)
        .await;

    match auth_result {
        Ok(true) => {
            // 2. Проверка наличия роли через authenticate_role
            let role_result = sqlx::query_scalar::<_, bool>("SELECT base.authenticate_role($1)")
                .bind(&creds.login)
                .fetch_one(pool)
                .await;

            match role_result {
                Ok(has_role) => {
                    // Здесь можно сгенерировать JWT токен (опционально)
                    HttpResponse::Ok().json(LoginResponse {
                        authenticated: true,
                        role_bound: has_role,
                        token: None, // если нужно, добавьте генерацию токена
                    })  
                }
                Err(e) => {
                    eprintln!("Ошибка проверки роли: {:?}", e);
                    HttpResponse::InternalServerError().body("Ошибка проверки роли")
                }
            }
        }
        Ok(false) => HttpResponse::Unauthorized().json(LoginResponse {
            authenticated: false,
            role_bound: false,
            token: None,
        }),
        Err(e) => {
            eprintln!("Ошибка аутентификации: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка сервера")
        }
    }
}

async fn bind_role(
     state: web::Data<AppState>,
    req: web::Json<BindRoleRequest>,
) -> impl Responder {
    let pool = &state.public_pool;
    let result = sqlx::query_scalar::<_, bool>("SELECT base.binding_role($1, $2)")
        .bind(&req.login)
        .bind(&req.role_password)
        .fetch_one(pool)
        .await;

    match result {
        Ok(true) => HttpResponse::Ok().json(serde_json::json!({ "success": true })),
        Ok(false) => HttpResponse::BadRequest().json(serde_json::json!({
            "success": false,
            "error": "Не удалось привязать роль (неверный код или роль уже привязана)"
        })),
        Err(e) => {
            eprintln!("Ошибка привязки роли: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка сервера")
        }
    }
}

async fn get_user_info(
    state: web::Data<AppState>,
    req: web::Json<UserInfoRequest>,
) -> impl Responder {
    let pool = &state.student_pool;

    let result = sqlx::query_as::<_, (String, String, String, String)>(
        "SELECT * FROM base.get_students_by_username($1)"
    )
    .bind(&req.username)
    .fetch_optional(pool)
    .await;

    match result {
        Ok(Some((lastname, firstname, patronymic,groupp))) => {
            HttpResponse::Ok().json(StudentInfo { lastname, firstname, patronymic, groupp})
        }
        Ok(None) => HttpResponse::NotFound().body("Студент не найден"),
        Err(e) => {
            eprintln!("Ошибка получения информации о студенте: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка сервера")
        }
    }
}

async fn get_courses(
    state: web::Data<AppState>,
    req: web::Json<UserInfoRequest>, // { username: String }
) -> impl Responder {
    let pool = &state.student_pool;

    let courses = sqlx::query_as::<_, Course>(
        "SELECT * FROM base.get_courses_by_username($1)"
    )
    .bind(&req.username)
    .fetch_all(pool)
    .await;

    match courses {
        Ok(courses) => HttpResponse::Ok().json(courses),
        Err(e) => {
            eprintln!("Ошибка получения курсов: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка получения курсов")
        }
    }
}

pub struct AppState {
    public_pool: PgPool,
    student_pool: PgPool,
    } 

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Загружаем переменные окружения из .env
    dotenv().ok();
    env_logger::init();

    // Создаём пул соединений
    let public_pool = PgPoolOptions::new()
    .max_connections(10)
    .connect(&env::var("DATABASE_URL_PUBLIC").expect("DATABASE_URL_PUBLIC not set"))
    .await
    .expect("Failed to connect with public user");

    let student_pool = PgPoolOptions::new()
    .max_connections(5) // меньше соединений для чтения
    .connect(&env::var("DATABASE_URL_STUDENT").expect("DATABASE_URL_STUDENT not set"))
    .await
    .expect("Failed to connect with student user");

    println!("Сервер запущен на http://127.0.0.1:8080");

    // Запускаем HTTP сервер
    HttpServer::new(move || {
    let state = web::Data::new(AppState {
        public_pool: public_pool.clone(),
        student_pool: student_pool.clone(),
    });

    App::new()
        .app_data(state.clone())
        .route("/users", web::post().to(create_user))
        .route("/login", web::post().to(authenticate))
        .route("/bind-role", web::post().to(bind_role))
        .route("/user-info", web::post().to(get_user_info)) // новый эндпоинт
        .route("/courses", web::post().to(get_courses))
        .service(fs::Files::new("/", "./static").index_file("index.html"))
    })
    .bind(("127.0.0.1", 8080))?
    .run()
    .await
}
