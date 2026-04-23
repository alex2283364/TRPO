-- ==========================================
-- СКРИПТ ЗАПОЛНЕНИЯ БАЗЫ ДАННЫХ
-- ==========================================

SET client_encoding = 'UTF8';

-- ==========================================
-- 1. ОЧИСТКА БАЗЫ ДАННЫХ
-- ==========================================
TRUNCATE TABLE base.usertestanswer RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.usertaskanswer RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.taskresult RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.answerfile RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.answercomment RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.validation RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.inventorytest RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.test_result RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.test_attempt RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.inventorytask RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.inventoryfile RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.inventorytext RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.contentorder RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.textitem RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.file RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.inventory RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.coursinventory RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.teachercours RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.coursgroup RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.cours RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.studentgroup RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.teachergroup RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.groups RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.student RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.teacher RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.userrole RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.userroletype RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.salt RESTART IDENTITY CASCADE;
TRUNCATE TABLE base.users RESTART IDENTITY CASCADE;

-- ==========================================
-- 2. СОЗДАНИЕ ПОЛЬЗОВАТЕЛЕЙ ЧЕРЕЗ ФУНКЦИЮ
-- ==========================================

-- Создаем 5 преподавателей
CALL base.add_user('teacher_1', 'teacher1@university.ru', '12345');
CALL base.add_user('teacher_2', 'teacher2@university.ru', '12345');
CALL base.add_user('teacher_3', 'teacher3@university.ru', '12345');
CALL base.add_user('teacher_4', 'teacher4@university.ru', '12345');
CALL base.add_user('teacher_5', 'teacher5@university.ru', '12345');

-- Создаем 20 студентов
CALL base.add_user('student_1', 'student1@university.ru', '12345');
CALL base.add_user('student_2', 'student2@university.ru', '12345');
CALL base.add_user('student_3', 'student3@university.ru', '12345');
CALL base.add_user('student_4', 'student4@university.ru', '12345');
CALL base.add_user('student_5', 'student5@university.ru', '12345');
CALL base.add_user('student_6', 'student6@university.ru', '12345');
CALL base.add_user('student_7', 'student7@university.ru', '12345');
CALL base.add_user('student_8', 'student8@university.ru', '12345');
CALL base.add_user('student_9', 'student9@university.ru', '12345');
CALL base.add_user('student_10', 'student10@university.ru', '12345');
CALL base.add_user('student_11', 'student11@university.ru', '12345');
CALL base.add_user('student_12', 'student12@university.ru', '12345');
CALL base.add_user('student_13', 'student13@university.ru', '12345');
CALL base.add_user('student_14', 'student14@university.ru', '12345');
CALL base.add_user('student_15', 'student15@university.ru', '12345');
CALL base.add_user('student_16', 'student16@university.ru', '12345');
CALL base.add_user('student_17', 'student17@university.ru', '12345');
CALL base.add_user('student_18', 'student18@university.ru', '12345');
CALL base.add_user('student_19', 'student19@university.ru', '12345');
CALL base.add_user('student_20', 'student20@university.ru', '12345');

-- ==========================================
-- 3. СОЗДАНИЕ ТИПОВ РОЛЕЙ
-- ==========================================
INSERT INTO base.userroletype (role_name, permission_oid) VALUES 
('teacher', 'PERM-TEA-001'),
('teacher', 'PERM-TEA-002'),
('teacher', 'PERM-TEA-003'),
('teacher', 'PERM-TEA-004'),
('teacher', 'PERM-TEA-005');

-- Создаем 20 ролей для студентов
INSERT INTO base.userroletype (role_name, permission_oid) VALUES 
('student', 'PERM-STU-001'),
('student', 'PERM-STU-002'),
('student', 'PERM-STU-003'),
('student', 'PERM-STU-004'),
('student', 'PERM-STU-005'),
('student', 'PERM-STU-006'),
('student', 'PERM-STU-007'),
('student', 'PERM-STU-008'),
('student', 'PERM-STU-009'),
('student', 'PERM-STU-010'),
('student', 'PERM-STU-011'),
('student', 'PERM-STU-012'),
('student', 'PERM-STU-013'),
('student', 'PERM-STU-014'),
('student', 'PERM-STU-015'),
('student', 'PERM-STU-016'),
('student', 'PERM-STU-017'),
('student', 'PERM-STU-018'),
('student', 'PERM-STU-019'),
('student', 'PERM-STU-020');

