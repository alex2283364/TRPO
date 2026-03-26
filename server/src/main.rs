mod models;

use crate::models::{
    BindRoleRequest, ContentOrderItem, Course, CourseContentItem, FileInfo, LoginRequest,
    LoginResponse, StudentInfo, TaskDetails, TaskInfo, TaskResultInfo, TaskTime, UserInfoRequest,
    SetAnswerRequest,
};
use crate::models::{CreateUserRequest, User};
use actix_files as fs;
use actix_files::NamedFile;
use actix_web::web::{Path, Query};
use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use dotenvy::dotenv;
use serde::Deserialize;
use sqlx::postgres::{PgPool, PgPoolOptions};
use std::env;
use std::path::PathBuf;
use actix_multipart::Multipart;
use futures_util::TryStreamExt as _;
use uuid::Uuid;
use std::io::Write;

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
                    return HttpResponse::Conflict()
                        .body("Пользователь с таким именем уже существует");
                }
                if db_err.constraint() == Some("users_email_key") {
                    return HttpResponse::Conflict()
                        .body("Пользователь с таким email уже существует");
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
            "SELECT id, user_name, email, create_at FROM base.users WHERE user_name = $1",
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
                HttpResponse::InternalServerError()
                    .body("Пользователь создан, но не удалось получить данные")
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

async fn bind_role(state: web::Data<AppState>, req: web::Json<BindRoleRequest>) -> impl Responder {
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
        "SELECT * FROM base.get_students_by_username($1)",
    )
    .bind(&req.username)
    .fetch_optional(pool)
    .await;

    match result {
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

async fn get_courses(
    state: web::Data<AppState>,
    req: web::Json<UserInfoRequest>, // { username: String }
) -> impl Responder {
    let pool = &state.student_pool;

    let courses = sqlx::query_as::<_, Course>("SELECT * FROM base.get_courses_by_username($1)")
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
#[derive(Debug, Deserialize)]
pub struct UsernameQuery {
    username: String,
}

async fn get_course_content(
    state: web::Data<AppState>,
    course_id: Path<i32>,
    query: Query<UsernameQuery>,
) -> impl Responder {
    let course_id = course_id.into_inner();
    let username = &query.username;
    let pool = &state.student_pool;

    // 1. Проверить, имеет ли пользователь доступ к этому курсу
    let has_access = sqlx::query_scalar::<_, i32>(
        "SELECT id FROM base.get_courses_by_username($1) WHERE id = $2",
    )
    .bind(username)
    .bind(course_id)
    .fetch_optional(pool)
    .await;

    match has_access {
        Ok(Some(_)) => { /* доступ есть */ }
        Ok(None) => return HttpResponse::Forbidden().body("У вас нет доступа к этому курсу"),
        Err(e) => {
            eprintln!("Ошибка проверки доступа: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка сервера");
        }
    }

    // 2. Получить порядок содержимого из функции get_contentorder_by_course
    let order_items = match sqlx::query_as::<_, ContentOrderItem>(
        "SELECT * FROM base.get_contentorder_by_course($1)",
    )
    .bind(course_id)
    .fetch_all(pool)
    .await
    {
        Ok(items) => items,
        Err(e) => {
            eprintln!("Ошибка получения порядка содержимого: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка получения содержимого");
        }
    };

    // 3. Для каждого элемента получить данные в зависимости от типа
    let mut result = Vec::new();
    let mut text_vec = Vec::new();
    //println!("{}",order_items[0].inventory_id);
    // Получаем текст через функцию get_textcontent_by_inventory
    let text = sqlx::query_scalar::<_, String>(
        "SELECT textсontent FROM base.get_textcontent_by_inventory($1)",
    )
    .bind(order_items[0].inventory_id)
    .fetch_all(pool)
    .await;

    match text {
        Ok(text) => {
            for t in text {
                text_vec.push(Some(t));
            }
        }
        Err(e) => {
            eprintln!("Ошибка получения текста: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка загрузки текста");
        }
    }
    let mut file_vec = Vec::new();
    // Получаем файлы для данного inventory (прямой запрос с id)
    let files = sqlx::query_as::<_, FileInfo>("SELECT * FROM base.get_files_by_inventory($1)")
        .bind(order_items[0].inventory_id)
        .fetch_all(pool)
        .await;

    match files {
        Ok(files) if !files.is_empty() => {
            for f in files {
                //println!("файл помещен {}", f.file_name);
                file_vec.push(Some(f));
            }
        }
        Ok(_) => {
            eprintln!(
                "Предупреждение: для inventory_id {} нет файлов",
                order_items[0].inventory_id
            );
        }
        Err(e) => {
            eprintln!("Ошибка получения файлов: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка загрузки файлов");
        }
    }

    let mut task_vec: Vec<Option<TaskInfo>> = Vec::new();
    // Получаем задания через функцию get_tasks_by_inventory
    let task = sqlx::query_as::<_, TaskInfo>("SELECT * FROM base.get_tasks_by_inventory($1)")
        .bind(order_items[0].inventory_id)
        .fetch_all(pool)
        .await;

    match task {
        Ok(task) if !task.is_empty() => {
            for t in task {
                //println!("Задание помещено {}", t.name);
                task_vec.push(Some(t));
            }
        }
        Ok(_) => {
            eprintln!(
                "Предупреждение: для inventory_id {} нет заданий",
                order_items[0].inventory_id
            );
        }
        Err(e) => {
            eprintln!("Ошибка получения заданий: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка загрузки файлов");
        }
    }
    for item in order_items {
        match item.r#type.as_str() {
            "text" => {
                result.push(CourseContentItem {
                    order: item.content_order,
                    r#type: "text".to_string(),
                    text: text_vec.remove(0),
                    file: None,
                    task: None,
                });
            }
            "file" => {
                result.push(CourseContentItem {
                    order: item.content_order,
                    r#type: "file".to_string(),
                    text: None,
                    file: file_vec.remove(0),
                    task: None,
                });
                //println!("файл извлечен ");
            }
            "task" => {
                result.push(CourseContentItem {
                    order: item.content_order,
                    r#type: "task".to_string(),
                    text: None,
                    file: None,
                    task: task_vec.remove(0),
                });
                //println!("Задание извлечено ");
            }
            _ => {
                eprintln!("Неизвестный тип элемента: {}", item.r#type);
            }
        }
    }

    HttpResponse::Ok().json(result)
}

async fn get_file(state: web::Data<AppState>, file_id: Path<i32>) -> actix_web::Result<NamedFile> {
    let file_id = file_id.into_inner();
    let pool = &state.student_pool;

    let file_info = sqlx::query_as::<_, FileInfo>("SELECT * FROM base.get_file_by_id($1)")
        .bind(file_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| {
            eprintln!("DB error: {:?}", e);
            actix_web::error::ErrorInternalServerError("Database error")
        })?;

    let file_info =
        file_info.ok_or_else(|| actix_web::error::ErrorNotFound("File not found in database"))?;
    let filename = format!("{}.{}", file_info.file_name, file_info.extension);
    let fullpath = format!("{}{}", file_info.path, filename);
    let path = PathBuf::from(&fullpath);
    if !path.exists() {
        eprintln!("File not found on disk: {:?}", path);
        return Err(actix_web::error::ErrorNotFound("File not found on disk"));
    }

    println!("Serving file: {:?} as {}", path, fullpath);

    let file = NamedFile::open(&path).map_err(|e| {
        eprintln!("Failed to open file {:?}: {}", path, e);
        actix_web::error::ErrorInternalServerError("Could not open file")
    })?;

    Ok(file.use_last_modified(true))
}

async fn get_task_details(
    state: web::Data<AppState>,
    task_id: Path<(i32, i32)>,
    query: Query<UsernameQuery>,
) -> impl Responder {
    let params = task_id.into_inner();
    let task_id = params.0;
    let time_id = params.1;
    let username = &query.username;
    let pool = &state.student_pool;
    //println!("{} - {}",task_id,time_id);
    // 1. Получаем временные рамки задания
    let geted_time = sqlx::query_as::<_, TaskTime>("SELECT * FROM base.get_time_by_id($1)")
        .bind(time_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| {
            eprintln!("Ошибка получения времени задания: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка получения времени задания")
        });
    let time;
    match geted_time {
        Ok(geted_time) => {
            time = geted_time;
        }
        Err(e) => {
            eprintln!("Ошибка получения заданий: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка загрузки файлов");
        }
    }
    // 2. Получаем файлы, прикрепленные к заданию
    let geted_task_files =
        sqlx::query_as::<_, FileInfo>("SELECT * FROM base.get_files_by_task($1)")
            .bind(task_id)
            .fetch_all(pool)
            .await
            .map_err(|e| {
                eprintln!("Ошибка получения файлов задания: {:?}", e);
                HttpResponse::InternalServerError().body("Ошибка получения файлов задания")
            });
    let task_files;
    match geted_task_files {
        Ok(geted_task_files) => {
            task_files = geted_task_files;
        }
        Err(e) => {
            eprintln!("Ошибка получения заданий: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка загрузки файлов");
        }
    }
    // 3. Получаем результат выполнения задания пользователем
    let geted_result = sqlx::query_as::<_, TaskResultInfo>(
        "SELECT * FROM base.get_taskresult_by_task_and_user($1, $2)",
    )
    .bind(task_id)
    .bind(username)
    .fetch_optional(pool)
    .await
    .map_err(|e| {
        eprintln!("Ошибка получения результата задания: {:?}", e);
        HttpResponse::InternalServerError().body("Ошибка получения результата задания")
    });
    let result;
    match geted_result {
        Ok(geted_result) => {
            result = geted_result;
        }
        Err(e) => {
            eprintln!("Ошибка получения заданий: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка загрузки файлов");
        }
    }
    // 4. Если результат существует, получаем файлы ответа
    let answer_files = if let Some(ref task_result) = result {
        let taskresult_id = task_result.id;
        match sqlx::query_as::<_, FileInfo>("SELECT * FROM base.get_files_by_answer($1)")
            .bind(taskresult_id)
            .fetch_all(pool)
            .await
        {
            Ok(files) => files,
            Err(e) => {
                eprintln!("Ошибка получения файлов ответа: {:?}", e);
                return HttpResponse::InternalServerError().body("Ошибка получения файлов ответа");
            }
        }
    } else {
        println!("Результат не найден");
        vec![]
    };

    let details = TaskDetails {
        time,
        task_files,
        result,
        answer_files,
    };
    //println!("{}", serde_json::to_string_pretty(&details).unwrap());
    HttpResponse::Ok().json(details)
}

async fn upload_file(
    state: web::Data<AppState>,
    mut payload: Multipart,
) -> impl Responder {
    let mut original_filename = String::new();
    let mut file_data: Option<Vec<u8>> = None;
    let mut extension = String::new();

    // Обрабатываем поля multipart
    loop {
        let mut next_field = match payload.try_next().await {
            Ok(Some(field)) => field,
            Ok(None) => break,
            Err(e) => {
                eprintln!("Ошибка чтения поля: {}", e);
                return HttpResponse::BadRequest().body("Ошибка чтения данных формы");
            }
        };
        let content_disposition = next_field.content_disposition();
        if let Some(name) = content_disposition.get_name() {
            if name == "file" {
                // Получаем имя файла
                if let Some(filename) = content_disposition.get_filename() {
                    if let Some(dot_pos) = filename.rfind('.') {
                        original_filename = filename[..dot_pos].to_string();
                        extension = filename[dot_pos+1..].to_string();
                    } else {
                        original_filename = filename.to_string();
                        extension = "".to_string();
                    }
                }
                // Читаем данные файла
                let mut bytes = Vec::new();
                loop {
                    match next_field.try_next().await {
                        Ok(Some(chunk)) => bytes.extend_from_slice(&chunk),
                        Ok(None) => break,
                        Err(e) => {
                            eprintln!("Ошибка чтения данных файла: {}", e);
                            return HttpResponse::BadRequest().body("Ошибка чтения файла");
                        }
                    }
                }
                file_data = Some(bytes);
            }
        }
    }

    let file_data = match file_data {
        Some(data) => data,
        None => return HttpResponse::BadRequest().body("Файл не передан"),
    };
    let size = file_data.len() as i32;

    // Генерируем UUID для имени файла в базе
    let uuid = Uuid::new_v4();
    let file_name_db = original_filename +"..."+ &uuid.to_string();
    let new_filename = format!("{}.{}", file_name_db, extension);
    let upload_dir = "./file/answers/";
    let full_path = format!("{}{}", upload_dir, new_filename);

    // Создаём директорию, если её нет
    if let Err(e) = std::fs::create_dir_all(upload_dir) {
        eprintln!("Не удалось создать директорию: {}", e);
        return HttpResponse::InternalServerError().body("Ошибка сервера");
    }

    // Сохраняем файл
    if let Err(e) = std::fs::write(&full_path, &file_data) {
        eprintln!("Ошибка сохранения файла: {}", e);
        return HttpResponse::InternalServerError().body("Ошибка сохранения файла");
    }

    // Вызываем функцию базы данных
    let pool = &state.public_pool;
    let file_id = match sqlx::query_scalar::<_, i32>(
        "SELECT base.upload_file($1, $2, $3, $4)"
    )
    .bind(&file_name_db)
    .bind(upload_dir)
    .bind(&extension)
    .bind(size)
    .fetch_one(pool)
    .await {
        Ok(id) => id,
        Err(e) => {
            eprintln!("Ошибка записи в базу данных: {}", e);
            // Удаляем файл, если не удалось записать в БД
            let _ = std::fs::remove_file(&full_path);
            return HttpResponse::InternalServerError().body("Ошибка сохранения в базу данных");
        }
    };

    HttpResponse::Ok().json(serde_json::json!({ "file_id": file_id }))
}

async fn set_answer(
    state: web::Data<AppState>,
    req: web::Json<SetAnswerRequest>,
) -> impl Responder {
    let pool = &state.student_pool;
    let result = sqlx::query_scalar::<_, bool>("SELECT base.set_answer($1, $2, $3, $4, $5)")
        .bind(&req.username)
        .bind(req.answer_id)
        .bind(req.task_id)
        .bind(&req.answertext)
        .bind(req.file_id)
        .fetch_one(pool)
        .await;

    match result {
        Ok(true) => HttpResponse::Ok().json(serde_json::json!({ "success": true })),
        Ok(false) => HttpResponse::BadRequest().json(serde_json::json!({
            "success": false,
            "error": "Не удалось сохранить ответ"
        })),
        Err(e) => {
            eprintln!("Ошибка при сохранении ответа: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка сервера")
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
            .route(
                "/course-content/{course_id}",
                web::get().to(get_course_content),
            )
            .route("/file/{file_id}", web::get().to(get_file))
            .route("/task/{task_id}/{time_id}", web::get().to(get_task_details))
            .route("/set-answer", web::post().to(set_answer))
            .route("/upload", web::post().to(upload_file))
            .service(fs::Files::new("/", "./static").index_file("index.html"))
    })
    .bind(("127.0.0.1", 8080))?
    .run()
    .await
}
