//! Обработчики для отправки ответов на задания и загрузки файлов.

use actix_multipart::Multipart;
use actix_web::{web, HttpResponse, Responder};
use futures_util::TryStreamExt as _;
use uuid::Uuid;
use std::io::Write;
use crate::models::SetAnswerRequest;
use crate::state::AppState;
use serde_json::json;

/// Загрузка файла ответа на задание.
pub async fn upload_file(
    state: web::Data<AppState>,
    mut payload: Multipart,
) -> impl Responder {
    let mut original_filename = String::new();
    let mut file_data: Option<Vec<u8>> = None;
    let mut extension = String::new();

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
                if let Some(filename) = content_disposition.get_filename() {
                    if let Some(dot_pos) = filename.rfind('.') {
                        original_filename = filename[..dot_pos].to_string();
                        extension = filename[dot_pos + 1..].to_string();
                    } else {
                        original_filename = filename.to_string();
                        extension = "".to_string();
                    }
                }
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

    let uuid = Uuid::new_v4();
    let file_name_db = original_filename + "..." + &uuid.to_string();
    let new_filename = format!("{}.{}", file_name_db, extension);
    let upload_dir = "./file/answers/";
    let full_path = format!("{}{}", upload_dir, new_filename);

    if let Err(e) = std::fs::create_dir_all(upload_dir) {
        eprintln!("Не удалось создать директорию: {}", e);
        return HttpResponse::InternalServerError().body("Ошибка сервера");
    }

    if let Err(e) = std::fs::write(&full_path, &file_data) {
        eprintln!("Ошибка сохранения файла: {}", e);
        return HttpResponse::InternalServerError().body("Ошибка сохранения файла");
    }

    let pool = &state.public_pool;
    let file_id = match sqlx::query_scalar::<_, i32>("SELECT base.upload_file($1, $2, $3, $4)")
        .bind(&file_name_db)
        .bind(upload_dir)
        .bind(&extension)
        .bind(size)
        .fetch_one(pool)
        .await
    {
        Ok(id) => id,
        Err(e) => {
            eprintln!("Ошибка записи в базу данных: {}", e);
            let _ = std::fs::remove_file(&full_path);
            return HttpResponse::InternalServerError().body("Ошибка сохранения в базу данных");
        }
    };

    HttpResponse::Ok().json(json!({ "file_id": file_id }))
}

/// Сохранение ответа на задание (текст и/или файл).
pub async fn set_answer(
    state: web::Data<AppState>,
    req: web::Json<SetAnswerRequest>,
) -> impl Responder {
    let pool = &state.student_pool;
    match sqlx::query_scalar::<_, bool>("SELECT base.set_answer($1, $2, $3, $4, $5)")
        .bind(&req.username)
        .bind(req.answer_id)
        .bind(req.task_id)
        .bind(&req.answertext)
        .bind(req.file_id)
        .fetch_one(pool)
        .await
    {
        Ok(true) => HttpResponse::Ok().json(json!({ "success": true })),
        Ok(false) => HttpResponse::BadRequest().json(json!({
            "success": false,
            "error": "Не удалось сохранить ответ"
        })),
        Err(e) => {
            eprintln!("Ошибка при сохранении ответа: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка сервера")
        }
    }
}