-- ==========================================
-- 4. ПРИВЯЗКА ПОЛЬЗОВАТЕЛЕЙ К РОЛЯМ
-- ==========================================
-- Учителя (user_id 1-5, role_id 1-5)
INSERT INTO base.userrole (user_id, role_id) VALUES (1, 1);
INSERT INTO base.userrole (user_id, role_id) VALUES (2, 2);
INSERT INTO base.userrole (user_id, role_id) VALUES (3, 3);
INSERT INTO base.userrole (user_id, role_id) VALUES (4, 4);
INSERT INTO base.userrole (user_id, role_id) VALUES (5, 5);

-- Студенты (user_id 6-25, role_id 6-25)
INSERT INTO base.userrole (user_id, role_id) VALUES (6, 6);
INSERT INTO base.userrole (user_id, role_id) VALUES (7, 7);
INSERT INTO base.userrole (user_id, role_id) VALUES (8, 8);
INSERT INTO base.userrole (user_id, role_id) VALUES (9, 9);
INSERT INTO base.userrole (user_id, role_id) VALUES (10, 10);
INSERT INTO base.userrole (user_id, role_id) VALUES (11, 11);
INSERT INTO base.userrole (user_id, role_id) VALUES (12, 12);
INSERT INTO base.userrole (user_id, role_id) VALUES (13, 13);
INSERT INTO base.userrole (user_id, role_id) VALUES (14, 14);
INSERT INTO base.userrole (user_id, role_id) VALUES (15, 15);
INSERT INTO base.userrole (user_id, role_id) VALUES (16, 16);
INSERT INTO base.userrole (user_id, role_id) VALUES (17, 17);
INSERT INTO base.userrole (user_id, role_id) VALUES (18, 18);
INSERT INTO base.userrole (user_id, role_id) VALUES (19, 19);
INSERT INTO base.userrole (user_id, role_id) VALUES (20, 20);
INSERT INTO base.userrole (user_id, role_id) VALUES (21, 21);
INSERT INTO base.userrole (user_id, role_id) VALUES (22, 22);
INSERT INTO base.userrole (user_id, role_id) VALUES (23, 23);
INSERT INTO base.userrole (user_id, role_id) VALUES (24, 24);
INSERT INTO base.userrole (user_id, role_id) VALUES (25, 25);

-- ==========================================
-- 5. СОЗДАНИЕ ПРОФИЛЕЙ ПРЕПОДАВАТЕЛЕЙ
-- ==========================================
INSERT INTO base.teacher (lastname, firstname, patronymic, teacher_code, role_id) VALUES 
('Смирнов', 'Иван', 'Петрович', 'TEA-001', 1),
('Кузнецов', 'Алексей', 'Сергеевич', 'TEA-002', 2),
('Попов', 'Дмитрий', 'Андреевич', 'TEA-003', 3),
('Васильев', 'Максим', 'Иванович', 'TEA-004', 4),
('Соколов', 'Артем', 'Дмитриевич', 'TEA-005', 5);

-- ==========================================
-- 6. СОЗДАНИЕ ПРОФИЛЕЙ СТУДЕНТОВ
-- ==========================================
INSERT INTO base.student (lastname, firstname, patronymic, student_code, role_id) VALUES 
('Иванов', 'Иван', 'Иванович', 'STU-001', 6),
('Петров', 'Петр', 'Петрович', 'STU-002', 7),
('Сидоров', 'Сидор', 'Сидорович', 'STU-003', 8),
('Козлов', 'Алексей', 'Николаевич', 'STU-004', 9),
('Новиков', 'Дмитрий', 'Алексеевич', 'STU-005', 10),
('Морозов', 'Сергей', 'Владимирович', 'STU-006', 11),
('Волков', 'Андрей', 'Сергеевич', 'STU-007', 12),
('Соловьев', 'Михаил', 'Андреевич', 'STU-008', 13),
('Васильев', 'Николай', 'Иванович', 'STU-009', 14),
('Зайцев', 'Павел', 'Петрович', 'STU-010', 15),
('Павлов', 'Евгений', 'Сергеевич', 'STU-011', 16),
('Семенов', 'Виктор', 'Михайлович', 'STU-012', 17),
('Голубев', 'Роман', 'Дмитриевич', 'STU-013', 18),
('Виноградов', 'Игорь', 'Алексеевич', 'STU-014', 19),
('Богданов', 'Олег', 'Викторович', 'STU-015', 20),
('Воробьев', 'Никита', 'Павлович', 'STU-016', 21),
('Федоров', 'Артем', 'Евгеньевич', 'STU-017', 22),
('Михайлов', 'Денис', 'Викторович', 'STU-018', 23),
('Беляев', 'Владимир', 'Олегович', 'STU-019', 24),
('Тарасов', 'Константин', 'Никитич', 'STU-020', 25);

