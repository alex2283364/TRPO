# TRPO
Курсовая работа по трпо
# 📁 TRPO Server

> **Серверная часть курсовой работы по дисциплине «Технология разработки программного обеспечения»**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0-blue?logo=typescript)](https://www.typescriptlang.org/)
[![Rust](https://img.shields.io/badge/Rust-1.70-orange?logo=rust)](https://www.rust-lang.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue?logo=postgresql)](https://www.postgresql.org/)

---

## 📋 О проекте

Бэкенд образовательной платформы с гибридной архитектурой (TypeScript + Rust) и ролевой системой доступа. Сервер предоставляет API для:

- 🔐 Регистрации и аутентификации пользователей
- 👥 Управления ролями: студент, преподаватель, администратор
- 📚 Создания и ведения курсов и учебных групп
- 📝 Системы заданий, тестов и попыток их прохождения
- 📊 Отслеживания прогресса и результатов обучения
- 📁 Загрузки файлов и комментариев к работам

---

## 🗂 Структура проекта

```
server/
├── src/
│   ├── handlers/          # Обработчики HTTP-запросов (Rust)
│   │   ├── answer.rs      # Обработка ответов на тесты
│   │   ├── course.rs      # Эндпоинты для работы с курсами
│   │   ├── mod.rs         # Модульная сборка хендлеров
│   │   ├── teacher.rs     # Функционал преподавателя
│   │   └── user.rs        # Управление пользователями и файлами
│   ├── auth.ts            # Логика аутентификации (TypeScript)
│   ├── register.ts        # Регистрация новых пользователей
│   ├── course.ts          # Бизнес-логика курсов
│   ├── user-info.ts       # Получение данных профиля
│   ├── main.rs            # Точка входа Actix Web-сервера
│   ├── models.rs          # Модели данных (Serde)
│   └── state.rs           # Глобальное состояние приложения
├── static/                # Статические файлы фронтенда
├── Creat.sql             # DDL-схема БД (таблицы, функции, триггеры)
├── Insert.sql            # Начальные данные для тестирования
├── TRPO.dump             # Полная резервная копия БД PostgreSQL
├── .env                  # Переменные окружения
├── package.json          # Зависимости TypeScript
├── tsconfig.json         # Конфигурация компилятора TS
├── Cargo.toml            # Зависимости Rust-проекта
├── Cargo.lock            # Lock-файл зависимостей Rust
└── postgres - TRPO - base.png  # ER-диаграмма базы данных
```

---

## 🛠 Технологический стек

| Компонент | Технология / Версия |
|-----------|-------------------|
| **Языки** | TypeScript, Rust, JavaScript |
| **Web-фреймворк** | Actix Web (Rust) |
| **База данных** | PostgreSQL с PL/pgSQL функциями |
| **ORM / Query** | SQLx с async-поддержкой |
| **Сериализация** | Serde + serde_json |
| **Асинхронность** | Tokio runtime |
| **Работа с файлами** | actix-files, actix-multipart |
| **Утилиты** | chrono, uuid, dotenvy, env_logger |

---

## ⚙️ Быстрый старт

### 1. Клонирование и переход в папку
```bash
git clone https://github.com/alex2283364/TRPO.git
cd TRPO/server
```

### 2. Настройка переменных окружения
Создайте или отредактируйте файл `.env`:
```env
DATABASE_URL_PUBLIC=postgres://publicUser:1@localhost/TRPO
DATABASE_URL_STUDENT=postgres://studentUser:1@localhost/TRPO
```

### 3. Подготовка базы данных

**Вариант А: Через SQL-скрипты**
```bash
# Создайте базу данных
createdb -U postgres TRPO

# Примените схему
psql -U postgres -d TRPO -f Creat.sql

# Загрузите тестовые данные (опционально)
psql -U postgres -d TRPO -f Insert.sql
```

**Вариант Б: Восстановление из дампа**
```bash
pg_restore -U postgres -d TRPO TRPO.dump
# или для текстового дампа:
psql -U postgres -d TRPO < TRPO.dump
```

### 4. Установка зависимостей
```bash
# TypeScript-утилиты (если используются)
npm install

# Rust-зависимости (автоматически при сборке)
rustup install stable
```

### 5. Сборка и запуск
```bash
# Сборка проекта
cargo build

# Запуск сервера
cargo run 
# или напрямую исполняемый файл:
./target/release/actix_users_db
```

Сервер будет доступен по адресу: `http://localhost:8080`

---

## 🗄 Архитектура базы данных

### Основные сущности
```
users          → профили всех пользователей
├─ student     → данные студентов
├─ teacher     → данные преподавателей  
└─ admin       → данные администраторов

cours / groups → учебные курсы и группы
├─ inventory   → учебные материалы
├─ task        → задания и тесты
│  ├─ question       → вопросы теста
│  ├─ answer_option  → варианты ответов
│  └─ taskresult     → результаты выполнения

file / comment / validation → вложения, комментарии, проверка работ
```

### 🔐 Система прав доступа

Проект использует **ролевое разграничение на уровне БД**:

| Роль пользователя | БД-пользователь | Доступ |
|------------------|----------------|--------|
| Гость / Регистрация | `publicUser` | Только `auth_*`, `register_*` функции |
| Студент | `studentUser` | Чтение курсов, отправка ответов, свои результаты |
| Преподаватель | `teacher` (через app logic) | Управление заданиями, проверка работ, аналитика |
| Администратор | `postgres` / `admin` | Полный доступ ко всем объектам БД |

> 💡 Все бизнес-операции выполняются через хранимые функции PostgreSQL, что обеспечивает централизованную валидацию и аудит.

---

## 📡 Основные эндпоинты API

```http
# Аутентификация
POST /api/auth/login
POST /api/auth/register

# Пользователи
GET  /api/user/me
PUT  /api/user/profile

# Курсы
GET  /api/courses
POST /api/courses          # (преподаватель/админ)
GET  /api/courses/:id

# Задания и тесты
GET  /api/tasks/:course_id
POST /api/tasks/submit
GET  /api/tasks/:id/results

# Файлы
POST /api/files/upload
GET  /api/files/:id
```
---

## 🧪 Запуск

```bash
# Запуск Rust
cargo ru
```

---

## 📄 Лицензия

Проект создан в рамках учебной курсовой работы. Исходный код распространяется под лицензией **MIT** — используйте с указанием авторства.

```
Copyright © 2026 alex2283364
```

---
> • Для актуальной информации проверяйте последние коммиты

*Последнее обновление: Апрель 2026 • Коммит: `50832b9`*
