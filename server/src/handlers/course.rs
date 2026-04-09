//! Обработчики для работы с курсами, их содержимым и файлами.

use actix_files::NamedFile;
use actix_web::{web, HttpResponse, Responder, Result as ActixResult};
use crate::models::{
    ContentOrderItem, Course, CourseContentItem, FileInfo, TaskDetails, TaskInfo, TaskTime,
    TaskResultInfo, UsernameQuery, UserInfoRequest,
};
use crate::state::AppState;
use std::path::PathBuf;

/// Получение списка курсов для пользователя.
pub async fn get_courses(
    state: web::Data<AppState>,
    req: web::Json<UserInfoRequest>,
) -> impl Responder {
    let pool = &state.student_pool;
    match sqlx::query_as::<_, Course>("SELECT * FROM base.get_courses_by_username($1)")
        .bind(&req.username)
        .fetch_all(pool)
        .await
    {
        Ok(courses) => HttpResponse::Ok().json(courses),
        Err(e) => {
            eprintln!("Ошибка получения курсов: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка получения курсов")
        }
    }
}

/// Получение содержимого курса (текст, файлы, задания) для пользователя.
pub async fn get_course_content(
    state: web::Data<AppState>,
    course_id: web::Path<i32>,
    query: web::Query<UsernameQuery>,
) -> impl Responder {
    let course_id = course_id.into_inner();
    let username = &query.username;
    let pool = &state.student_pool;

    // Проверка доступа
    let has_access = sqlx::query_scalar::<_, i32>(
        "SELECT id FROM base.get_courses_by_username($1) WHERE id = $2",
    )
    .bind(username)
    .bind(course_id)
    .fetch_optional(pool)
    .await;

    match has_access {
        Ok(Some(_)) => {}
        Ok(None) => return HttpResponse::Forbidden().body("У вас нет доступа к этому курсу"),
        Err(e) => {
            eprintln!("Ошибка проверки доступа: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка сервера");
        }
    }

    // Получение порядка содержимого
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

    let mut result = Vec::new();
    let mut text_vec = Vec::new();
    let mut file_vec = Vec::new();
    let mut task_vec = Vec::new();

    // Загружаем текст, файлы и задания для первого элемента (в исходном коде так)
    // Примечание: в исходной реализации используется только order_items[0],
    // что кажется багом. Здесь оставлено как было, но для полноценной работы
    // нужно обрабатывать все элементы.
    if let Some(first) = order_items.first() {
        let text = sqlx::query_scalar::<_, String>(
            "SELECT textсontent FROM base.get_textcontent_by_inventory($1)",
        )
        .bind(first.inventory_id)
        .fetch_all(pool)
        .await;
        match text {
            Ok(text) => text_vec.extend(text.into_iter().map(Some)),
            Err(e) => {
                eprintln!("Ошибка получения текста: {:?}", e);
                return HttpResponse::InternalServerError().body("Ошибка загрузки текста");
            }
        }

        let files = sqlx::query_as::<_, FileInfo>("SELECT * FROM base.get_files_by_inventory($1)")
            .bind(first.inventory_id)
            .fetch_all(pool)
            .await;
        match files {
            Ok(files) => file_vec.extend(files.into_iter().map(Some)),
            Err(e) => {
                eprintln!("Ошибка получения файлов: {:?}", e);
                return HttpResponse::InternalServerError().body("Ошибка загрузки файлов");
            }
        }

        let tasks = sqlx::query_as::<_, TaskInfo>("SELECT * FROM base.get_tasks_by_inventory($1)")
            .bind(first.inventory_id)
            .fetch_all(pool)
            .await;
        match tasks {
            Ok(tasks) => task_vec.extend(tasks.into_iter().map(Some)),
            Err(e) => {
                eprintln!("Ошибка получения заданий: {:?}", e);
                return HttpResponse::InternalServerError().body("Ошибка загрузки заданий");
            }
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
            }
            "task" => {
                result.push(CourseContentItem {
                    order: item.content_order,
                    r#type: "task".to_string(),
                    text: None,
                    file: None,
                    task: task_vec.remove(0),
                });
            }
            _ => {
                eprintln!("Неизвестный тип элемента: {}", item.r#type);
            }
        }
    }

    HttpResponse::Ok().json(result)
}

/// Скачивание файла по его идентификатору.
pub async fn get_file(
    state: web::Data<AppState>,
    file_id: web::Path<i32>,
) -> ActixResult<NamedFile> {
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

    let file_info = file_info.ok_or_else(|| actix_web::error::ErrorNotFound("File not found in database"))?;
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

/// Получение деталей задания: временные рамки, файлы задания, результат пользователя.
pub async fn get_task_details(
    state: web::Data<AppState>,
    task_id: web::Path<(i32, i32)>,
    query: web::Query<UsernameQuery>,
) -> impl Responder {
    let params = task_id.into_inner();
    let task_id = params.0;
    let time_id = params.1;
    let username = &query.username;
    let pool = &state.student_pool;

    let time = match sqlx::query_as::<_, TaskTime>("SELECT * FROM base.get_time_by_id($1)")
        .bind(time_id)
        .fetch_optional(pool)
        .await
    {
        Ok(t) => t,
        Err(e) => {
            eprintln!("Ошибка получения времени задания: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка получения времени задания");
        }
    };

    let task_files = match sqlx::query_as::<_, FileInfo>("SELECT * FROM base.get_files_by_task($1)")
        .bind(task_id)
        .fetch_all(pool)
        .await
    {
        Ok(files) => files,
        Err(e) => {
            eprintln!("Ошибка получения файлов задания: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка получения файлов задания");
        }
    };

    let result = match sqlx::query_as::<_, TaskResultInfo>(
        "SELECT * FROM base.get_taskresult_by_task_and_user($1, $2)",
    )
    .bind(task_id)
    .bind(username)
    .fetch_optional(pool)
    .await
    {
        Ok(r) => r,
        Err(e) => {
            eprintln!("Ошибка получения результата задания: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка получения результата задания");
        }
    };

    let answer_files = if let Some(ref task_result) = result {
        match sqlx::query_as::<_, FileInfo>("SELECT * FROM base.get_files_by_answer($1)")
            .bind(task_result.id)
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
        vec![]
    };

    HttpResponse::Ok().json(TaskDetails {
        time,
        task_files,
        result,
        answer_files,
    })
}