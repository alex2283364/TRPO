use actix_web::{web, HttpResponse, Responder};
use crate::models::{UserInfoRequest, TeacherInfo, Course, CourseIdRequest, StudentInfoCourse, GroupInfo,
                    TaskResultFullInfo, TaskResultRaw, TaskIdRequest, FileInfo, UpdateTaskValidationRequest,
                TestIdRequest, TestStudentResult};
use crate::state::AppState;
use serde_json::json;

/// Получение информации о преподавателе (фамилия, имя, отчество) по имени пользователя.
pub async fn get_teacher_info(
    state: web::Data<AppState>,
    req: web::Json<UserInfoRequest>,
) -> impl Responder {
    let pool = &state.public_pool; // используем пул с правами public
    match sqlx::query_as::<_, (String, String, String)>(
        "SELECT * FROM base.get_teacher_by_username($1)"
    )
    .bind(&req.username)
    .fetch_optional(pool)
    .await
    {
        Ok(Some((lastname, firstname, patronymic))) => {
            HttpResponse::Ok().json(TeacherInfo {
                lastname,
                firstname,
                patronymic,
            })
        }
        Ok(None) => HttpResponse::NotFound().body("Преподаватель не найден"),
        Err(e) => {
            eprintln!("Ошибка получения информации о преподавателе: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка сервера")
        }
    }
}

pub async fn get_courses_teacher(
    state: web::Data<AppState>,
    req: web::Json<UserInfoRequest>,
) -> impl Responder {
    let pool = &state.public_pool; // используем пул с правами public (функция SECURITY DEFINER)
    match sqlx::query_as::<_, Course>("SELECT * FROM base.get_courses_by_teacher($1)")
        .bind(&req.username)
        .fetch_all(pool)
        .await
    {
        Ok(courses) => HttpResponse::Ok().json(courses),
        Err(e) => {
            eprintln!("Ошибка получения курсов преподавателя: {:?}", e);
            HttpResponse::InternalServerError().body("Ошибка получения курсов")
        }
    }
}

pub async fn get_course_groups_with_students(
    state: web::Data<AppState>,
    req: web::Json<CourseIdRequest>,
) -> impl Responder {
    let pool = &state.public_pool;
    let course_id = req.course_id;

    // 1. Получить все группы, связанные с курсом
    let groups = match sqlx::query_as::<_, (i32, String, String, i32)>(
        "SELECT * FROM base.get_group_by_course($1)"
    )
    .bind(course_id)
    .fetch_all(pool)
    .await
    {
        Ok(rows) => rows,
        Err(e) => {
            eprintln!("Ошибка получения групп для курса {}: {:?}", course_id, e);
            return HttpResponse::InternalServerError().body("Ошибка получения групп");
        }
    };

    if groups.is_empty() {
        return HttpResponse::Ok().json(Vec::<GroupInfo>::new());
    }

    let mut result = Vec::new();

    // 2. Для каждой группы получаем студентов
    for (group_id, group_name, academic_year, max_students) in groups {
        let students = match sqlx::query_as::<_, (String, String, String, String, String, String)>(
            "SELECT * FROM base.get_students_by_group($1)"
        )
        .bind(group_id)
        .fetch_all(pool)
        .await
        {
            Ok(rows) => rows
                .into_iter()
                .map(|(user_name, lastname, firstname, patronymic, student_code, group_name)| {
                    StudentInfoCourse {
                        user_name,
                        lastname,
                        firstname,
                        patronymic,
                        student_code,
                        group_name,
                    }
                })
                .collect(),
            Err(e) => {
                eprintln!("Ошибка получения студентов для группы {}: {:?}", group_id, e);
                // Пропускаем группу, если не удалось получить студентов (или можно вернуть ошибку)
                continue;
            }
        };

        result.push(GroupInfo {
            id: group_id,
            name: group_name,
            academic_year,
            max_students,
            students,
        });
    }

    HttpResponse::Ok().json(result)
}

pub async fn get_task_results(
    state: web::Data<AppState>,
    req: web::Json<TaskIdRequest>,
) -> impl Responder {
    let pool = &state.public_pool;
    let task_id = req.task_id;

    // 1. Получаем базовые результаты задания из БД
    let raw_results = match sqlx::query_as::<_, TaskResultRaw>(
        "SELECT * FROM base.get_task_results($1)"
    )
    .bind(task_id)
    .fetch_all(pool)
    .await
    {
        Ok(results) => results,
        Err(e) => {
            eprintln!("Ошибка получения результатов задания {}: {:?}", task_id, e);
            return HttpResponse::InternalServerError().body("Ошибка получения результатов задания");
        }
    };

    if raw_results.is_empty() {
        return HttpResponse::Ok().json(Vec::<TaskResultFullInfo>::new());
    }

    let mut final_results = Vec::new();

    // 2. Для каждого результата получаем информацию о студенте и файлах
    for raw in raw_results {
        // Получаем информацию о студенте
        let student_info = match sqlx::query_as::<_, (String, String, String, String)>(
            "SELECT * FROM base.get_students_by_username($1)"
        )
        .bind(&raw.user_name)
        .fetch_optional(pool)
        .await
        {
            Ok(Some((lastname, firstname, patronymic, groupp))) => {
                (lastname, firstname, patronymic, groupp)
            }
            Ok(None) => {
                eprintln!("Студент с username {} не найден", raw.user_name);
                continue;
            }
            Err(e) => {
                eprintln!("Ошибка получения информации о студенте {}: {:?}", raw.user_name, e);
                continue;
            }
        };

        // Получаем файлы ответа для данного result_id
        let answer_files = match sqlx::query_as::<_, FileInfo>(
            "SELECT * FROM base.get_files_by_answer($1)"
        )
        .bind(raw.result_id)
        .fetch_all(pool)
        .await
        {
            Ok(files) => files,
            Err(e) => {
                eprintln!("Ошибка получения файлов ответа для result_id {}: {:?}", raw.result_id, e);
                vec![] // продолжаем без файлов, чтобы не терять остальные данные
            }
        };

        final_results.push(TaskResultFullInfo {
            user_name: raw.user_name,
            result_id: raw.result_id,
            lastname: student_info.0,
            firstname: student_info.1,
            patronymic: student_info.2,
            groupp: student_info.3,
            answertext: raw.answertext,
            result: raw.result,
            answer_files,
            validation: raw.validation,
            validation_status: raw.validation_status,
        });
    }

    HttpResponse::Ok().json(final_results)
}