-- ==========================================
-- 7. СОЗДАНИЕ ГРУПП
-- ==========================================
INSERT INTO base.groups (name, academic_year, max_students) VALUES 
('ИВТ-101', '2024', 30),
('ИВТ-102', '2024', 30),
('ИВТ-201', '2023', 25),
('ИВТ-202', '2023', 25),
('ИВТ-301', '2022', 20);

-- ==========================================
-- 8. ПРИВЯЗКА СТУДЕНТОВ К ГРУППАМ
-- ==========================================
-- Группа 1 (ИВТ-101): студенты 1-4, 16
INSERT INTO base.studentgroup (student_id, group_id) VALUES (1, 1);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (2, 1);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (3, 1);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (4, 2);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (5, 2);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (6, 2);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (7, 3);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (8, 3);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (9, 3);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (10, 4);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (11, 4);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (12, 4);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (13, 5);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (14, 5);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (15, 5);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (16, 1);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (17, 2);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (18, 3);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (19, 4);
INSERT INTO base.studentgroup (student_id, group_id) VALUES (20, 5);

-- ==========================================
-- 9. ПРИВЯЗКА ПРЕПОДАВАТЕЛЕЙ К ГРУППАМ
-- ==========================================
INSERT INTO base.teachergroup (teacher_id, group_id) VALUES (1, 1);
INSERT INTO base.teachergroup (teacher_id, group_id) VALUES (1, 2);
INSERT INTO base.teachergroup (teacher_id, group_id) VALUES (2, 3);
INSERT INTO base.teachergroup (teacher_id, group_id) VALUES (2, 4);
INSERT INTO base.teachergroup (teacher_id, group_id) VALUES (3, 5);
INSERT INTO base.teachergroup (teacher_id, group_id) VALUES (4, 1);
INSERT INTO base.teachergroup (teacher_id, group_id) VALUES (5, 2);

-- ==========================================
-- 10. СОЗДАНИЕ КУРСОВ
-- ==========================================
INSERT INTO base.cours (name, description, start_date, end_date) VALUES 
('Основы SQL', 'Введение в базы данных и SQL запросы', '2026-01-01', '2026-06-01'),
('Веб-разработка', 'HTML, CSS и JavaScript с нуля', '2026-01-15', '2026-06-15'),
('Алгоритмы', 'Структуры данных и алгоритмы', '2026-02-01', '2026-07-01'),
('Математика', 'Высшая математика для программистов', '2026-01-01', '2026-05-30'),
('Физика', 'Общая физика', '2026-01-01', '2026-05-30'),
('Английский язык', 'Technical English', '2026-01-01', '2026-06-01'),
('Операционные системы', 'Linux и Windows internals', '2026-03-01', '2026-08-01'),
('Компьютерные сети', 'TCP/IP и протоколы', '2026-03-01', '2026-08-01'),
('Git и DevOps', 'Системы контроля версий', '2026-02-15', '2026-07-15'),
('Тестирование ПО', 'QA Manual и Automation', '2026-04-01', '2026-09-01');

-- ==========================================
-- 11. ПРИВЯЗКА КУРСОВ К ГРУППАМ
-- ==========================================
-- Все группы проходят первые 5 курсов
INSERT INTO base.coursgroup (course_id, groupe_id) VALUES 
(1, 1), (1, 2), (1, 3), (1, 4), (1, 5),
(2, 1), (2, 2), (2, 3), (2, 4), (2, 5),
(3, 1), (3, 2), (3, 3), (3, 4), (3, 5),
(4, 1), (4, 2), (4, 3), (4, 4), (4, 5),
(5, 1), (5, 2), (5, 3), (5, 4), (5, 5);

-- Остальные курсы только для первых 3 групп
INSERT INTO base.coursgroup (course_id, groupe_id) VALUES 
(6, 1), (6, 2), (6, 3),
(7, 1), (7, 2), (7, 3),
(8, 1), (8, 2), (8, 3),
(9, 1), (9, 2), (9, 3),
(10, 1), (10, 2), (10, 3);

