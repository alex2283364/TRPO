use chrono::NaiveDate;
use chrono::NaiveDateTime;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct User {
    pub id: i32,
    pub user_name: String, // соответствует колонке в БД
    pub email: String,
    pub create_at: NaiveDateTime,
}

#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub username: String, // входное поле (можно назвать иначе, но в БД пойдёт как user_name)
    pub email: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub login: String, // может быть user_name или email
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct BindRoleRequest {
    pub login: String,
    pub role_password: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub authenticated: bool,
    pub role_bound: bool,
    pub role_type: Option<String>, // новое поле – тип роли (если есть)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub token: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct StudentInfo {
    pub lastname: String,
    pub firstname: String,
    pub patronymic: String,
    pub groupp: String,
}

#[derive(Debug, Deserialize)]
pub struct UserInfoRequest {
    pub username: String,
}

#[derive(Debug, serde::Serialize, serde::Deserialize, sqlx::FromRow)]
pub struct Course {
    pub id: i32,
    pub name: String,
    pub description: String,
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
}

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct ContentOrderItem {
    pub content_order: i32, // порядок элемента
    pub inventory_id: i32,  // идентификатор элемента в inventory
    pub r#type: String,     // "text" или "file"
}

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct FileInfo {
    pub id: i32, // идентификатор файла (для скачивания)
    pub file_name: String,
    pub extension: String,
    pub path: String,
}

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct TaskInfo {
    pub id: i32, // идентификатор файла (для скачивания)
    pub time_id: i32,
    pub name: String,
    pub qdescription: String,
    pub adescription: String,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct TestInfo {
    pub id: i32,
    pub title: String,
    pub description: Option<String>,
    pub time_limit_seconds: Option<i32>,
    pub max_attempts: i32,
}

// Составной ответ для клиента
#[derive(Debug, Serialize)]
pub struct CourseContentItem {
    pub order: i32,
    pub r#type: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub file: Option<FileInfo>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub task: Option<TaskInfo>,
    pub test: Option<TestInfo>,
}

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct TaskTime {
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
}

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct TaskResultInfo {
    pub id: i32,
    pub validation: String,
    pub create_date: NaiveDateTime,
    pub result: Option<String>,
    pub answertext: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TaskDetails {
    pub time: Option<TaskTime>,
    pub task_files: Vec<FileInfo>,
    pub result: Option<TaskResultInfo>,
    pub answer_files: Vec<FileInfo>,
}

#[derive(Debug, Deserialize)]
pub struct SetAnswerRequest {
    pub username: String,
    pub answer_id: i32,
    pub task_id: i32,
    pub answertext: String,
    pub file_id: i32,
}

/// Структура для извлечения параметра username из строки запроса.
#[derive(Debug, Deserialize)]
pub struct UsernameQuery {
    pub username: String,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct AnswerOption {
    pub id: i32,
    pub option_text: String,
    pub sort_order: i32,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct TestQuestion {
    pub id: i32,
    pub question_text: String,
    pub question_type: String, // single_choice, multiple_choice, text
    pub points: i32,
    pub sort_order: i32,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TestQuestionWithOption {
    pub id: i32,
    pub question_text: String,
    pub question_type: String, // single_choice, multiple_choice, text
    pub points: i32,
    pub sort_order: i32,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub options: Vec<AnswerOption>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SubmitTestRequest {
    pub test_id: i32,
    pub attempt_id: i32,
    pub answers: Vec<TestAnswer>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TestAnswer {
    pub question_id: i32,
    pub answer: AnswerValue,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(untagged)]
pub enum AnswerValue {
    Single(i32), // для single_choice - id выбранного варианта (sort_order)
    Multiple(Vec<i32>), // для multiple_choice - массив sort_order выбранных вариантов
    Text(String), // для текстового ответа
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TestResultResponse {
    pub score: i32,
    pub max_score: i32,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct CombinedQuestion {
    pub id: i32,
    pub question_type: String,
    pub question_points: i32,
    pub right_answer: String,
}

#[derive(Debug, Deserialize)]
pub struct BestResultRequest {
    pub username: String,
    pub test_id: i32,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct BestResultResponse {
    pub total_points: i32,
    pub max_points: i32,
    pub percentage: f32,
    pub completed_at: NaiveDateTime,
}

#[derive(serde::Serialize)]
pub struct TeacherInfo {
    pub lastname: String,
    pub firstname: String,
    pub patronymic: String,
}

#[derive(Debug, Deserialize)]
pub struct CourseIdRequest {
    pub course_id: i32,
}

#[derive(Debug,Deserialize, Serialize)]
pub struct StudentInfoCourse {
    pub user_name: String,
    pub lastname: String,
    pub firstname: String,
    pub patronymic: String,
    pub student_code: String,
    pub group_name: String,
}

#[derive(Debug, Serialize)]
pub struct GroupInfo {
    pub id: i32,
    pub name: String,
    pub academic_year: String,
    pub max_students: i32,
    pub students: Vec<StudentInfoCourse>,
}

#[derive(Debug, Serialize)]
pub struct TaskResultFullInfo {
    pub user_name: String,
    pub result_id: i32,
    pub lastname: String,
    pub firstname: String,
    pub patronymic: String,
    pub groupp: String,
    pub answertext: Option<String>,
    pub result: Option<String>,
    pub answer_files: Vec<FileInfo>,
    pub validation: i32,
    pub validation_status: String,
}

#[derive(Debug, sqlx::FromRow)]
pub struct TaskResultRaw {
    pub user_name: String,
    pub result_id: i32,
    pub create_date: NaiveDateTime,
    pub answertext: Option<String>,
    pub result: Option<String>,
    pub validation: i32,
    pub validation_status: String,
}

#[derive(Debug, Deserialize)]
pub struct TaskIdRequest {
    pub task_id: i32,
}

#[derive(Debug, Deserialize)]
pub struct UpdateTaskValidationRequest {
    pub validation: String,      // текст статуса проверки (verification, aproved, rejected, redevelopment)
    pub result: String,          // текст результата проверки
    pub task_id: i32,
    pub task_result_id: i32,
    pub username: String,
    #[serde(default)]            // позволяет не передавать поле, если комментарий не нужен
    pub comment_text: Option<String>, // опциональный комментарий
}

#[derive(Debug, Deserialize)]
pub struct TaskResultIdRequest {
    pub taskresult_id: i32,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct CommentInfo {
    pub user_name: String,
    pub comment_text: String,
    pub comment_date: NaiveDateTime,
}

#[derive(Debug, Serialize)]
pub struct ExtendedComment {
    pub user_name: String,
    pub lastname: String,
    pub firstname: String,
    pub patronymic: String,
    pub comment_text: String,
    pub comment_date: NaiveDateTime,
}

// Структура для запроса test_id
#[derive(Debug, Deserialize)]
pub struct TestIdRequest {
    pub test_id: i32,
}

// Структура для ответа – информация о студенте с результатами теста
#[derive(Debug, Serialize)]
pub struct TestStudentResult {
    pub lastname: String,
    pub firstname: String,
    pub patronymic: String,
    pub groupp: String,
    pub total_points: i32,
    pub max_points: i32,
    pub percentage: f32,
}