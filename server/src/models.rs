use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use chrono::NaiveDateTime;
use chrono::NaiveDate;

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct User {
    pub id: i32,
    pub user_name: String,      // соответствует колонке в БД
    pub email: String,
    pub create_at: NaiveDateTime,
}

#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub username: String,       // входное поле (можно назвать иначе, но в БД пойдёт как user_name)
    pub email: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub login: String,    // может быть user_name или email
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
    #[serde(skip_serializing_if = "Option::is_none")]
    pub token: Option<String>, // если используете JWT
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