-- ==========================================
-- 12. ПРИВЯЗКА ПРЕПОДАВАТЕЛЕЙ К КУРСАМ
-- ==========================================
INSERT INTO base.teachercours (course_id, teacher_id) VALUES 
(1, 1), (2, 1), (3, 1),
(4, 2), (5, 2),
(6, 3), (7, 3),
(8, 4), (9, 4),
(10, 5);

-- ==========================================
-- 13. ВРЕМЕННЫЕ СЛОТЫ
-- ==========================================
INSERT INTO base."time" (name, start_date, end_date) VALUES 
('Весна 2026', '2026-02-01', '2026-06-30');

-- ==========================================
-- 14. ИНВЕНТАРИ (УЧЕБНЫЕ БЛОКИ)
-- ==========================================
INSERT INTO base.inventory (create_state, que_date) VALUES 
(NOW(), '2026-06-01'),
(NOW(), '2026-06-15'),
(NOW(), '2026-07-01'),
(NOW(), '2026-05-30'),
(NOW(), '2026-05-30'),
(NOW(), '2026-06-01'),
(NOW(), '2026-08-01'),
(NOW(), '2026-08-01'),
(NOW(), '2026-07-15'),
(NOW(), '2026-09-01');

-- ==========================================
-- 15. ПРИВЯЗКА ИНВЕНТАРЕЙ К КУРСАМ
-- ==========================================
INSERT INTO base.coursinventory (cours_id, inventory_id) VALUES 
(1, 1), (2, 2), (3, 3), (4, 4), (5, 5),
(6, 6), (7, 7), (8, 8), (9, 9), (10, 10);

-- ==========================================
-- 16. ТЕКСТОВЫЕ МАТЕРИАЛЫ
-- ==========================================
INSERT INTO base.textitem ("textсontent") VALUES 
('<h3>Лекция 1: Введение в SQL</h3><p>SQL (Structured Query Language) — это язык структурированных запросов...</p>'),
('<h3>Лекция 2: Основы HTML</h3><p>HTML (HyperText Markup Language) — стандартный язык гипертекстовой разметки...</p>'),
('<h3>Лекция 3: Алгоритмы сортировки</h3><p>Сортировка — процесс упорядочивания элементов...</p>'),
('<h3>Лекция 4: Математический анализ</h3><p>Пределы, производные, интегралы...</p>'),
('<h3>Лекция 5: Механика</h3><p>Законы Ньютона, кинематика...</p>'),
('<h3>Lesson 1: Basics</h3><p>Introduction to technical English...</p>'),
('<h3>Лекция 7: Процессы в Linux</h3><p>Управление процессами, сигналы...</p>'),
('<h3>Лекция 8: Модель OSI</h3><p>Сетевые протоколы и уровни...</p>'),
('<h3>Лекция 9: Git basics</h3><p>Системы контроля версий...</p>'),
('<h3>Лекция 10: Виды тестирования</h3><p>Unit, Integration, E2E тесты...</p>');

-- ==========================================
-- 17. ПРИВЯЗКА ТЕКСТОВ К ИНВЕНТАРЯМ
-- ==========================================
INSERT INTO base.inventorytext (inventory_id, textitem_id) VALUES 
(1, 1), (2, 2), (3, 3), (4, 4), (5, 5),
(6, 6), (7, 7), (8, 8), (9, 9), (10, 10);

-- ==========================================
-- 18. ФАЙЛЫ
-- ==========================================
INSERT INTO base.file (file_name, path, extension, size) VALUES 
('lecture_sql_intro', '/files/courses/', 'pdf', 1024),
('task_sql_queries', '/files/tasks/', 'docx', 512),
('lecture_html_basics', '/files/courses/', 'pdf', 2048),
('task_layout', '/files/tasks/', 'zip', 1024),
('lecture_algorithms', '/files/courses/', 'pdf', 4096),
('task_sorting', '/files/tasks/', 'py', 256),
('lecture_math', '/files/courses/', 'pdf', 8192),
('task_integrals', '/files/tasks/', 'pdf', 512),
('lecture_physics', '/files/courses/', 'pdf', 16384),
('task_mechanics', '/files/tasks/', 'docx', 1024);

