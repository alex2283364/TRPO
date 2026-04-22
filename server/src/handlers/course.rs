//! Обработчики для работы с курсами, их содержимым и файлами.

use actix_files::NamedFile;
use actix_web::{web, HttpResponse, Responder, Result as ActixResult};
use crate::models::{
    ContentOrderItem, Course, CourseContentItem, FileInfo, TaskDetails, TaskInfo, TaskTime,
    TaskResultInfo, UsernameQuery, UserInfoRequest, TestInfo, TestQuestion, AnswerOption,
    TestQuestionWithOption, AnswerValue, TestResultResponse, CombinedQuestion, SubmitTestRequest,
    BestResultRequest, BestResultResponse, TaskResultIdRequest, CommentInfo, ExtendedComment,
    TeacherInfo,
};
use crate::state::AppState;
use std::path::PathBuf;
use serde_json::json;
use sqlx::{Error, database};
use std::collections::{HashMap, HashSet};

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
    let mut test_vec = Vec::new(); // новый вектор для тестов

    // Загружаем данные для первого элемента (сохраняем существующую логику)
    if let Some(first) = order_items.first() {
        // Текст
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

        // Файлы
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

        // Задания
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

        // загрузка тестов 
        let tests = sqlx::query_as::<_, TestInfo>("SELECT * FROM base.get_tests_by_inventory($1)")
            .bind(first.inventory_id)
            .fetch_all(pool)
            .await;
        match tests {
            Ok(tests) => test_vec.extend(tests.into_iter().map(Some)),
            Err(e) => {
                eprintln!("Ошибка получения тестов: {:?}", e);
                return HttpResponse::InternalServerError().body("Ошибка загрузки тестов");
            }
        }
    }

    // Формирование результата в соответствии с порядком
    for item in order_items {
        match item.r#type.as_str() {
            "text" => {
                result.push(CourseContentItem {
                    order: item.content_order,
                    r#type: "text".to_string(),
                    text: text_vec.remove(0),
                    file: None,
                    task: None,
                    test: None, // добавить поле в структуру
                });
            }
            "file" => {
                result.push(CourseContentItem {
                    order: item.content_order,
                    r#type: "file".to_string(),
                    text: None,
                    file: file_vec.remove(0),
                    task: None,
                    test: None,
                });
            }
            "task" => {
                result.push(CourseContentItem {
                    order: item.content_order,
                    r#type: "task".to_string(),
                    text: None,
                    file: None,
                    task: task_vec.remove(0),
                    test: None,
                });
            }
            "test" => { // новый тип
                result.push(CourseContentItem {
                    order: item.content_order,
                    r#type: "test".to_string(),
                    text: None,
                    file: None,
                    task: None,
                    test: test_vec.remove(0),
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

impl From<TestQuestion> for TestQuestionWithOption {
    fn from(question: TestQuestion) -> Self {
        Self {
            id: question.id,
            question_text: question.question_text,
            question_type: question.question_type,
            points: question.points,
            sort_order: question.sort_order,
            options: Vec::new(),
        }
    }
}

/// Получение всех вопросов теста по его ID
pub async fn get_test_questions_and_start(
    state: web::Data<AppState>,
    test_id: web::Path<i32>,
    query: web::Query<UsernameQuery>, // получаем username из query
) -> impl Responder {
    let test_id = test_id.into_inner();
    let username = &query.username;
    let pool = &state.student_pool;
    println!("Начало загрузки теста");
    if username.is_empty() {
        return HttpResponse::BadRequest().body("Username is required");
    }

    // 2. Количество предыдущих попыток
    let attempt_count: i32 = match sqlx::query_scalar("SELECT base.get_attempt_count($1, $2)")
        .bind(test_id)
        .bind(username)
        .fetch_one(pool)
        .await
    {
        Ok(count) => count,
        Err(e) => {
            eprintln!("Ошибка получения количества попыток: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка сервера");
        }
    };
    println!("Количество попыток: {}", attempt_count);
    let new_attempt_number = (attempt_count as i32) + 1;

    // 3. Создаём попытку через insert_test_attempt (принимает username)
    let attempt_id: i32 = match sqlx::query_scalar(
        "SELECT base.insert_test_attempt($1, $2, $3)"
    )
    .bind(test_id)
    .bind(username)
    .bind(new_attempt_number)
    .fetch_one(pool)
    .await
    {
        Ok(id) => id,
        Err(Error::Database(db_err)) => {
            let err_msg = db_err.message();
            eprintln!("Ошибка БД при создании попытки: {}", err_msg);
            if err_msg.contains("exceeded") || err_msg.contains("attempts") {
                return HttpResponse::Forbidden().json(json!({
                    "error": "Достигнуто максимальное количество попыток"
                }));
            } else if err_msg.contains("not found") {
                return HttpResponse::NotFound().json(json!({
                    "error": "Пользователь или тест не найдены"
                }));
            }
            return HttpResponse::InternalServerError().body("Ошибка сервера");
        }
        Err(e) => {
            eprintln!("Неожиданная ошибка: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка сервера");
        }
    };

    // 4. Загружаем вопросы теста
    let mut questions = match sqlx::query_as::<_, TestQuestion>(
        "SELECT * FROM base.get_question_by_test($1)"
    )
    .bind(test_id)
    .fetch_all(pool)
    .await
    {
        Ok(q) => q,
        Err(e) => {
            eprintln!("Ошибка получения вопросов теста: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка загрузки вопросов теста");
        }
    };

    let mut questions_with_options: Vec<TestQuestionWithOption> = questions
    .into_iter()
    .map(Into::into) // или .map(|q| q.into())
    .collect();

    // 5. Для каждого вопроса загружаем варианты ответов
    for question in &mut questions_with_options {
        match sqlx::query_as::<_, AnswerOption>("SELECT * FROM base.get_option_by_question($1)")
            .bind(question.id)
            .fetch_all(pool)
            .await
        {
            Ok(options) => {
                question.options = options;
            }
            Err(e) => {
                eprintln!("Ошибка получения вариантов ответов для вопроса {}: {:?}", question.id, e);
                // Можно продолжить без вариантов, но лучше вернуть ошибку
                return HttpResponse::InternalServerError().body("Ошибка загрузки вариантов ответов");
            }
        }
    }

    // 6. Возвращаем attempt_id и вопросы (с вариантами ответов)
    HttpResponse::Ok().json(json!({
        "attempt_id": attempt_id,
        "attempt_number": new_attempt_number,
        "questions": questions_with_options
    }))
}

pub async fn submit_test(
    state: web::Data<AppState>,
    req: web::Json<SubmitTestRequest>,
) -> impl Responder {
    println!("{}", req.test_id);
    let pool = &state.student_pool;
    let test_id = req.test_id;
    let attempt_id = req.attempt_id;
    let answers = &req.answers;

    
    // 2. Получаем правильные ответы и баллы за каждый вопрос теста
    

    let combined_questions= match sqlx::query_as::<_, CombinedQuestion>(
        "SELECT * FROM base.get_combined_questions($1)"
    )
    .bind(test_id)
    .fetch_all(pool)
    .await{
        Ok(questions) => questions,
        Err(e) => {
            eprintln!("Ошибка получения правильных ответов: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка загрузки данных теста");
        }
    };

    // Создаём HashMap для быстрого поиска правильного ответа и баллов по question_id
    
        let mut right_answers_map: HashMap<i32, (Vec<String>, i32)> = HashMap::new();
    for cq in combined_questions {
        let entry = right_answers_map.entry(cq.id).or_insert_with(|| (Vec::new(), cq.question_points));
        entry.0.push(cq.right_answer);
    }
    // 3. Подсчитываем набранные баллы и максимальный балл
    let max_points: i32 = right_answers_map.values().map(|(_, points)| points).sum();
    let mut total_points = 0;

    // Для каждого ответа клиента проверяем правильность
    for answer in answers {
        let question_id = answer.question_id;
        if let Some((right_answers_vec, points)) = right_answers_map.get(&question_id) {
            let is_correct = match &answer.answer {
                AnswerValue::Single(opt_id) => {
                    // Для single_choice: правильный ответ — sort_order выбранного варианта
                    right_answers_vec.len() == 1 && 
                    right_answers_vec[0].parse::<i32>().ok() == Some(*opt_id)
                }
                AnswerValue::Multiple(opt_ids) => {
                    
                    let right_set: std::collections::HashSet<i32> = right_answers_vec
                        .iter()
                        .filter_map(|s| s.parse::<i32>().ok())
                        .collect();
                    let user_set: std::collections::HashSet<i32> = opt_ids.iter().cloned().collect();
                    user_set == right_set
                }
                AnswerValue::Text(text) => {
                   if right_answers_vec.len() == 1 {
                        text.trim().eq_ignore_ascii_case(right_answers_vec[0].trim())
                    } else {
                        false
                    }
                }
            };
            if is_correct {
                total_points += points;
            }
        } else {
            eprintln!("Вопрос с id {} не найден в тесте", question_id);
        }
    }
    // 5. Завершаем попытку, вызывая complete_test_attempt
    if let Err(e) = sqlx::query("SELECT base.complete_test_attempt($1, $2, $3)")
        .bind(attempt_id)
        .bind(total_points)
        .bind(max_points)
        .execute(pool)
        .await{
             match e {
                sqlx::Error::Database(db_err) => {
                eprintln!("Ошибка завершения попытки: {:?}", db_err);
                return HttpResponse::InternalServerError().body("Ошибка загрузки данных теста");
                }
                _ => {
                eprintln!("Неизвестная ошибка: {:?}", e);
                return HttpResponse::InternalServerError().body("Внутренняя ошибка сервера");
               } 
             }
        } else{
            ;
        }

    // 6. Возвращаем результат
    HttpResponse::Ok().json(TestResultResponse {
        score: total_points,
        max_score: max_points,
    })
}

pub async fn get_best_test_result(
    state: web::Data<AppState>,
    req: web::Json<BestResultRequest>,
) -> impl Responder {
    let pool = &state.student_pool;

    let result = sqlx::query_as::<_, BestResultResponse>(
        "SELECT * FROM base.get_best_test_result($1, $2)"
    )
    .bind(&req.username)
    .bind(req.test_id)
    .fetch_optional(pool)
    .await;

    match result {
        Ok(Some(row)) => HttpResponse::Ok().json(BestResultResponse {
            total_points: row.total_points,
            max_points: row.max_points,
            percentage: row.percentage,
            completed_at: row.completed_at,
        }),
        Ok(None) => {
            HttpResponse::NotFound().body("Результат не найден")
        }
        Err(e) => {
            eprintln!("Ошибка получения лучшего результата: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка сервера")
        }
    }
}

/// Получение комментариев по taskresult_id с дополнительной информацией о преподавателе
pub async fn get_comments_by_taskresult(
    state: web::Data<AppState>,
    req: web::Json<TaskResultIdRequest>,
) -> impl Responder {
    let pool = &state.public_pool;

    // 1. Получаем базовые комментарии (user_name, comment_text, comment_date)
    let comments = match sqlx::query_as::<_, CommentInfo>(
        "SELECT * FROM base.get_comments_by_taskresult($1)"
    )
    .bind(req.taskresult_id)
    .fetch_all(pool)
    .await
    {
        Ok(comments) => comments,
        Err(e) => {
            eprintln!("Ошибка получения комментариев: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка получения комментариев");
        }
    };

    if comments.is_empty() {
        return HttpResponse::Ok().json(Vec::<ExtendedComment>::new());
    }

    // 2. Для каждого комментария получаем ФИО преподавателя
    let mut extended_comments = Vec::new();
    for comment in comments {
        let teacher_info = match sqlx::query_as::<_, (String, String, String)>(
            "SELECT * FROM base.get_teacher_by_username($1)"
        )
        .bind(&comment.user_name)
        .fetch_optional(pool)
        .await
        {
            Ok(Some((lastname, firstname, patronymic))) => TeacherInfo {
                lastname,
                firstname,
                patronymic,
            },
            Ok(None) => {
                eprintln!("Преподаватель с username {} не найден", comment.user_name);
                // Можно вернуть заглушку или пропустить комментарий
                TeacherInfo {
                    lastname: comment.user_name.clone(),
                    firstname: "".to_string(),
                    patronymic: "".to_string(),
                }
            }
            Err(e) => {
                eprintln!("Ошибка получения информации о преподавателе {}: {:?}", comment.user_name, e);
                TeacherInfo {
                    lastname: comment.user_name.clone(),
                    firstname: "".to_string(),
                    patronymic: "".to_string(),
                }
            }
        };

        extended_comments.push(ExtendedComment {
            user_name: comment.user_name,
            lastname: teacher_info.lastname,
            firstname: teacher_info.firstname,
            patronymic: teacher_info.patronymic,
            comment_text: comment.comment_text,
            comment_date: comment.comment_date,
        });
    }

    HttpResponse::Ok().json(extended_comments)
}