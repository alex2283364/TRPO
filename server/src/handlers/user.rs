//! Обработчики, связанные с управлением пользователями, аутентификацией и ролями.

use actix_web::{web, HttpResponse, Responder};
use crate::models::{
    BindRoleRequest, CreateUserRequest, LoginRequest, LoginResponse, StudentInfo, User, UserInfoRequest,
};
use crate::state::AppState;
use serde_json::json;

/// Получение списка всех пользователей (не используется в роутах, но оставлено для возможного администрирования).
pub async fn get_users(state: web::Data<AppState>) -> impl Responder {
    let pool = &state.public_pool;
    match sqlx::query_as::<_, User>("SELECT * FROM base.users")
        .fetch_all(pool)
        .await
    {
        Ok(users) => HttpResponse::Ok().json(users),
        Err(e) => {
            eprintln!("Ошибка: {}", e);
            HttpResponse::InternalServerError().body(format!("Ошибка базы данных: {}", e))
        }
    }
}

/// Создание нового пользователя.
pub async fn create_user(
    state: web::Data<AppState>,
    user_req: web::Json<CreateUserRequest>,
) -> impl Responder {
    let pool = &state.public_pool;
    let mut tx = match pool.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            eprintln!("Ошибка начала транзакции: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка сервера");
        }
    };

    if let Err(e) = sqlx::query("CALL base.add_user($1, $2, $3)")
        .bind(&user_req.username)
        .bind(&user_req.email)
        .bind(&user_req.password)
        .execute(&mut *tx)
        .await
    {
        let _ = tx.rollback().await;
        match e {
            sqlx::Error::Database(db_err) => {
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
        let user = sqlx::query_as::<_, User>(
            "SELECT id, user_name, email, create_at FROM base.users WHERE user_name = $1",
        )
        .bind(&user_req.username)
        .fetch_one(&mut *tx)
        .await;

        match user {
            Ok(user) => {
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

/// Аутентификация пользователя по логину/паролю.
pub async fn authenticate(
    state: web::Data<AppState>,
    creds: web::Json<LoginRequest>,
) -> impl Responder {
    let pool = &state.public_pool;
    let auth_result = sqlx::query_scalar::<_, bool>("SELECT base.authenticate_user($1, $2)")
        .bind(&creds.login)
        .bind(&creds.password)
        .fetch_one(pool)
        .await;

    match auth_result {
        Ok(true) => {
            let role_result = sqlx::query_scalar::<_, bool>("SELECT base.authenticate_role($1)")
                .bind(&creds.login)
                .fetch_one(pool)
                .await;

            match role_result {
                Ok(has_role) => HttpResponse::Ok().json(LoginResponse {
                    authenticated: true,
                    role_bound: has_role,
                    token: None,
                }),
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

/// Привязка роли к пользователю с помощью кода роли.
pub async fn bind_role(
    state: web::Data<AppState>,
    req: web::Json<BindRoleRequest>,
) -> impl Responder {
    let pool = &state.public_pool;
    match sqlx::query_scalar::<_, bool>("SELECT base.binding_role($1, $2)")
        .bind(&req.login)
        .bind(&req.role_password)
        .fetch_one(pool)
        .await
    {
        Ok(true) => HttpResponse::Ok().json(json!({ "success": true })),
        Ok(false) => HttpResponse::BadRequest().json(json!({
            "success": false,
            "error": "Не удалось привязать роль (неверный код или роль уже привязана)"
        })),
        Err(e) => {
            eprintln!("Ошибка привязки роли: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка сервера")
        }
    }
}

/// Получение информации о студенте (ФИО, группа) по имени пользователя.
pub async fn get_user_info(
    state: web::Data<AppState>,
    req: web::Json<UserInfoRequest>,
) -> impl Responder {
    let pool = &state.student_pool;
    match sqlx::query_as::<_, (String, String, String, String)>(
        "SELECT * FROM base.get_students_by_username($1)",
    )
    .bind(&req.username)
    .fetch_optional(pool)
    .await
    {
        Ok(Some((lastname, firstname, patronymic, groupp))) => {
            HttpResponse::Ok().json(StudentInfo {
                lastname,
                firstname,
                patronymic,
                groupp,
            })
        }
        Ok(None) => HttpResponse::NotFound().body("Студент не найден"),
        Err(e) => {
            eprintln!("Ошибка получения информации о студенте: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка сервера")
        }
    }
}