-- ==========================================
-- 19. ПРИВЯЗКА ФАЙЛОВ К ИНВЕНТАРЯМ
-- ==========================================
INSERT INTO base.inventoryfile (inventory_id, file_id) VALUES 
(1, 1), (1, 2),
(2, 3), (2, 4),
(3, 5), (3, 6),
(4, 7), (4, 8),
(5, 9), (5, 10);

-- ==========================================
-- 20. ЗАДАНИЯ
-- ==========================================
INSERT INTO base.task (name, time_id, qdescription, adescription) VALUES 
('Задание 1: SQL запросы', 1, 'Напишите 5 SELECT запросов к базе данных.', 'Прикрепите файл с кодом.'),
('Задание 2: Верстка страницы', 1, 'Сверстайте лендинг по макету.', 'Прикрепите архив с проектом.'),
('Задание 3: Реализация сортировки', 1, 'Реализуйте алгоритм быстрой сортировки.', 'Код на Python или Java.'),
('Задание 4: Решение интегралов', 1, 'Решите 10 интегралов из списка.', 'Фото или PDF с решениями.'),
('Задание 5: Лабораторная по механике', 1, 'Проведите эксперимент и опишите результаты.', 'Отчет в Word.'),
('Задание 6: Эссе на английском', 1, 'Напишите эссе на тему "My Future Career".', 'Текст не менее 200 слов.'),
('Задание 7: Скрипт на Bash', 1, 'Напишите скрипт для автоматизации бэкапов.', 'Файл .sh'),
('Задание 8: Настройка Wireshark', 1, 'Перехватите и проанализируйте пакеты.', 'Скриншоты и выводы.'),
('Задание 9: Работа с ветками Git', 1, 'Создайте репозиторий, сделайте 5 коммитов.', 'Ссылка на GitHub.'),
('Задание 10: Тест-кейсы', 1, 'Составьте 10 тест-кейсов для формы логина.', 'Таблица Excel.');

-- ==========================================
-- 21. ПРИВЯЗКА ЗАДАНИЙ К ИНВЕНТАРЯМ
-- ==========================================
INSERT INTO base.inventorytask (inventory_id, tasklist_id) VALUES 
(1, 1), (2, 2), (3, 3), (4, 4), (5, 5),
(6, 6), (7, 7), (8, 8), (9, 9), (10, 10);

-- ==========================================
-- 22. ПРИВЯЗКА ФАЙЛОВ К ЗАДАНИЯМ
-- ==========================================
INSERT INTO base.taskfile (task_id, file_id) VALUES 
(1, 2), (2, 4), (3, 6), (4, 8), (5, 10);

-- ==========================================
-- 23. ПОРЯДОК КОНТЕНТА
-- ==========================================
INSERT INTO base.contentorder (type, cotent_order, inventory_id) VALUES 
('text', 0, 1), ('task', 1, 1),
('text', 0, 2), ('task', 1, 2),
('text', 0, 3), ('task', 1, 3),
('text', 0, 4), ('task', 1, 4),
('text', 0, 5), ('task', 1, 5),
('text', 0, 6), ('task', 1, 6),
('text', 0, 7), ('task', 1, 7),
('text', 0, 8), ('task', 1, 8),
('text', 0, 9), ('task', 1, 9),
('text', 0, 10), ('task', 1, 10);

-- ==========================================
-- 24. ОБНОВЛЕНИЕ ПОСЛЕДОВАТЕЛЬНОСТЕЙ
-- ==========================================
SELECT setval('base.userroletype_id_seq', 25, true);
SELECT setval('base.users_id_seq', 25, true);
SELECT setval('base.student_id_seq', 20, true);
SELECT setval('base.teacher_id_seq', 5, true);
SELECT setval('base.groups_id_seq', 5, true);
SELECT setval('base.cours_id_seq', 10, true);
SELECT setval('base.inventory_id_seq', 10, true);
SELECT setval('base.textitem_id_seq', 10, true);
SELECT setval('base.file_id_seq', 10, true);
SELECT setval('base.task_id_seq', 10, true);
SELECT setval('base.contentorder_id_seq', 20, true);

-- ==========================================
-- ГОТОВО!
-- ==========================================
-- ЛОГИНЫ И ПАРОЛИ:
-- Учителя: teacher_1 ... teacher_5 (пароль: 12345)
-- Студенты: student_1 ... student_20 (пароль: 12345)