pub async fn update_task_validation(
    state: web::Data<AppState>,
    req: web::Json<UpdateTaskValidationRequest>,
) -> impl Responder {
    let pool = &state.public_pool;
    let mut tx = match pool.begin().await {
        Ok(tx) => tx,
        Err(e) => {
            eprintln!("Ошибка начала транзакции: {:?}", e);
            return HttpResponse::InternalServerError().body("Ошибка сервера");
        }
    };

    // 1. Вызов функции create_validation_and_update_taskresult
    let validation_id = match sqlx::query_scalar::<_, i32>(
        "SELECT base.create_validation_and_update_taskresult($1, $2, $3, $4, $5)"
    )
    .bind(&req.validation)
    .bind(&req.result)
    .bind(req.task_id)
    .bind(req.task_result_id)
    .bind(&req.username)
    .fetch_one(&mut *tx)
    .await
    {
        Ok(id) => id,
        Err(sqlx::Error::Database(db_err)) => {
            let msg = db_err.to_string();
            eprintln!("Ошибка БД при обновлении проверки: {}", msg);
            let _ = tx.rollback().await;
            if msg.contains("не найден") || msg.contains("not found") {
                return HttpResponse::NotFound().body(msg);
            }
            return HttpResponse::InternalServerError().body("Ошибка базы данных");
        }
        Err(e) => {
            eprintln!("Неизвестная ошибка: {:?}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().body("Внутренняя ошибка сервера");
        }
    };

    // 2. Если передан комментарий, добавляем его
    let comment_id = if let Some(ref comment_text) = req.comment_text {
        if !comment_text.trim().is_empty() {
            match sqlx::query_scalar::<_, i32>(
                "SELECT base.add_comment_to_taskresult($1, $2, $3)"
            )
            .bind(&req.username)
            .bind(req.task_result_id)
            .bind(comment_text)
            .fetch_one(&mut *tx)
            .await
            {
                Ok(id) => Some(id),
                Err(e) => {
                    eprintln!("Ошибка добавления комментария: {:?}", e);
                    let _ = tx.rollback().await;
                    return HttpResponse::InternalServerError().body("Ошибка добавления комментария");
                }
            }
        } else {
            None
        }
    } else {
        None
    };

    // Коммит транзакции
    if let Err(e) = tx.commit().await {
        eprintln!("Ошибка коммита транзакции: {:?}", e);
        return HttpResponse::InternalServerError().body("Ошибка сохранения");
    }

    HttpResponse::Ok().json(json!({
        "success": true,
        "validation_id": validation_id,
        "comment_id": comment_id,
        "message": "Статус проверки и комментарий сохранены"
    }))
}

pub async fn get_test_results(
    state: web::Data<AppState>,
    req: web::Json<TestIdRequest>,
) -> impl Responder {
    let pool = &state.public_pool;
    let test_id = req.test_id;

    // 1. Получаем список (user_name, total_points, max_points, percentage) из функции БД
    // Предполагается, что функция возвращает все строки, а не только лучшую (LIMIT 1 убран).
    // Если в БД функция всё же содержит LIMIT 1, результат будет содержать только одну запись.
    let raw_results = match sqlx::query_as::<_, (String, i32, i32, f32)>(
        "SELECT * FROM base.get_test_results_by_test_id($1)"
    )
    .bind(test_id)
    .fetch_all(pool)
    .await
    {
        Ok(rows) => rows,
        Err(e) => {
            eprintln!("Ошибка получения результатов теста {}: {:?}", test_id, e);
            return HttpResponse::InternalServerError().body("Ошибка получения результатов теста");
        }
    };

    if raw_results.is_empty() {
        return HttpResponse::Ok().json(Vec::<TestStudentResult>::new());
    }

    let mut final_results = Vec::new();

    // 2. Для каждой записи получаем данные студента через get_students_by_username
    for (user_name, total_points, max_points, percentage) in raw_results {
        let student_info = match sqlx::query_as::<_, (String, String, String, String)>(
            "SELECT * FROM base.get_students_by_username($1)"
        )
        .bind(&user_name)
        .fetch_optional(pool)
        .await
        {
            Ok(Some((lastname, firstname, patronymic, groupp))) => {
                (lastname, firstname, patronymic, groupp)
            }
            Ok(None) => {
                eprintln!("Студент с username {} не найден", user_name);
                continue;
            }
            Err(e) => {
                eprintln!("Ошибка получения информации о студенте {}: {:?}", user_name, e);
                continue;
            }
        };

        final_results.push(TestStudentResult {
            lastname: student_info.0,
            firstname: student_info.1,
            patronymic: student_info.2,
            groupp: student_info.3,
            total_points,
            max_points,
            percentage,
        });
    }

    HttpResponse::Ok().json(final_results)
}