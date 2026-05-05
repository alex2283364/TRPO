--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: base; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA base;


ALTER SCHEMA base OWNER TO postgres;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA base;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: add_comment_to_taskresult(text, integer, text); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.add_comment_to_taskresult(p_username text, p_taskresult_id integer, p_comment_text text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id      integer;
    v_comment_id   integer;
BEGIN
    -- Получить user_id по имени пользователя
    SELECT u.id INTO v_user_id
    FROM base.users u
    WHERE u.user_name = p_username;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Пользователь с именем "%" не найден', p_username;
    END IF;

    -- Вставить запись в таблицу comment
    INSERT INTO base.comment (comment_text, comment_date, user_id)
    VALUES (p_comment_text, Now(), v_user_id)
    RETURNING id INTO v_comment_id;

    -- Вставить связь в answerComment
    INSERT INTO base.answerComment (taskresult_id, comment_id)
    VALUES (p_taskresult_id, v_comment_id);

    RETURN v_comment_id;
END;
$$;


ALTER FUNCTION base.add_comment_to_taskresult(p_username text, p_taskresult_id integer, p_comment_text text) OWNER TO postgres;

--
-- Name: add_test(); Type: PROCEDURE; Schema: base; Owner: postgres
--

CREATE PROCEDURE base.add_test()
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN

END;
$$;


ALTER PROCEDURE base.add_test() OWNER TO postgres;

--
-- Name: add_user(character varying, character varying, character varying); Type: PROCEDURE; Schema: base; Owner: postgres
--

CREATE PROCEDURE base.add_user(IN p_user_name character varying, IN p_email character varying, IN p_password character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_salt      TEXT;
    v_salt_id   INTEGER;
    v_password_hash TEXT;
BEGIN
    -- 1. Generate a random salt (16 bytes, hex encoded)
    v_salt := base.gen_salt('bf');

    -- 2. Compute the password hash: SHA256(password || salt)
    v_password_hash := encode(base.digest(p_password || v_salt, 'sha256'), 'hex');

    -- 3. Insert the salt and obtain its ID
    INSERT INTO base.salt (salt)
    VALUES (v_salt)
    RETURNING id INTO v_salt_id;

    -- 4. Insert the user with the hash, email, current timestamp, and the salt reference
    INSERT INTO base.users (user_name, password_hash, email, create_at, salt_id)
    VALUES (p_user_name, v_password_hash, p_email, NOW(), v_salt_id);
END;
$$;


ALTER PROCEDURE base.add_user(IN p_user_name character varying, IN p_email character varying, IN p_password character varying) OWNER TO postgres;

--
-- Name: authenticate_role(character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.authenticate_role(p_login character varying) RETURNS TABLE(hasrole boolean, roletype character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id   INTEGER;
    v_role_id   INTEGER;
    v_role_name VARCHAR;
BEGIN
    -- Ищем активного пользователя по user_name или email
    SELECT u.id
    INTO v_user_id
    FROM base.users u
    WHERE (u.user_name = p_login OR u.email = p_login)
      AND u.is_active = TRUE;

    -- Если пользователь не найден или неактивен
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::VARCHAR;
        RETURN;
    END IF;

    -- Ищем привязанную роль
    SELECT us.role_id
    INTO v_role_id
    FROM base.userrole us
    WHERE us.user_id = v_user_id;

    -- Если роль есть – получаем её имя
    IF v_role_id IS NOT NULL THEN
        SELECT ut.role_name
        INTO v_role_name
        FROM base.userroletype ut
        WHERE ut.id = v_role_id;

        IF v_role_name IS NOT NULL THEN
            RETURN QUERY SELECT TRUE, v_role_name;
        ELSE
            RETURN QUERY SELECT FALSE, NULL::VARCHAR;
        END IF;
    ELSE
        RETURN QUERY SELECT FALSE, NULL::VARCHAR;
    END IF;
END;
$$;


ALTER FUNCTION base.authenticate_role(p_login character varying) OWNER TO postgres;

--
-- Name: authenticate_user(character varying, character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.authenticate_user(p_login character varying, p_password character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id       INTEGER;
    v_salt          TEXT;
    v_stored_hash   TEXT;
    v_computed_hash TEXT;
BEGIN
    -- Ищем активного пользователя по user_name или email
    SELECT u.id, s.salt, u.password_hash
    INTO v_user_id, v_salt, v_stored_hash
    FROM base.users u
    JOIN base.salt s ON u.salt_id = s.id
    WHERE (u.user_name = p_login OR u.email = p_login)
      AND u.is_active = TRUE;

    -- Если пользователь не найден или неактивен
    IF NOT FOUND THEN
        RETURN False;
    END IF;

    -- Вычисляем хеш для введённого пароля с использованием найденной соли
    v_computed_hash := encode(base.digest(p_password || v_salt, 'sha256'), 'hex');

    -- Сравниваем с сохранённым хешем
    IF v_computed_hash = v_stored_hash THEN
        RETURN True;
    ELSE
        RETURN False;
    END IF;
END;
$$;


ALTER FUNCTION base.authenticate_user(p_login character varying, p_password character varying) OWNER TO postgres;

--
-- Name: binding_role(character varying, character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.binding_role(p_login character varying, role_pasword character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id       INTEGER;
    v_role_id       INTEGER;
BEGIN
    -- Ищем активного пользователя по user_name или email
    SELECT u.id
    INTO v_user_id
    FROM base.users u
    WHERE (u.user_name = p_login OR u.email = p_login)
      AND u.is_active = TRUE;

    -- Если пользователь не найден или неактивен
    IF NOT FOUND THEN
        RETURN False;
    END IF;
    -- Ищем роль по коду
   SELECT ut.id
   INTO v_role_id
   FROM base.userroletype ut
   WHERE (ut.permission_oid = role_pasword);
    IF NOT FOUND THEN
        RETURN False;
    END IF;
    IF FOUND THEN
        PERFORM us.role_id 
        FROM base.userrole us
        WHERE(v_role_id = us.role_id);
        IF FOUND THEN
           RETURN False;
        END IF;
        IF NOT FOUND THEN
           INSERT INTO base.userrole(user_id, role_id) VALUES(v_user_id, v_role_id);
           return true;
        END IF;
    END IF;
END;
$$;


ALTER FUNCTION base.binding_role(p_login character varying, role_pasword character varying) OWNER TO postgres;

--
-- Name: complete_test_attempt(integer, integer, integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.complete_test_attempt(p_attempt_id integer, p_total_points integer, p_max_points integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_percentage DECIMAL(5,2);
    v_exists BOOLEAN;
BEGIN
    -- Защита от деления на ноль
    IF p_max_points <= 0 THEN
        RAISE EXCEPTION 'max_points must be positive';
    END IF;

    -- Вычисляем процент выполнения
    v_percentage := (p_total_points::numeric / p_max_points) * 100;

    -- Обновляем статус попытки (только если она ещё в процессе)
    UPDATE base.test_attempt
    SET status = 'completed'
    WHERE id = p_attempt_id AND status = 'in_progress';

    -- Проверяем, была ли обновлена запись
    IF NOT FOUND THEN
        IF NOT EXISTS (SELECT 1 FROM base.test_attempt WHERE id = p_attempt_id) THEN
            RAISE EXCEPTION 'Attempt with id % does not exist', p_attempt_id;
        ELSE
            RAISE EXCEPTION 'Attempt % is already completed or abandoned', p_attempt_id;
        END IF;
    END IF;
        -- Вставляем новый результат
        INSERT INTO base.test_result (attempt_id, total_points, max_points, percentage, completed_at)
        VALUES (p_attempt_id, p_total_points, p_max_points, v_percentage, CURRENT_TIMESTAMP);

END;
$$;


ALTER FUNCTION base.complete_test_attempt(p_attempt_id integer, p_total_points integer, p_max_points integer) OWNER TO postgres;

--
-- Name: create_validation_and_update_taskresult(character varying, character varying, integer, integer, character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.create_validation_and_update_taskresult(p_validation character varying, p_result character varying, p_task_id integer, p_taskresult_id integer, p_username character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id        integer;
    v_validation_id  integer;
BEGIN
    -- Получить user_id по имени пользователя
    SELECT u.id INTO v_user_id
    FROM base.users u
    WHERE u.user_name = p_username;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Пользователь с именем "%" не найден', p_username;
    END IF;

    -- Вставить новую запись в validation
    INSERT INTO base.validation (validation, task_id, user_id, change_date)
    VALUES (p_validation, p_task_id, v_user_id, now())
    RETURNING id INTO v_validation_id;

    -- Обновить taskresult: result и validation_id
    UPDATE base.taskresult
    SET result = p_result,
        validation_id = v_validation_id
    WHERE id = p_taskResult_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Запись taskresult с id = % не найдена', p_taskResult_id;
    END IF;

    -- Вернуть id созданной записи validation
    RETURN v_validation_id;
END;
$$;


ALTER FUNCTION base.create_validation_and_update_taskresult(p_validation character varying, p_result character varying, p_task_id integer, p_taskresult_id integer, p_username character varying) OWNER TO postgres;

--
-- Name: get_attempt_count(integer, character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_attempt_count(p_test_id integer, p_username character varying) RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT COUNT(*)
    FROM base.test_attempt ta
    JOIN base.users u ON ta.user_id = u.id
    WHERE ta.test_id = p_test_id AND u.user_name = p_username;
$$;


ALTER FUNCTION base.get_attempt_count(p_test_id integer, p_username character varying) OWNER TO postgres;

--
-- Name: get_best_test_result(text, integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_best_test_result(p_user_name text, p_test_id integer) RETURNS TABLE(total_points integer, max_points integer, percentage real, completed_at timestamp without time zone)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT tr.total_points, tr.max_points, tr.percentage::real, tr.completed_at
    FROM base.test_result tr
    JOIN base.test_attempt ta ON tr.attempt_id = ta.id
    JOIN base.users u ON ta.user_id = u.id
    WHERE u.user_name = p_user_name AND ta.test_id = p_test_id
    ORDER BY tr.total_points DESC
    LIMIT 1;
$$;


ALTER FUNCTION base.get_best_test_result(p_user_name text, p_test_id integer) OWNER TO postgres;

--
-- Name: get_combined_questions(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_combined_questions(td_id integer) RETURNS TABLE(id integer, question_type character varying, question_points integer, right_answer text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM (
        -- Первый запрос: правильные ответы из вариантов (sort_order)
        SELECT 
            q.id,
            q.question_type,
            q.points,
            ao.sort_order::TEXT AS right_answer
        FROM base.answer_option ao
        JOIN base.question q ON q.id = ao.question_id
        JOIN base.test_definition td ON td.id = td_id
        WHERE ao.is_correct = true
    
        UNION ALL
    
        -- Второй запрос: вопросы с текстовым правильным ответом
        SELECT 
            q.id,
            q.question_type,
            q.points,
            q.correct_text::TEXT AS right_answer
        FROM base.question q
        JOIN base.test_definition td ON td.id = td_id
        WHERE q.correct_text IS NOT NULL
    ) AS combined
    ORDER BY id;
END;
$$;


ALTER FUNCTION base.get_combined_questions(td_id integer) OWNER TO postgres;

--
-- Name: get_comments_by_taskresult(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_comments_by_taskresult(p_taskresult_id integer) RETURNS TABLE(user_name text, comment_text text, comment_date timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'base', 'public', 'pg_temp'
    AS $$
    SELECT u.user_name, c.comment_text, c.comment_date
    FROM base.answercomment a
    JOIN base."comment" c ON c.id = a.comment_id
    JOIN base.users u ON u.id = c.user_id
    WHERE a.taskresult_id = p_taskresult_id;
$$;


ALTER FUNCTION base.get_comments_by_taskresult(p_taskresult_id integer) OWNER TO postgres;

--
-- Name: get_contentorder_by_course(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_contentorder_by_course(p_course_id integer) RETURNS TABLE(content_order integer, inventory_id integer, type character varying)
    LANGUAGE sql SECURITY DEFINER
    AS $$
	    SELECT co.Cotent_order, i.id, co.type
	    FROM base.contentorder co
	    JOIN base.cours c ON c.id = p_course_id
	    JOIN base.coursInventory ci ON ci.cours_id = c.id
	    JOIN base.inventory i ON i.id = ci.inventory_id
	    WHERE co.inventory_id = i.id
	    ORDER BY co.Cotent_order;
$$;


ALTER FUNCTION base.get_contentorder_by_course(p_course_id integer) OWNER TO postgres;

--
-- Name: get_courses_by_teacher(character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_courses_by_teacher(p_user_name character varying) RETURNS TABLE(id integer, name character varying, description text, start_date date, end_date date)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    select distinct c.id,
        c."name",
        c.description,
        c.start_date,
        c.end_date
    FROM base.cours c
    join base.teachercours tc on c.id = tc.course_id  
    join base.teacher t on t.id = tc.teacher_id 
    JOIN base.userrole ur ON ur.role_id = t.role_id 
    JOIN base.users u ON u.id = ur.user_id
    WHERE u.user_name = p_user_name;
$$;


ALTER FUNCTION base.get_courses_by_teacher(p_user_name character varying) OWNER TO postgres;

--
-- Name: get_courses_by_username(character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_courses_by_username(p_user_name character varying) RETURNS TABLE(id integer, name character varying, description text, start_date date, end_date date)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT DISTINCT
        c.id,
        c."name",          -- кавычки нужны, так как "name" является зарезервированным словом
        c.description,
        c.start_date,
        c.end_date
    FROM base.cours c
    JOIN base.coursgroup cg ON c.id = cg.course_id
    JOIN base.groups g ON g.id = cg.groupe_id
    JOIN base.studentgroup sg ON sg.group_id = g.id
    JOIN base.student s ON s.id = sg.student_id
    JOIN base.userrole ur ON ur.role_id = s.role_id
    JOIN base.users u ON u.id = ur.user_id
    WHERE u.user_name = p_user_name;
$$;


ALTER FUNCTION base.get_courses_by_username(p_user_name character varying) OWNER TO postgres;

--
-- Name: get_file_by_id(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_file_by_id(p_id integer) RETURNS TABLE(id integer, file_name text, extension text, path text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT id, file_name, extension, path
    FROM base.file
    WHERE id = p_id;
$$;


ALTER FUNCTION base.get_file_by_id(p_id integer) OWNER TO postgres;

--
-- Name: get_files_by_answer(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_files_by_answer(p_answer_id integer) RETURNS TABLE(id integer, file_name character varying, extension character varying, path character varying)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT f.id, f.file_name, f."extension", f."path"
    FROM base.file f
    JOIN base.answerfile af ON f.id = af.file_id
    WHERE af.taskresult_id = p_answer_id;
$$;


ALTER FUNCTION base.get_files_by_answer(p_answer_id integer) OWNER TO postgres;

--
-- Name: get_files_by_inventory(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_files_by_inventory(p_inventory_id integer) RETURNS TABLE(id integer, file_name character varying, extension character varying, path character varying)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT f.id, f.file_name, f."extension", f."path"
    FROM base.file f
    JOIN base.inventoryfile fi ON f.id = fi.file_id
    WHERE fi.inventory_id = p_inventory_id;
$$;


ALTER FUNCTION base.get_files_by_inventory(p_inventory_id integer) OWNER TO postgres;

--
-- Name: get_files_by_task(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_files_by_task(p_task_id integer) RETURNS TABLE(id integer, file_name character varying, extension character varying, path character varying)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT f.id, f.file_name, f."extension", f."path"
    FROM base.file f
    JOIN base.taskfile ti ON f.id = ti.file_id
    WHERE ti.task_id = p_task_id;
$$;


ALTER FUNCTION base.get_files_by_task(p_task_id integer) OWNER TO postgres;

--
-- Name: get_group_by_course(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_group_by_course(p_course_id integer) RETURNS TABLE(id integer, name character varying, academic_year character varying, max_students integer)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'base', 'public', 'pg_temp'
    AS $$
    SELECT g.id, g."name", g.academic_year, g.max_students
    FROM base."groups" g
    JOIN base.coursgroup cg ON cg.groupe_id = g.id
    JOIN base.cours c ON c.id = cg.course_id
    WHERE c.id = p_course_id;
$$;


ALTER FUNCTION base.get_group_by_course(p_course_id integer) OWNER TO postgres;

--
-- Name: get_group_by_teacher(character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_group_by_teacher(p_user_name character varying) RETURNS TABLE(id integer, name character varying, academic_year character varying, max_students integer)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    select g.id, g."name", g.academic_year, g.max_students  
    from base."groups" g 
    join teachergroup tg on tg.group_id = g.id 
    join base.teacher t on t.id = tg.teacher_id  
    JOIN base.userrole ur ON ur.role_id = t.role_id 
    JOIN base.users u ON u.id = ur.user_id
    WHERE u.user_name = 'test8';
$$;


ALTER FUNCTION base.get_group_by_teacher(p_user_name character varying) OWNER TO postgres;

--
-- Name: get_option_by_question(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_option_by_question(p_question_id integer) RETURNS TABLE(id integer, option_text text, sort_order integer)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT a.id, a.option_text, a.sort_order
    FROM base.answer_option a
    WHERE a.question_id = p_question_id;
$$;


ALTER FUNCTION base.get_option_by_question(p_question_id integer) OWNER TO postgres;

--
-- Name: get_question_by_test(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_question_by_test(p_test_id integer) RETURNS TABLE(id integer, question_text text, question_type character varying, points integer, sort_order integer)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT q.id, q.question_text, q.question_type, q.points, q.sort_order
    FROM base.question q
    WHERE q.test_id = p_test_id;
$$;


ALTER FUNCTION base.get_question_by_test(p_test_id integer) OWNER TO postgres;

--
-- Name: get_students_by_group(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_students_by_group(p_group_id integer) RETURNS TABLE(user_name text, lastname text, firstname text, patronymic text, student_code text, group_name text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'base', 'pg_temp'
    AS $$
    SELECT u.user_name,
           s.lastname,
           s.firstname,
           s.patronymic,
           s.student_code,
           g."name"
    FROM base.users u
    JOIN base.userrole ur ON ur.user_id = u.id
    JOIN base.userroletype ut ON ut.id = ur.role_id
    JOIN base.student s ON s.role_id = ur.role_id
    JOIN base.studentgroup sg ON sg.student_id = s.id
    JOIN base."groups" g ON g.id = sg.group_id
    WHERE g.id = p_group_id;
$$;


ALTER FUNCTION base.get_students_by_group(p_group_id integer) OWNER TO postgres;

--
-- Name: get_students_by_username(character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_students_by_username(p_user_name character varying) RETURNS TABLE(lastname character varying, firstname character varying, patronymic character varying, groupp character varying)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT s.lastname, s.firstname, s.patronymic, g.name
    FROM base.student s
    JOIN base.userrole ur ON s.role_id = ur.role_id
    JOIN base.users u ON ur.user_id = u.id
    JOIN base.studentgroup sg on sg.student_id = s.id 
    JOIN base.groups g on g.id = sg.group_id
    WHERE u.user_name = p_user_name;
$$;


ALTER FUNCTION base.get_students_by_username(p_user_name character varying) OWNER TO postgres;

--
-- Name: get_task_results(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_task_results(p_task_id integer) RETURNS TABLE(user_name character varying, result_id integer, create_date timestamp without time zone, answertext character varying, result character varying, validation integer, validation_status character varying)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'base', 'public', 'pg_temp'
    AS $$
    SELECT u.user_name,
           t.id AS result_id,
           t.create_date,
           t.answertext,
           t."result",
           t.validation_id,
           v.validation
    FROM base.taskresult t
    join base.validation v on v.id = t.validation_id 
    JOIN base.usertaskanswer ua ON ua.taskresult_id = t.id
    JOIN base.users u ON u.id = ua.user_id
    WHERE t.task_id = p_task_id;
$$;


ALTER FUNCTION base.get_task_results(p_task_id integer) OWNER TO postgres;

--
-- Name: get_task_results_by_username(integer, character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_task_results_by_username(p_task_id integer, p_username character varying) RETURNS TABLE(result_id integer, create_date timestamp without time zone, answertext character varying, result character varying, validation integer, validation_status character varying)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'base', 'public', 'pg_temp'
    AS $$
    SELECT 
           t.id AS result_id,
           t.create_date,
           t.answertext,
           t."result",
           t.validation_id,
           v.validation
    FROM base.taskresult t
    join base.validation v on v.id = t.validation_id 
    JOIN base.usertaskanswer ua ON ua.taskresult_id = t.id
    JOIN base.users u ON u.id = ua.user_id
    WHERE t.task_id = p_task_id and u.user_name = p_username;
$$;


ALTER FUNCTION base.get_task_results_by_username(p_task_id integer, p_username character varying) OWNER TO postgres;

--
-- Name: get_taskresult_by_task_and_user(integer, character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_taskresult_by_task_and_user(p_task_id integer, p_user_name character varying) RETURNS TABLE(id integer, validation character varying, create_date timestamp without time zone, result text, answertext text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT tr.id, v.validation, tr.create_date, tr."result", tr.answertext
    FROM base.taskresult tr
    JOIN base.users u ON u.user_name = p_user_name
    join base.usertaskanswer ua on ua.user_id = u.id 
    join base.validation v on tr.validation_id = v.id
    WHERE tr.id = ua.taskresult_id and tr.task_id = p_task_id;
$$;


ALTER FUNCTION base.get_taskresult_by_task_and_user(p_task_id integer, p_user_name character varying) OWNER TO postgres;

--
-- Name: get_tasks_by_course(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_tasks_by_course(p_course_id integer) RETURNS TABLE(id integer, p_name character varying, start_date date, end_date date)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'base', 'public', 'pg_temp'
    AS $$
    SELECT t.id,
           t."name",
           ti.start_date,
           ti.end_date
    FROM base.task t
    JOIN base.inventorytask it ON it.tasklist_id = t.id
    JOIN base.inventory i ON i.id = it.inventory_id
    JOIN base.coursinventory ci ON ci.inventory_id = i.id
    JOIN base.cours c ON c.id = ci.cours_id
    JOIN base."time" ti ON ti.id = t.time_id
    WHERE c.id = p_course_id;
$$;


ALTER FUNCTION base.get_tasks_by_course(p_course_id integer) OWNER TO postgres;

--
-- Name: get_tasks_by_inventory(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_tasks_by_inventory(p_inventory_id integer) RETURNS TABLE(id integer, time_id integer, name text, qdescription text, adescription text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT tk.id, tk.time_id, tk."name", tk.qdescription, tk.adescription
    FROM base.task tk
    JOIN base.inventorytask it ON tk.id = it.tasklist_id
    WHERE it.inventory_id = p_inventory_id;
$$;


ALTER FUNCTION base.get_tasks_by_inventory(p_inventory_id integer) OWNER TO postgres;

--
-- Name: get_teacher_by_username(text); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_teacher_by_username(p_user_name text) RETURNS TABLE(lastname text, firstname text, patronymic text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'base', 'public', 'pg_temp'
    AS $$
    SELECT t.lastname, t.firstname, t.patronymic
    FROM base.teacher t
    JOIN base.userrole ur ON ur.role_id = t.role_id
    JOIN base.users u ON u.id = ur.user_id
    WHERE u.user_name = p_user_name;
$$;


ALTER FUNCTION base.get_teacher_by_username(p_user_name text) OWNER TO postgres;

--
-- Name: get_test_results_by_test_id(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_test_results_by_test_id(p_test_id integer) RETURNS TABLE(user_name character varying, total_points integer, max_points integer, percentage real)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT DISTINCT ON (u.id)
           u.user_name,
           tr.total_points,
           tr.max_points,
           tr.percentage::real
    FROM base.test_attempt ta
    JOIN base.test_result tr ON tr.attempt_id = ta.id
    JOIN base.users u ON u.id = ta.user_id
    WHERE ta.test_id = p_test_id
    ORDER BY u.id, tr.total_points DESC, tr.percentage DESC, tr.completed_at DESC;
$$;


ALTER FUNCTION base.get_test_results_by_test_id(p_test_id integer) OWNER TO postgres;

--
-- Name: get_test_results_by_test_id_and_username(integer, character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_test_results_by_test_id_and_username(p_test_id integer, p_username character varying) RETURNS TABLE(total_points integer, max_points integer, percentage real)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT DISTINCT ON (u.id)          
           tr.total_points,
           tr.max_points,
           tr.percentage::real
    FROM base.test_attempt ta
    JOIN base.test_result tr ON tr.attempt_id = ta.id
    JOIN base.users u ON u.id = ta.user_id
    WHERE ta.test_id = p_test_id and u.user_name = p_username
    ORDER BY u.id, tr.total_points DESC, tr.percentage DESC, tr.completed_at DESC;
$$;


ALTER FUNCTION base.get_test_results_by_test_id_and_username(p_test_id integer, p_username character varying) OWNER TO postgres;

--
-- Name: get_tests_by_course(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_tests_by_course(p_course_id integer) RETURNS TABLE(id integer, title character varying)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'base', 'public', 'pg_temp'
    AS $$
    SELECT td.id, td.title
    FROM base.test_definition td
    JOIN base.inventorytest it ON it.test_id = td.id
    JOIN base.inventory i ON i.id = it.inventory_id
    JOIN base.coursinventory ci ON ci.inventory_id = i.id
    JOIN base.cours c ON c.id = ci.cours_id
    WHERE c.id = p_course_id;
$$;


ALTER FUNCTION base.get_tests_by_course(p_course_id integer) OWNER TO postgres;

--
-- Name: get_tests_by_inventory(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_tests_by_inventory(p_inventory_id integer) RETURNS TABLE(id integer, title character varying, description text, time_limit_seconds integer, max_attempts integer)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT td.id, td.title, td.description, td.time_limit_seconds, td.max_attempts
    FROM base.test_definition td
    JOIN base.inventorytest it ON td.id = it.inventory_id
    WHERE it.inventory_id = p_inventory_id;
$$;


ALTER FUNCTION base.get_tests_by_inventory(p_inventory_id integer) OWNER TO postgres;

--
-- Name: get_textcontent_by_inventory(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_textcontent_by_inventory(p_inventory_id integer) RETURNS TABLE("textсontent" text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT ti.textсontent
    FROM base.textitem ti
    JOIN base.inventorytext it ON ti.id = it.textitem_id
    WHERE it.inventory_id = p_inventory_id
    ORDER BY ti.id ASC;
$$;


ALTER FUNCTION base.get_textcontent_by_inventory(p_inventory_id integer) OWNER TO postgres;

--
-- Name: get_time_by_id(integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_time_by_id(p_time_id integer) RETURNS TABLE(start_date date, end_date date)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT t.start_date, t.end_date
    FROM base."time" t
    WHERE t.id = p_time_id;
$$;


ALTER FUNCTION base.get_time_by_id(p_time_id integer) OWNER TO postgres;

--
-- Name: insert_test_attempt(integer, character varying, integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.insert_test_attempt(p_test_id integer, p_user_name character varying, p_attempt_number integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_time_limit INTEGER;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_new_id INTEGER;
    v_user_id INTEGER;
    v_max_attempt INTEGER;
BEGIN
    -- Получаем ID пользователя по имени
    SELECT u.id INTO v_user_id
    FROM base.users u
    WHERE u.user_name = p_user_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User with name "%" not found', p_user_name;
    END IF;

    SELECT td.max_attempts INTO v_max_attempt
    FROM base.test_definition td
    WHERE td.id = p_test_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User with name "%" not found', p_user_name;
    END IF;

    IF p_attempt_number > v_max_attempt THEN
        RAISE EXCEPTION 'The number of attempts for the user "%" has been exceeded', p_user_name;
    END IF;

    -- Получаем ограничение по времени для указанного теста
    SELECT td.time_limit_seconds INTO v_time_limit
    FROM base.test_definition td  -- добавлена схема base для единообразия
    WHERE td.id = p_test_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Test with id % not found in test_definition', p_test_id;
    END IF;

    -- Фиксируем время начала попытки
    v_start_time := CURRENT_TIMESTAMP;

    -- Вычисляем время окончания: start_time + time_limit секунд
    v_end_time := v_start_time + (v_time_limit * INTERVAL '1 second');

    -- Вставляем новую запись
    INSERT INTO base.test_attempt (test_id, user_id, attempt_number, start_time, end_time, status)
    VALUES (p_test_id, v_user_id, p_attempt_number, v_start_time, v_end_time, 'in_progress')
    RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$$;


ALTER FUNCTION base.insert_test_attempt(p_test_id integer, p_user_name character varying, p_attempt_number integer) OWNER TO postgres;

--
-- Name: set_answer(character varying, integer, integer, text, integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.set_answer(p_username character varying, p_answer_id integer, p_task_id integer, p_answertext text, p_file_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
v_taskresult_id_old INTEGER;
v_taskresult_id_new INTEGER;
v_user_id INTEGER;
v_validation_id INTEGER;
BEGIN
    Select u.id from base.users u 
    where u.user_name = p_username 
    INTO v_user_id;

    DELETE FROM base.answerfile
    WHERE base.answerfile.taskresult_id = p_answer_id;

    DELETE FROM base.usertaskanswer
    WHERE base.usertaskanswer.user_id = v_user_id
    AND base.usertaskanswer.taskresult_id = p_answer_id;

    DELETE FROM base.taskresult
    WHERE base.taskresult.id = p_answer_id;
    
    INSERT INTO base.validation (user_id,change_date,task_id)
    VALUES (v_user_id,NOW(),p_task_id)
    RETURNING base.validation.id INTO v_validation_id;

    INSERT INTO base.taskresult (task_id,validation_id,create_date,answertext)
    VALUES (p_task_id,v_validation_id,NOW(),p_answertext)
    RETURNING base.taskresult.id INTO v_taskresult_id_new;
    if p_file_id > 0 then
      INSERT INTO base.answerfile (taskresult_id,file_id)
      VALUES (v_taskresult_id_new,p_file_id);        
    end if;
    INSERT INTO base.usertaskanswer (taskresult_id,user_id)
    VALUES (v_taskresult_id_new,v_user_id);
    return true;
END;
$$;


ALTER FUNCTION base.set_answer(p_username character varying, p_answer_id integer, p_task_id integer, p_answertext text, p_file_id integer) OWNER TO postgres;

--
-- Name: upload_file(character varying, character varying, character varying, integer); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.upload_file(p_file_name character varying, p_path character varying, p_extension character varying, p_size integer) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
v_file_id INTEGER;
BEGIN  
    INSERT INTO base.file (file_name,path,extension,size)
    VALUES (p_file_name,p_path,p_extension,p_size)
    RETURNING base.file.id INTO v_file_id;

    return v_file_id;
END;
$$;


ALTER FUNCTION base.upload_file(p_file_name character varying, p_path character varying, p_extension character varying, p_size integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: answer_option; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.answer_option (
    id integer NOT NULL,
    question_id integer NOT NULL,
    option_text text NOT NULL,
    is_correct boolean DEFAULT false,
    sort_order integer DEFAULT 0
);


ALTER TABLE base.answer_option OWNER TO postgres;

--
-- Name: answer_option_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.answer_option_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.answer_option_id_seq OWNER TO postgres;

--
-- Name: answer_option_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.answer_option_id_seq OWNED BY base.answer_option.id;


--
-- Name: answercomment; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.answercomment (
    taskresult_id integer,
    comment_id integer
);


ALTER TABLE base.answercomment OWNER TO postgres;

--
-- Name: answerfile; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.answerfile (
    taskresult_id integer NOT NULL,
    file_id integer
);


ALTER TABLE base.answerfile OWNER TO postgres;

--
-- Name: comment; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.comment (
    id integer NOT NULL,
    comment_text text,
    comment_date timestamp with time zone,
    user_id integer
);


ALTER TABLE base.comment OWNER TO postgres;

--
-- Name: comment_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.comment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.comment_id_seq OWNER TO postgres;

--
-- Name: comment_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.comment_id_seq OWNED BY base.comment.id;


--
-- Name: contentorder; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.contentorder (
    id integer NOT NULL,
    type character varying(255) NOT NULL,
    cotent_order integer NOT NULL,
    inventory_id integer NOT NULL
);


ALTER TABLE base.contentorder OWNER TO postgres;

--
-- Name: contentorder_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.contentorder_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.contentorder_id_seq OWNER TO postgres;

--
-- Name: contentorder_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.contentorder_id_seq OWNED BY base.contentorder.id;


--
-- Name: cours; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.cours (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    start_date date,
    end_date date
);


ALTER TABLE base.cours OWNER TO postgres;

--
-- Name: cours_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.cours_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.cours_id_seq OWNER TO postgres;

--
-- Name: cours_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.cours_id_seq OWNED BY base.cours.id;


--
-- Name: coursgroup; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.coursgroup (
    course_id integer NOT NULL,
    groupe_id integer
);


ALTER TABLE base.coursgroup OWNER TO postgres;

--
-- Name: coursinventory; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.coursinventory (
    cours_id integer,
    inventory_id integer
);


ALTER TABLE base.coursinventory OWNER TO postgres;

--
-- Name: file; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.file (
    id integer NOT NULL,
    file_name character varying(255),
    path character varying(255),
    extension character varying(10),
    size integer
);


ALTER TABLE base.file OWNER TO postgres;

--
-- Name: file_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.file_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.file_id_seq OWNER TO postgres;

--
-- Name: file_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.file_id_seq OWNED BY base.file.id;


--
-- Name: groups; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.groups (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    academic_year character varying(20),
    max_students integer
);


ALTER TABLE base.groups OWNER TO postgres;

--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.groups_id_seq OWNER TO postgres;

--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.groups_id_seq OWNED BY base.groups.id;


--
-- Name: inventory; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.inventory (
    id integer NOT NULL,
    create_state timestamp without time zone,
    que_date timestamp without time zone
);


ALTER TABLE base.inventory OWNER TO postgres;

--
-- Name: inventory_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.inventory_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.inventory_id_seq OWNER TO postgres;

--
-- Name: inventory_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.inventory_id_seq OWNED BY base.inventory.id;


--
-- Name: inventoryfile; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.inventoryfile (
    inventory_id integer NOT NULL,
    file_id integer
);


ALTER TABLE base.inventoryfile OWNER TO postgres;

--
-- Name: inventorytask; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.inventorytask (
    inventory_id integer,
    tasklist_id integer
);


ALTER TABLE base.inventorytask OWNER TO postgres;

--
-- Name: inventorytest; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.inventorytest (
    test_id integer,
    inventory_id integer
);


ALTER TABLE base.inventorytest OWNER TO postgres;

--
-- Name: inventorytext; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.inventorytext (
    inventory_id integer NOT NULL,
    textitem_id integer
);


ALTER TABLE base.inventorytext OWNER TO postgres;

--
-- Name: question; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.question (
    id integer NOT NULL,
    test_id integer NOT NULL,
    question_text text NOT NULL,
    question_type character varying(50) NOT NULL,
    points integer DEFAULT 1,
    sort_order integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    correct_text text
);


ALTER TABLE base.question OWNER TO postgres;

--
-- Name: question_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.question_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.question_id_seq OWNER TO postgres;

--
-- Name: question_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.question_id_seq OWNED BY base.question.id;


--
-- Name: salt; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.salt (
    id integer NOT NULL,
    salt character varying(255)
);


ALTER TABLE base.salt OWNER TO postgres;

--
-- Name: salt_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.salt_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.salt_id_seq OWNER TO postgres;

--
-- Name: salt_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.salt_id_seq OWNED BY base.salt.id;


--
-- Name: student; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.student (
    id integer NOT NULL,
    lastname character varying(255) NOT NULL,
    firstname character varying(255) NOT NULL,
    patronymic character varying(255),
    student_code character varying(255) NOT NULL,
    role_id integer NOT NULL
);


ALTER TABLE base.student OWNER TO postgres;

--
-- Name: student_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.student_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.student_id_seq OWNER TO postgres;

--
-- Name: student_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.student_id_seq OWNED BY base.student.id;


--
-- Name: studentgroup; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.studentgroup (
    student_id integer,
    group_id integer
);


ALTER TABLE base.studentgroup OWNER TO postgres;

--
-- Name: task; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.task (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    time_id integer,
    qdescription text,
    adescription text
);


ALTER TABLE base.task OWNER TO postgres;

--
-- Name: task_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.task_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.task_id_seq OWNER TO postgres;

--
-- Name: task_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.task_id_seq OWNED BY base.task.id;


--
-- Name: taskfile; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.taskfile (
    task_id integer NOT NULL,
    file_id integer
);


ALTER TABLE base.taskfile OWNER TO postgres;

--
-- Name: taskresult; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.taskresult (
    id integer NOT NULL,
    task_id integer NOT NULL,
    validation_id integer,
    create_date timestamp without time zone,
    result character varying(255),
    answertext text
);


ALTER TABLE base.taskresult OWNER TO postgres;

--
-- Name: taskresult_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.taskresult_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.taskresult_id_seq OWNER TO postgres;

--
-- Name: taskresult_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.taskresult_id_seq OWNED BY base.taskresult.id;


--
-- Name: teacher; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.teacher (
    id integer NOT NULL,
    lastname character varying(255) NOT NULL,
    firstname character varying(255) NOT NULL,
    patronymic character varying(255),
    teacher_code character varying(255) NOT NULL,
    role_id integer NOT NULL
);


ALTER TABLE base.teacher OWNER TO postgres;

--
-- Name: teacher_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.teacher_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.teacher_id_seq OWNER TO postgres;

--
-- Name: teacher_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.teacher_id_seq OWNED BY base.teacher.id;


--
-- Name: teachercours; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.teachercours (
    course_id integer NOT NULL,
    teacher_id integer
);


ALTER TABLE base.teachercours OWNER TO postgres;

--
-- Name: teachergroup; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.teachergroup (
    teacher_id integer,
    group_id integer
);


ALTER TABLE base.teachergroup OWNER TO postgres;

--
-- Name: test_attempt; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.test_attempt (
    id integer NOT NULL,
    test_id integer NOT NULL,
    user_id integer NOT NULL,
    attempt_number integer NOT NULL,
    start_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    end_time timestamp without time zone,
    status character varying(50) DEFAULT 'in_progress'::character varying
);


ALTER TABLE base.test_attempt OWNER TO postgres;

--
-- Name: test_attempt_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.test_attempt_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.test_attempt_id_seq OWNER TO postgres;

--
-- Name: test_attempt_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.test_attempt_id_seq OWNED BY base.test_attempt.id;


--
-- Name: test_definition; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.test_definition (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    time_limit_seconds integer,
    max_attempts integer DEFAULT 1,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE base.test_definition OWNER TO postgres;

--
-- Name: test_definition_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.test_definition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.test_definition_id_seq OWNER TO postgres;

--
-- Name: test_definition_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.test_definition_id_seq OWNED BY base.test_definition.id;


--
-- Name: test_result; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.test_result (
    id integer NOT NULL,
    attempt_id integer NOT NULL,
    total_points integer,
    max_points integer,
    percentage numeric(5,2),
    completed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE base.test_result OWNER TO postgres;

--
-- Name: test_result_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.test_result_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.test_result_id_seq OWNER TO postgres;

--
-- Name: test_result_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.test_result_id_seq OWNED BY base.test_result.id;


--
-- Name: textitem; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.textitem (
    id integer NOT NULL,
    "textсontent" text
);


ALTER TABLE base.textitem OWNER TO postgres;

--
-- Name: textitem_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.textitem_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.textitem_id_seq OWNER TO postgres;

--
-- Name: textitem_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.textitem_id_seq OWNED BY base.textitem.id;


--
-- Name: time; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base."time" (
    id integer NOT NULL,
    name character varying(255),
    start_date date,
    end_date date
);


ALTER TABLE base."time" OWNER TO postgres;

--
-- Name: time_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.time_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.time_id_seq OWNER TO postgres;

--
-- Name: time_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.time_id_seq OWNED BY base."time".id;


--
-- Name: userrole; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.userrole (
    user_id integer,
    role_id integer
);


ALTER TABLE base.userrole OWNER TO postgres;

--
-- Name: userroletype; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.userroletype (
    id integer NOT NULL,
    role_name character varying(255) NOT NULL,
    permission_oid character varying(255)
);


ALTER TABLE base.userroletype OWNER TO postgres;

--
-- Name: userroletype_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.userroletype_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.userroletype_id_seq OWNER TO postgres;

--
-- Name: userroletype_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.userroletype_id_seq OWNED BY base.userroletype.id;


--
-- Name: users; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.users (
    id integer NOT NULL,
    user_name character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    email character varying(255),
    is_active boolean DEFAULT true,
    create_at timestamp without time zone,
    salt_id integer
);


ALTER TABLE base.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.users_id_seq OWNED BY base.users.id;


--
-- Name: usertaskanswer; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.usertaskanswer (
    taskresult_id integer,
    user_id integer
);


ALTER TABLE base.usertaskanswer OWNER TO postgres;

--
-- Name: validation; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.validation (
    id integer NOT NULL,
    validation character varying(255) DEFAULT 'verification'::character varying NOT NULL,
    user_id integer,
    change_date timestamp without time zone,
    task_id integer
);


ALTER TABLE base.validation OWNER TO postgres;

--
-- Name: validation_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.validation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.validation_id_seq OWNER TO postgres;

--
-- Name: validation_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.validation_id_seq OWNED BY base.validation.id;


--
-- Name: answer_option id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.answer_option ALTER COLUMN id SET DEFAULT nextval('base.answer_option_id_seq'::regclass);


--
-- Name: comment id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.comment ALTER COLUMN id SET DEFAULT nextval('base.comment_id_seq'::regclass);


--
-- Name: contentorder id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.contentorder ALTER COLUMN id SET DEFAULT nextval('base.contentorder_id_seq'::regclass);


--
-- Name: cours id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.cours ALTER COLUMN id SET DEFAULT nextval('base.cours_id_seq'::regclass);


--
-- Name: file id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.file ALTER COLUMN id SET DEFAULT nextval('base.file_id_seq'::regclass);


--
-- Name: groups id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.groups ALTER COLUMN id SET DEFAULT nextval('base.groups_id_seq'::regclass);


--
-- Name: inventory id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.inventory ALTER COLUMN id SET DEFAULT nextval('base.inventory_id_seq'::regclass);


--
-- Name: question id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.question ALTER COLUMN id SET DEFAULT nextval('base.question_id_seq'::regclass);


--
-- Name: salt id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.salt ALTER COLUMN id SET DEFAULT nextval('base.salt_id_seq'::regclass);


--
-- Name: student id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.student ALTER COLUMN id SET DEFAULT nextval('base.student_id_seq'::regclass);


--
-- Name: task id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.task ALTER COLUMN id SET DEFAULT nextval('base.task_id_seq'::regclass);


--
-- Name: taskresult id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.taskresult ALTER COLUMN id SET DEFAULT nextval('base.taskresult_id_seq'::regclass);


--
-- Name: teacher id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.teacher ALTER COLUMN id SET DEFAULT nextval('base.teacher_id_seq'::regclass);


--
-- Name: test_attempt id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test_attempt ALTER COLUMN id SET DEFAULT nextval('base.test_attempt_id_seq'::regclass);


--
-- Name: test_definition id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test_definition ALTER COLUMN id SET DEFAULT nextval('base.test_definition_id_seq'::regclass);


--
-- Name: test_result id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test_result ALTER COLUMN id SET DEFAULT nextval('base.test_result_id_seq'::regclass);


--
-- Name: textitem id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.textitem ALTER COLUMN id SET DEFAULT nextval('base.textitem_id_seq'::regclass);


--
-- Name: time id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base."time" ALTER COLUMN id SET DEFAULT nextval('base.time_id_seq'::regclass);


--
-- Name: userroletype id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.userroletype ALTER COLUMN id SET DEFAULT nextval('base.userroletype_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.users ALTER COLUMN id SET DEFAULT nextval('base.users_id_seq'::regclass);


--
-- Name: validation id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.validation ALTER COLUMN id SET DEFAULT nextval('base.validation_id_seq'::regclass);


--
-- Data for Name: answer_option; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.answer_option (id, question_id, option_text, is_correct, sort_order) FROM stdin;
1	1	SELECT	t	1
2	1	INSERT	f	2
3	1	UPDATE	f	3
4	1	DELETE	f	4
5	2	MERGE	f	1
6	2	JOIN	t	2
7	2	UNION	f	3
8	2	GROUP BY	f	4
9	3	COUNT	t	1
10	3	AVG	t	2
11	3	SUM	t	3
12	3	ORDER BY	f	4
13	3	WHERE	f	5
14	5	VARCHAR	f	1
15	5	DATE	f	2
16	5	INT	t	3
17	5	BOOLEAN	f	4
\.


--
-- Data for Name: answercomment; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.answercomment (taskresult_id, comment_id) FROM stdin;
1	1
2	2
3	3
1	9
1	10
\.


--
-- Data for Name: answerfile; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.answerfile (taskresult_id, file_id) FROM stdin;
1	11
2	12
\.


--
-- Data for Name: comment; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.comment (id, comment_text, comment_date, user_id) FROM stdin;
1	Принято	2026-04-23 20:51:52.818334+03	1
2	На доработку	2026-04-23 20:52:16.668663+03	1
3	Отклонено	2026-04-23 20:52:28.439526+03	1
9	На доработку	2026-04-24 14:03:50.111398+03	1
10	Тест принятия	2026-05-04 16:01:38.5748+03	1
\.


--
-- Data for Name: contentorder; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.contentorder (id, type, cotent_order, inventory_id) FROM stdin;
1	text	0	1
2	task	1	1
3	text	0	2
4	task	1	2
5	text	0	3
6	task	1	3
7	text	0	4
8	task	1	4
9	text	0	5
10	task	1	5
11	text	0	6
12	task	1	6
13	text	0	7
14	task	1	7
15	text	0	8
16	task	1	8
17	text	0	9
18	task	1	9
19	text	0	10
20	task	1	10
21	test	2	1
\.


--
-- Data for Name: cours; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.cours (id, name, description, start_date, end_date) FROM stdin;
1	Основы SQL	Введение в базы данных и SQL запросы	2026-01-01	2026-06-01
2	Веб-разработка	HTML, CSS и JavaScript с нуля	2026-01-15	2026-06-15
3	Алгоритмы	Структуры данных и алгоритмы	2026-02-01	2026-07-01
4	Математика	Высшая математика для программистов	2026-01-01	2026-05-30
5	Физика	Общая физика	2026-01-01	2026-05-30
6	Английский язык	Technical English	2026-01-01	2026-06-01
7	Операционные системы	Linux и Windows internals	2026-03-01	2026-08-01
8	Компьютерные сети	TCP/IP и протоколы	2026-03-01	2026-08-01
9	Git и DevOps	Системы контроля версий	2026-02-15	2026-07-15
10	Тестирование ПО	QA Manual и Automation	2026-04-01	2026-09-01
\.


--
-- Data for Name: coursgroup; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.coursgroup (course_id, groupe_id) FROM stdin;
1	1
1	2
1	3
1	4
1	5
2	1
2	2
2	3
2	4
2	5
3	1
3	2
3	3
3	4
3	5
4	1
4	2
4	3
4	4
4	5
5	1
5	2
5	3
5	4
5	5
6	1
6	2
6	3
7	1
7	2
7	3
8	1
8	2
8	3
9	1
9	2
9	3
10	1
10	2
10	3
\.


--
-- Data for Name: coursinventory; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.coursinventory (cours_id, inventory_id) FROM stdin;
1	1
2	2
3	3
4	4
5	5
6	6
7	7
8	8
9	9
10	10
\.


--
-- Data for Name: file; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.file (id, file_name, path, extension, size) FROM stdin;
1	lecture_sql_intro	/files/courses/	pdf	1024
2	task_sql_queries	/files/tasks/	docx	512
3	lecture_html_basics	/files/courses/	pdf	2048
4	task_layout	/files/tasks/	zip	1024
5	lecture_algorithms	/files/courses/	pdf	4096
6	task_sorting	/files/tasks/	py	256
7	lecture_math	/files/courses/	pdf	8192
8	task_integrals	/files/tasks/	pdf	512
9	lecture_physics	/files/courses/	pdf	16384
10	task_mechanics	/files/tasks/	docx	1024
11	diagram...d7d39a2a-3ed1-4151-aad2-3be62d00bc21	./file/answers/	png	21715
12	diagram...dfd57de7-7329-4ff5-bef6-26794fb4a181	./file/answers/	svg	31573
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.groups (id, name, academic_year, max_students) FROM stdin;
1	ИВТ-101	2024	30
2	ИВТ-102	2024	30
3	ИВТ-201	2023	25
4	ИВТ-202	2023	25
5	ИВТ-301	2022	20
\.


--
-- Data for Name: inventory; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.inventory (id, create_state, que_date) FROM stdin;
1	2026-04-23 23:41:59.042896	2026-06-01 00:00:00
2	2026-04-23 23:41:59.042896	2026-06-15 00:00:00
3	2026-04-23 23:41:59.042896	2026-07-01 00:00:00
4	2026-04-23 23:41:59.042896	2026-05-30 00:00:00
5	2026-04-23 23:41:59.042896	2026-05-30 00:00:00
6	2026-04-23 23:41:59.042896	2026-06-01 00:00:00
7	2026-04-23 23:41:59.042896	2026-08-01 00:00:00
8	2026-04-23 23:41:59.042896	2026-08-01 00:00:00
9	2026-04-23 23:41:59.042896	2026-07-15 00:00:00
10	2026-04-23 23:41:59.042896	2026-09-01 00:00:00
\.


--
-- Data for Name: inventoryfile; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.inventoryfile (inventory_id, file_id) FROM stdin;
1	1
1	2
2	3
2	4
3	5
3	6
4	7
4	8
5	9
5	10
\.


--
-- Data for Name: inventorytask; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.inventorytask (inventory_id, tasklist_id) FROM stdin;
1	1
2	2
3	3
4	4
5	5
6	6
7	7
8	8
9	9
10	10
\.


--
-- Data for Name: inventorytest; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.inventorytest (test_id, inventory_id) FROM stdin;
1	1
\.


--
-- Data for Name: inventorytext; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.inventorytext (inventory_id, textitem_id) FROM stdin;
1	1
2	2
3	3
4	4
5	5
6	6
7	7
8	8
9	9
10	10
\.


--
-- Data for Name: question; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.question (id, test_id, question_text, question_type, points, sort_order, created_at, correct_text) FROM stdin;
1	1	Какой оператор используется для извлечения данных из таблицы?	single_choice	1	1	2026-04-23 23:41:59.072711	\N
2	1	Какое ключевое слово используется для объединения двух таблиц по общему столбцу?	single_choice	1	2	2026-04-23 23:41:59.074547	\N
3	1	Какие из следующих функций являются агрегатными в SQL?	multiple_choice	2	3	2026-04-23 23:41:59.075224	\N
5	1	Какой тип данных в SQL используется для хранения целых чисел?	single_choice	1	5	2026-04-23 23:41:59.076348	\N
4	1	Напишите SQL-запрос, который выбирает столбцы "name" и "age" из таблицы "users" для всех пользователей старше 18 лет.	text	3	4	2026-04-23 23:41:59.075798	123
\.


--
-- Data for Name: salt; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.salt (id, salt) FROM stdin;
1	$2a$06$SIWnlmwBETk1vRBFcLCO3e
2	$2a$06$6PeBeAR6azXj9uHF6FXRWe
3	$2a$06$icaNOki2xQJnPPf34gavh.
4	$2a$06$fxKxRmi4mMYj1wTESSaeGe
5	$2a$06$edC48bqqQDPVM4cFGKbWS.
6	$2a$06$JSAvvlfyU3ZhZOzn2sBgqu
7	$2a$06$8baMadEoZOmXbdaY7eiAle
8	$2a$06$93Ba9Faaqx/TFHOHyiBTIO
9	$2a$06$U4U1sUSPTPjgykXAAZj5be
10	$2a$06$54XjXeM/bYGcWJnRb7IjNO
11	$2a$06$Ek/rYxW03iwgafcsORAee.
12	$2a$06$QPZE8eaE3hLmrSzt1cHLdu
13	$2a$06$4ZtcW9BcaZ831AqgW4scC.
14	$2a$06$zJae9ET.DKouWkpkSmEeze
15	$2a$06$mZyPScowPTErEOSarPHvbu
16	$2a$06$31z8klUF3Xhj6LuBwfUCHu
17	$2a$06$iN60dvHJ2rVy9oSF3q7eue
18	$2a$06$ai4yaauQUJgRuTy7XqVzIe
19	$2a$06$GQkv2V3/nSh.dctLXyKnzO
20	$2a$06$DoxiSjcU.8emJt4P1Z730.
21	$2a$06$NLNWzYywXnP/ZLv5XUnis.
22	$2a$06$CCbEIU4rB.JP5uR4yL.Rr.
23	$2a$06$Y3aX2JdfKfBryzGYcG7dKe
24	$2a$06$dhuRCVTfQqfpbCDXMJxHX.
25	$2a$06$1zCVSUpFhcjaPagvdIQSgu
\.


--
-- Data for Name: student; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.student (id, lastname, firstname, patronymic, student_code, role_id) FROM stdin;
1	Иванов	Иван	Иванович	STU-001	6
2	Петров	Петр	Петрович	STU-002	7
3	Сидоров	Сидор	Сидорович	STU-003	8
4	Козлов	Алексей	Николаевич	STU-004	9
5	Новиков	Дмитрий	Алексеевич	STU-005	10
6	Морозов	Сергей	Владимирович	STU-006	11
7	Волков	Андрей	Сергеевич	STU-007	12
8	Соловьев	Михаил	Андреевич	STU-008	13
9	Васильев	Николай	Иванович	STU-009	14
10	Зайцев	Павел	Петрович	STU-010	15
11	Павлов	Евгений	Сергеевич	STU-011	16
12	Семенов	Виктор	Михайлович	STU-012	17
13	Голубев	Роман	Дмитриевич	STU-013	18
14	Виноградов	Игорь	Алексеевич	STU-014	19
15	Богданов	Олег	Викторович	STU-015	20
16	Воробьев	Никита	Павлович	STU-016	21
17	Федоров	Артем	Евгеньевич	STU-017	22
18	Михайлов	Денис	Викторович	STU-018	23
19	Беляев	Владимир	Олегович	STU-019	24
20	Тарасов	Константин	Никитич	STU-020	25
\.


--
-- Data for Name: studentgroup; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.studentgroup (student_id, group_id) FROM stdin;
1	1
2	1
3	1
4	2
5	2
6	2
7	3
8	3
9	3
10	4
11	4
12	4
13	5
14	5
15	5
16	1
17	2
18	3
19	4
20	5
\.


--
-- Data for Name: task; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.task (id, name, time_id, qdescription, adescription) FROM stdin;
1	Задание 1: SQL запросы	1	Напишите 5 SELECT запросов к базе данных.	Прикрепите файл с кодом.
2	Задание 2: Верстка страницы	1	Сверстайте лендинг по макету.	Прикрепите архив с проектом.
3	Задание 3: Реализация сортировки	1	Реализуйте алгоритм быстрой сортировки.	Код на Python или Java.
4	Задание 4: Решение интегралов	1	Решите 10 интегралов из списка.	Фото или PDF с решениями.
5	Задание 5: Лабораторная по механике	1	Проведите эксперимент и опишите результаты.	Отчет в Word.
6	Задание 6: Эссе на английском	1	Напишите эссе на тему "My Future Career".	Текст не менее 200 слов.
7	Задание 7: Скрипт на Bash	1	Напишите скрипт для автоматизации бэкапов.	Файл .sh
8	Задание 8: Настройка Wireshark	1	Перехватите и проанализируйте пакеты.	Скриншоты и выводы.
9	Задание 9: Работа с ветками Git	1	Создайте репозиторий, сделайте 5 коммитов.	Ссылка на GitHub.
10	Задание 10: Тест-кейсы	1	Составьте 10 тест-кейсов для формы логина.	Таблица Excel.
\.


--
-- Data for Name: taskfile; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.taskfile (task_id, file_id) FROM stdin;
1	2
2	4
3	6
4	8
5	10
\.


--
-- Data for Name: taskresult; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.taskresult (id, task_id, validation_id, create_date, result, answertext) FROM stdin;
4	1	4	2026-04-23 20:50:26.376178	\N	Ответ 2 без файла
2	1	6	2026-04-23 20:49:09.906668	0	Ответ 2 с файлом
3	1	7	2026-04-23 20:49:34.92466	0	Ответ 1 без файла
1	1	13	2026-04-23 20:48:30.393639	5	Ответ 1 с файлом
\.


--
-- Data for Name: teacher; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.teacher (id, lastname, firstname, patronymic, teacher_code, role_id) FROM stdin;
1	Смирнов	Иван	Петрович	TEA-001	1
2	Кузнецов	Алексей	Сергеевич	TEA-002	2
3	Попов	Дмитрий	Андреевич	TEA-003	3
4	Васильев	Максим	Иванович	TEA-004	4
5	Соколов	Артем	Дмитриевич	TEA-005	5
\.


--
-- Data for Name: teachercours; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.teachercours (course_id, teacher_id) FROM stdin;
1	1
2	1
3	1
4	2
5	2
6	3
7	3
8	4
9	4
10	5
\.


--
-- Data for Name: teachergroup; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.teachergroup (teacher_id, group_id) FROM stdin;
1	1
1	2
2	3
2	4
3	5
4	1
5	2
\.


--
-- Data for Name: test_attempt; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.test_attempt (id, test_id, user_id, attempt_number, start_time, end_time, status) FROM stdin;
1	1	6	1	2026-04-23 20:42:09.032643	2026-04-23 20:42:39.032643	completed
2	1	7	1	2026-04-23 20:43:01.830992	2026-04-23 20:43:31.830992	completed
3	1	6	2	2026-04-23 20:46:37.040048	2026-04-23 20:47:07.040048	completed
4	1	9	1	2026-04-23 20:49:52.687283	2026-04-23 20:50:22.687283	in_progress
5	1	8	1	2026-04-24 11:07:32.733598	2026-04-24 11:08:02.733598	completed
6	1	7	2	2026-05-04 13:00:12.764528	2026-05-04 13:00:42.764528	completed
\.


--
-- Data for Name: test_definition; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.test_definition (id, title, description, time_limit_seconds, max_attempts, created_at) FROM stdin;
1	Основы SQL	Тест проверяет базовые знания SQL: SELECT, JOIN, агрегатные функции и типы данных.	30	2	2026-04-23 23:41:59.071072
\.


--
-- Data for Name: test_result; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.test_result (id, attempt_id, total_points, max_points, percentage, completed_at) FROM stdin;
1	1	4	5	80.00	2026-04-23 20:42:30.676465
2	2	4	8	50.00	2026-04-23 20:44:25.054924
3	3	8	8	100.00	2026-04-23 20:46:46.207256
4	5	1	8	12.50	2026-04-24 11:07:41.083703
5	6	1	8	12.50	2026-05-04 13:00:25.689905
\.


--
-- Data for Name: textitem; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.textitem (id, "textсontent") FROM stdin;
1	<h3>Лекция 1: Введение в SQL</h3><p>SQL (Structured Query Language) — это язык структурированных запросов...</p>
2	<h3>Лекция 2: Основы HTML</h3><p>HTML (HyperText Markup Language) — стандартный язык гипертекстовой разметки...</p>
3	<h3>Лекция 3: Алгоритмы сортировки</h3><p>Сортировка — процесс упорядочивания элементов...</p>
4	<h3>Лекция 4: Математический анализ</h3><p>Пределы, производные, интегралы...</p>
5	<h3>Лекция 5: Механика</h3><p>Законы Ньютона, кинематика...</p>
6	<h3>Lesson 1: Basics</h3><p>Introduction to technical English...</p>
7	<h3>Лекция 7: Процессы в Linux</h3><p>Управление процессами, сигналы...</p>
8	<h3>Лекция 8: Модель OSI</h3><p>Сетевые протоколы и уровни...</p>
9	<h3>Лекция 9: Git basics</h3><p>Системы контроля версий...</p>
10	<h3>Лекция 10: Виды тестирования</h3><p>Unit, Integration, E2E тесты...</p>
\.


--
-- Data for Name: time; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base."time" (id, name, start_date, end_date) FROM stdin;
1	Первое второе	2026-01-01	2026-05-25
2	Весна 2026	2026-02-01	2026-06-30
3	Весна 2026	2026-02-01	2026-06-30
4	Весна 2026	2026-02-01	2026-06-30
5	Весна 2026	2026-02-01	2026-06-30
6	Весна 2026	2026-02-01	2026-06-30
7	Весна 2026	2026-02-01	2026-06-30
\.


--
-- Data for Name: userrole; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.userrole (user_id, role_id) FROM stdin;
1	1
2	2
3	3
4	4
5	5
6	6
7	7
8	8
9	9
10	10
11	11
12	12
13	13
14	14
15	15
16	16
17	17
18	18
19	19
20	20
21	21
22	22
23	23
24	24
25	25
\.


--
-- Data for Name: userroletype; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.userroletype (id, role_name, permission_oid) FROM stdin;
1	teacher	PERM-TEA-001
2	teacher	PERM-TEA-002
3	teacher	PERM-TEA-003
4	teacher	PERM-TEA-004
5	teacher	PERM-TEA-005
6	student	PERM-STU-001
7	student	PERM-STU-002
8	student	PERM-STU-003
9	student	PERM-STU-004
10	student	PERM-STU-005
11	student	PERM-STU-006
12	student	PERM-STU-007
13	student	PERM-STU-008
14	student	PERM-STU-009
15	student	PERM-STU-010
16	student	PERM-STU-011
17	student	PERM-STU-012
18	student	PERM-STU-013
19	student	PERM-STU-014
20	student	PERM-STU-015
21	student	PERM-STU-016
22	student	PERM-STU-017
23	student	PERM-STU-018
24	student	PERM-STU-019
25	student	PERM-STU-020
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.users (id, user_name, password_hash, email, is_active, create_at, salt_id) FROM stdin;
1	teacher_1	e46dce02aff8bf76525f2d3e4c16839217a6919faf0e87278ebb4b98d845c954	teacher1@university.ru	t	2026-04-23 23:41:58.976246	1
2	teacher_2	f7f1a5862307d2e2c9d7a98a1f3aba330ce6362e1560bf548af65d22e652c2da	teacher2@university.ru	t	2026-04-23 23:41:58.979742	2
3	teacher_3	a9ccfc7574d00944bfa32457931cd0ae50d8ffb84ad9e7078d07ef0c825ebd9b	teacher3@university.ru	t	2026-04-23 23:41:58.980532	3
4	teacher_4	c742b01b25a7a79c9ea6c8ad43aaf6ad4416b27f39930ff4cf6222b9354edbd7	teacher4@university.ru	t	2026-04-23 23:41:58.981384	4
5	teacher_5	3dbffa0bbd8fa05ead3de440ea07e4384c3c9f29e738f808f49a3feda9b9252c	teacher5@university.ru	t	2026-04-23 23:41:58.982227	5
6	student_1	e4d9c0149f42d370847eedcf591503859a5fb62179138846e04e9806400e2bc0	student1@university.ru	t	2026-04-23 23:41:58.982925	6
7	student_2	fba84cbe035fe6149829df1ca4ba95e4c06a88e227a37a9aee9af833fe045c70	student2@university.ru	t	2026-04-23 23:41:58.983506	7
8	student_3	766a6cf71b56fbc4f4b070704162ef472d493b2ebd7cf78b832ba6009bc66ac9	student3@university.ru	t	2026-04-23 23:41:58.984063	8
9	student_4	c051a2ca187a9a35e0cbc64e027da7b08855dd16fb3c2d631ee84b0d9a4d9152	student4@university.ru	t	2026-04-23 23:41:58.984599	9
10	student_5	ac229ca0b18fd9f922472b5b1418672747efbc2cd63ae8a1eb79fc3d99223a56	student5@university.ru	t	2026-04-23 23:41:58.985066	10
11	student_6	99278ed51006d77a050b39d45c782929c6b488a3cd253226a3de5d8bfd4c0d4c	student6@university.ru	t	2026-04-23 23:41:58.985626	11
12	student_7	79a2a83c2649d1aa8c74356320f111487f8090c4019b0cc9507778f2db0493eb	student7@university.ru	t	2026-04-23 23:41:58.986164	12
13	student_8	5866d7d871e45ca7dd000462b6b62681cda21e78310b8be2c033706c75d69f3b	student8@university.ru	t	2026-04-23 23:41:58.986657	13
14	student_9	186b827c01c5acc62b3616e9abd564d43147bc4057ddae35a1c324116b3853fb	student9@university.ru	t	2026-04-23 23:41:58.987152	14
15	student_10	586fb2493ea6f01e3db565b579884246fc7d9ad0726d37c5683db3062e92577a	student10@university.ru	t	2026-04-23 23:41:58.987701	15
16	student_11	3fcc40dc7f21d24ce46cd07c8394d57998088b8fa3248a3500222b94dc5d5795	student11@university.ru	t	2026-04-23 23:41:58.98822	16
17	student_12	a2718f4e0ab4280f4142b6ca79cc07e18c23f12e928d2ccf9f86978734a03bd8	student12@university.ru	t	2026-04-23 23:41:58.988717	17
18	student_13	f869d5e93a5108a91fa3ed7d92cc606cbd5b0296ccb44d69e0a28f7f14738ebd	student13@university.ru	t	2026-04-23 23:41:58.989217	18
19	student_14	71df35a9c2fa5c94b3e198093815cfaa69007ea555fbff60108275f37d4ab0b7	student14@university.ru	t	2026-04-23 23:41:58.98971	19
20	student_15	e4b7f024d0fd8f0d34069c7f600ef512d48714de649ba76067d57d5c83552a6e	student15@university.ru	t	2026-04-23 23:41:58.990189	20
21	student_16	7143cfda5068139192ab92c88d502c27a16fee7e5413876130e0995e346d9b58	student16@university.ru	t	2026-04-23 23:41:58.990643	21
22	student_17	25d8073af37cd9ea145471c0b05cfcebe37a7f526fdf7e17a94dca4403f8bdd6	student17@university.ru	t	2026-04-23 23:41:58.991108	22
23	student_18	1b5f9a4440068c505f46ce2b16ba9bc804b0e4a717ee2d58a2805e8d6d1f562c	student18@university.ru	t	2026-04-23 23:41:58.991568	23
24	student_19	a1d24fd65c0b81320e28d6175a8419194f56129f2da585adab9e36b2b6a23f96	student19@university.ru	t	2026-04-23 23:41:58.992053	24
25	student_20	e75a9f110f7e7292f952870923449866b1964155742efae20ebff762bbca9388	student20@university.ru	t	2026-04-23 23:41:58.992526	25
\.


--
-- Data for Name: usertaskanswer; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.usertaskanswer (taskresult_id, user_id) FROM stdin;
1	6
2	7
3	8
4	9
\.


--
-- Data for Name: validation; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.validation (id, validation, user_id, change_date, task_id) FROM stdin;
1	verification	6	2026-04-23 20:48:30.393639	1
2	verification	7	2026-04-23 20:49:09.906668	1
3	verification	8	2026-04-23 20:49:34.92466	1
4	verification	9	2026-04-23 20:50:26.376178	1
5	aproved	1	2026-04-23 20:51:52.818334	1
6	redevelopment	1	2026-04-23 20:52:16.668663	1
7	rejected	1	2026-04-23 20:52:28.439526	1
8	aproved	1	2026-04-23 21:05:28.035135	1
9	aproved	1	2026-04-23 21:17:11.376318	1
10	aproved	1	2026-04-23 21:26:14.946501	1
11	aproved	6	2026-04-23 21:35:47.073062	1
12	redevelopment	1	2026-04-24 11:03:50.111398	1
13	aproved	1	2026-05-04 13:01:38.5748	1
\.


--
-- Name: answer_option_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.answer_option_id_seq', 17, true);


--
-- Name: comment_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.comment_id_seq', 10, true);


--
-- Name: contentorder_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.contentorder_id_seq', 21, true);


--
-- Name: cours_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.cours_id_seq', 10, true);


--
-- Name: file_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.file_id_seq', 12, true);


--
-- Name: groups_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.groups_id_seq', 5, true);


--
-- Name: inventory_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.inventory_id_seq', 10, true);


--
-- Name: question_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.question_id_seq', 5, true);


--
-- Name: salt_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.salt_id_seq', 25, true);


--
-- Name: student_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.student_id_seq', 20, true);


--
-- Name: task_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.task_id_seq', 10, true);


--
-- Name: taskresult_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.taskresult_id_seq', 4, true);


--
-- Name: teacher_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.teacher_id_seq', 5, true);


--
-- Name: test_attempt_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.test_attempt_id_seq', 6, true);


--
-- Name: test_definition_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.test_definition_id_seq', 1, true);


--
-- Name: test_result_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.test_result_id_seq', 5, true);


--
-- Name: textitem_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.textitem_id_seq', 10, true);


--
-- Name: time_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.time_id_seq', 7, true);


--
-- Name: userroletype_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.userroletype_id_seq', 25, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.users_id_seq', 25, true);


--
-- Name: validation_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.validation_id_seq', 13, true);


--
-- Name: answer_option answer_option_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.answer_option
    ADD CONSTRAINT answer_option_pkey PRIMARY KEY (id);


--
-- Name: comment comment_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.comment
    ADD CONSTRAINT comment_pkey PRIMARY KEY (id);


--
-- Name: contentorder contentorder_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.contentorder
    ADD CONSTRAINT contentorder_pkey PRIMARY KEY (id);


--
-- Name: cours cours_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.cours
    ADD CONSTRAINT cours_pkey PRIMARY KEY (id);


--
-- Name: file file_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.file
    ADD CONSTRAINT file_pkey PRIMARY KEY (id);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (id);


--
-- Name: question question_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.question
    ADD CONSTRAINT question_pkey PRIMARY KEY (id);


--
-- Name: salt salt_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.salt
    ADD CONSTRAINT salt_pkey PRIMARY KEY (id);


--
-- Name: student student_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.student
    ADD CONSTRAINT student_pkey PRIMARY KEY (id);


--
-- Name: student student_student_code_key; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.student
    ADD CONSTRAINT student_student_code_key UNIQUE (student_code);


--
-- Name: task task_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.task
    ADD CONSTRAINT task_pkey PRIMARY KEY (id);


--
-- Name: taskresult taskresult_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.taskresult
    ADD CONSTRAINT taskresult_pkey PRIMARY KEY (id);


--
-- Name: teacher teacher_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.teacher
    ADD CONSTRAINT teacher_pkey PRIMARY KEY (id);


--
-- Name: test_attempt test_attempt_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test_attempt
    ADD CONSTRAINT test_attempt_pkey PRIMARY KEY (id);


--
-- Name: test_attempt test_attempt_test_id_user_id_attempt_number_key; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test_attempt
    ADD CONSTRAINT test_attempt_test_id_user_id_attempt_number_key UNIQUE (test_id, user_id, attempt_number);


--
-- Name: test_definition test_definition_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test_definition
    ADD CONSTRAINT test_definition_pkey PRIMARY KEY (id);


--
-- Name: test_result test_result_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test_result
    ADD CONSTRAINT test_result_pkey PRIMARY KEY (id);


--
-- Name: textitem textitem_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.textitem
    ADD CONSTRAINT textitem_pkey PRIMARY KEY (id);


--
-- Name: time time_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base."time"
    ADD CONSTRAINT time_pkey PRIMARY KEY (id);


--
-- Name: userrole userrole_role_id_key; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.userrole
    ADD CONSTRAINT userrole_role_id_key UNIQUE (role_id);


--
-- Name: userroletype userroletype_permission_oid_key; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.userroletype
    ADD CONSTRAINT userroletype_permission_oid_key UNIQUE (permission_oid);


--
-- Name: userroletype userroletype_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.userroletype
    ADD CONSTRAINT userroletype_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_user_name_key; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.users
    ADD CONSTRAINT users_user_name_key UNIQUE (user_name);


--
-- Name: validation validation_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.validation
    ADD CONSTRAINT validation_pkey PRIMARY KEY (id);


--
-- Name: answer_option answer_option_question_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.answer_option
    ADD CONSTRAINT answer_option_question_id_fkey FOREIGN KEY (question_id) REFERENCES base.question(id) ON DELETE CASCADE;


--
-- Name: answercomment answercomment_comment_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.answercomment
    ADD CONSTRAINT answercomment_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES base.comment(id);


--
-- Name: answercomment answercomment_taskresult_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.answercomment
    ADD CONSTRAINT answercomment_taskresult_id_fkey FOREIGN KEY (taskresult_id) REFERENCES base.taskresult(id);


--
-- Name: answerfile answerfile_file_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.answerfile
    ADD CONSTRAINT answerfile_file_id_fkey FOREIGN KEY (file_id) REFERENCES base.file(id);


--
-- Name: answerfile answerfile_taskresult_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.answerfile
    ADD CONSTRAINT answerfile_taskresult_id_fkey FOREIGN KEY (taskresult_id) REFERENCES base.taskresult(id);


--
-- Name: comment comment_user_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.comment
    ADD CONSTRAINT comment_user_id_fkey FOREIGN KEY (user_id) REFERENCES base.users(id);


--
-- Name: contentorder contentorder_inventory_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.contentorder
    ADD CONSTRAINT contentorder_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES base.inventory(id);


--
-- Name: coursgroup coursgroup_course_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.coursgroup
    ADD CONSTRAINT coursgroup_course_id_fkey FOREIGN KEY (course_id) REFERENCES base.cours(id);


--
-- Name: coursgroup coursgroup_groupe_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.coursgroup
    ADD CONSTRAINT coursgroup_groupe_id_fkey FOREIGN KEY (groupe_id) REFERENCES base.groups(id);


--
-- Name: coursinventory coursinventory_cours_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.coursinventory
    ADD CONSTRAINT coursinventory_cours_id_fkey FOREIGN KEY (cours_id) REFERENCES base.cours(id);


--
-- Name: coursinventory coursinventory_inventory_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.coursinventory
    ADD CONSTRAINT coursinventory_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES base.inventory(id);


--
-- Name: inventorytest courstest_inventory_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.inventorytest
    ADD CONSTRAINT courstest_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES base.inventory(id);


--
-- Name: inventorytest courstest_test_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.inventorytest
    ADD CONSTRAINT courstest_test_id_fkey FOREIGN KEY (test_id) REFERENCES base.test_definition(id);


--
-- Name: inventoryfile inventoryfile_file_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.inventoryfile
    ADD CONSTRAINT inventoryfile_file_id_fkey FOREIGN KEY (file_id) REFERENCES base.file(id);


--
-- Name: inventoryfile inventoryfile_inventory_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.inventoryfile
    ADD CONSTRAINT inventoryfile_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES base.inventory(id);


--
-- Name: inventorytask inventorytask_inventory_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.inventorytask
    ADD CONSTRAINT inventorytask_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES base.inventory(id);


--
-- Name: inventorytask inventorytask_tasklist_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.inventorytask
    ADD CONSTRAINT inventorytask_tasklist_id_fkey FOREIGN KEY (tasklist_id) REFERENCES base.task(id);


--
-- Name: inventorytext inventorytext_inventory_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.inventorytext
    ADD CONSTRAINT inventorytext_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES base.inventory(id);


--
-- Name: inventorytext inventorytext_textitem_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.inventorytext
    ADD CONSTRAINT inventorytext_textitem_id_fkey FOREIGN KEY (textitem_id) REFERENCES base.textitem(id);


--
-- Name: question question_test_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.question
    ADD CONSTRAINT question_test_id_fkey FOREIGN KEY (test_id) REFERENCES base.test_definition(id) ON DELETE CASCADE;


--
-- Name: student student_role_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.student
    ADD CONSTRAINT student_role_id_fkey FOREIGN KEY (role_id) REFERENCES base.userroletype(id);


--
-- Name: studentgroup studentgroup_group_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.studentgroup
    ADD CONSTRAINT studentgroup_group_id_fkey FOREIGN KEY (group_id) REFERENCES base.groups(id);


--
-- Name: studentgroup studentgroup_student_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.studentgroup
    ADD CONSTRAINT studentgroup_student_id_fkey FOREIGN KEY (student_id) REFERENCES base.student(id);


--
-- Name: task task_time_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.task
    ADD CONSTRAINT task_time_id_fkey FOREIGN KEY (time_id) REFERENCES base."time"(id);


--
-- Name: taskfile taskfile_file_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.taskfile
    ADD CONSTRAINT taskfile_file_id_fkey FOREIGN KEY (file_id) REFERENCES base.file(id);


--
-- Name: taskfile taskfile_task_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.taskfile
    ADD CONSTRAINT taskfile_task_id_fkey FOREIGN KEY (task_id) REFERENCES base.task(id);


--
-- Name: taskresult taskresult_task_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.taskresult
    ADD CONSTRAINT taskresult_task_id_fkey FOREIGN KEY (task_id) REFERENCES base.task(id);


--
-- Name: taskresult taskresult_validation_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.taskresult
    ADD CONSTRAINT taskresult_validation_id_fkey FOREIGN KEY (validation_id) REFERENCES base.validation(id);


--
-- Name: teacher teacher_role_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.teacher
    ADD CONSTRAINT teacher_role_id_fkey FOREIGN KEY (role_id) REFERENCES base.userroletype(id);


--
-- Name: teachercours teachercours_course_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.teachercours
    ADD CONSTRAINT teachercours_course_id_fkey FOREIGN KEY (course_id) REFERENCES base.cours(id);


--
-- Name: teachercours teachercours_teacher_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.teachercours
    ADD CONSTRAINT teachercours_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES base.teacher(id);


--
-- Name: teachergroup teachergroup_group_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.teachergroup
    ADD CONSTRAINT teachergroup_group_id_fkey FOREIGN KEY (group_id) REFERENCES base.groups(id);


--
-- Name: teachergroup teachergroup_student_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.teachergroup
    ADD CONSTRAINT teachergroup_student_id_fkey FOREIGN KEY (teacher_id) REFERENCES base.teacher(id);


--
-- Name: test_attempt test_attempt_test_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test_attempt
    ADD CONSTRAINT test_attempt_test_id_fkey FOREIGN KEY (test_id) REFERENCES base.test_definition(id) ON DELETE CASCADE;


--
-- Name: test_attempt test_attempt_user_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test_attempt
    ADD CONSTRAINT test_attempt_user_id_fkey FOREIGN KEY (user_id) REFERENCES base.users(id) ON DELETE CASCADE;


--
-- Name: test_result test_result_attempt_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test_result
    ADD CONSTRAINT test_result_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES base.test_attempt(id) ON DELETE CASCADE;


--
-- Name: userrole userrole_role_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.userrole
    ADD CONSTRAINT userrole_role_id_fkey FOREIGN KEY (role_id) REFERENCES base.userroletype(id);


--
-- Name: userrole userrole_user_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.userrole
    ADD CONSTRAINT userrole_user_id_fkey FOREIGN KEY (user_id) REFERENCES base.users(id);


--
-- Name: users users_salt_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.users
    ADD CONSTRAINT users_salt_id_fkey FOREIGN KEY (salt_id) REFERENCES base.salt(id);


--
-- Name: usertaskanswer usertaskanswer_taskresult_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.usertaskanswer
    ADD CONSTRAINT usertaskanswer_taskresult_id_fkey FOREIGN KEY (taskresult_id) REFERENCES base.taskresult(id);


--
-- Name: usertaskanswer usertaskanswer_user_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.usertaskanswer
    ADD CONSTRAINT usertaskanswer_user_id_fkey FOREIGN KEY (user_id) REFERENCES base.users(id);


--
-- Name: validation validation_task_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.validation
    ADD CONSTRAINT validation_task_id_fkey FOREIGN KEY (task_id) REFERENCES base.task(id);


--
-- Name: validation validation_user_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.validation
    ADD CONSTRAINT validation_user_id_fkey FOREIGN KEY (user_id) REFERENCES base.users(id);


--
-- Name: SCHEMA base; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA base TO admin;
GRANT USAGE ON SCHEMA base TO "publicUser";
GRANT USAGE ON SCHEMA base TO "studentUser";


--
-- Name: FUNCTION add_comment_to_taskresult(p_username text, p_taskresult_id integer, p_comment_text text); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.add_comment_to_taskresult(p_username text, p_taskresult_id integer, p_comment_text text) TO admin;


--
-- Name: PROCEDURE add_test(); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON PROCEDURE base.add_test() TO admin;


--
-- Name: PROCEDURE add_user(IN p_user_name character varying, IN p_email character varying, IN p_password character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON PROCEDURE base.add_user(IN p_user_name character varying, IN p_email character varying, IN p_password character varying) TO admin;
GRANT ALL ON PROCEDURE base.add_user(IN p_user_name character varying, IN p_email character varying, IN p_password character varying) TO "publicUser";


--
-- Name: FUNCTION authenticate_role(p_login character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.authenticate_role(p_login character varying) TO admin;


--
-- Name: FUNCTION authenticate_user(p_login character varying, p_password character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.authenticate_user(p_login character varying, p_password character varying) TO "publicUser";


--
-- Name: FUNCTION binding_role(p_login character varying, role_pasword character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.binding_role(p_login character varying, role_pasword character varying) TO admin;


--
-- Name: FUNCTION complete_test_attempt(p_attempt_id integer, p_total_points integer, p_max_points integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.complete_test_attempt(p_attempt_id integer, p_total_points integer, p_max_points integer) TO admin;


--
-- Name: FUNCTION create_validation_and_update_taskresult(p_validation character varying, p_result character varying, p_task_id integer, p_taskresult_id integer, p_username character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.create_validation_and_update_taskresult(p_validation character varying, p_result character varying, p_task_id integer, p_taskresult_id integer, p_username character varying) TO admin;


--
-- Name: FUNCTION get_attempt_count(p_test_id integer, p_username character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_attempt_count(p_test_id integer, p_username character varying) TO admin;


--
-- Name: FUNCTION get_best_test_result(p_user_name text, p_test_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_best_test_result(p_user_name text, p_test_id integer) TO admin;


--
-- Name: FUNCTION get_combined_questions(td_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_combined_questions(td_id integer) TO admin;


--
-- Name: FUNCTION get_comments_by_taskresult(p_taskresult_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_comments_by_taskresult(p_taskresult_id integer) TO admin;


--
-- Name: FUNCTION get_contentorder_by_course(p_course_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_contentorder_by_course(p_course_id integer) TO admin;


--
-- Name: FUNCTION get_courses_by_teacher(p_user_name character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_courses_by_teacher(p_user_name character varying) TO admin;


--
-- Name: FUNCTION get_courses_by_username(p_user_name character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_courses_by_username(p_user_name character varying) TO admin;


--
-- Name: FUNCTION get_file_by_id(p_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_file_by_id(p_id integer) TO admin;


--
-- Name: FUNCTION get_files_by_answer(p_answer_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_files_by_answer(p_answer_id integer) TO admin;


--
-- Name: FUNCTION get_files_by_inventory(p_inventory_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_files_by_inventory(p_inventory_id integer) TO admin;


--
-- Name: FUNCTION get_files_by_task(p_task_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_files_by_task(p_task_id integer) TO admin;


--
-- Name: FUNCTION get_group_by_course(p_course_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_group_by_course(p_course_id integer) TO admin;


--
-- Name: FUNCTION get_group_by_teacher(p_user_name character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_group_by_teacher(p_user_name character varying) TO admin;


--
-- Name: FUNCTION get_option_by_question(p_question_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_option_by_question(p_question_id integer) TO admin;


--
-- Name: FUNCTION get_question_by_test(p_test_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_question_by_test(p_test_id integer) TO admin;


--
-- Name: FUNCTION get_students_by_group(p_group_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_students_by_group(p_group_id integer) TO admin;


--
-- Name: FUNCTION get_students_by_username(p_user_name character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_students_by_username(p_user_name character varying) TO admin;


--
-- Name: FUNCTION get_task_results(p_task_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_task_results(p_task_id integer) TO admin;


--
-- Name: FUNCTION get_task_results_by_username(p_task_id integer, p_username character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_task_results_by_username(p_task_id integer, p_username character varying) TO admin;


--
-- Name: FUNCTION get_taskresult_by_task_and_user(p_task_id integer, p_user_name character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_taskresult_by_task_and_user(p_task_id integer, p_user_name character varying) TO admin;


--
-- Name: FUNCTION get_tasks_by_course(p_course_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_tasks_by_course(p_course_id integer) TO admin;


--
-- Name: FUNCTION get_tasks_by_inventory(p_inventory_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_tasks_by_inventory(p_inventory_id integer) TO admin;


--
-- Name: FUNCTION get_teacher_by_username(p_user_name text); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_teacher_by_username(p_user_name text) TO admin;


--
-- Name: FUNCTION get_test_results_by_test_id(p_test_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_test_results_by_test_id(p_test_id integer) TO admin;


--
-- Name: FUNCTION get_test_results_by_test_id_and_username(p_test_id integer, p_username character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_test_results_by_test_id_and_username(p_test_id integer, p_username character varying) TO admin;


--
-- Name: FUNCTION get_tests_by_course(p_course_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_tests_by_course(p_course_id integer) TO admin;


--
-- Name: FUNCTION get_tests_by_inventory(p_inventory_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_tests_by_inventory(p_inventory_id integer) TO admin;


--
-- Name: FUNCTION get_textcontent_by_inventory(p_inventory_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_textcontent_by_inventory(p_inventory_id integer) TO admin;


--
-- Name: FUNCTION get_time_by_id(p_time_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_time_by_id(p_time_id integer) TO admin;


--
-- Name: FUNCTION insert_test_attempt(p_test_id integer, p_user_name character varying, p_attempt_number integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.insert_test_attempt(p_test_id integer, p_user_name character varying, p_attempt_number integer) TO admin;


--
-- Name: FUNCTION set_answer(p_username character varying, p_answer_id integer, p_task_id integer, p_answertext text, p_file_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.set_answer(p_username character varying, p_answer_id integer, p_task_id integer, p_answertext text, p_file_id integer) TO admin;


--
-- Name: FUNCTION upload_file(p_file_name character varying, p_path character varying, p_extension character varying, p_size integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.upload_file(p_file_name character varying, p_path character varying, p_extension character varying, p_size integer) TO admin;


--
-- Name: TABLE answer_option; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.answer_option TO admin;


--
-- Name: TABLE answercomment; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.answercomment TO admin;


--
-- Name: TABLE answerfile; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.answerfile TO admin;


--
-- Name: TABLE comment; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.comment TO admin;


--
-- Name: TABLE contentorder; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.contentorder TO admin;


--
-- Name: TABLE cours; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.cours TO admin;


--
-- Name: TABLE coursgroup; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.coursgroup TO admin;


--
-- Name: TABLE coursinventory; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.coursinventory TO admin;


--
-- Name: TABLE file; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.file TO admin;


--
-- Name: TABLE groups; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.groups TO admin;


--
-- Name: TABLE inventory; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.inventory TO admin;


--
-- Name: TABLE inventoryfile; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.inventoryfile TO admin;


--
-- Name: TABLE inventorytask; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.inventorytask TO admin;


--
-- Name: TABLE inventorytest; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.inventorytest TO admin;


--
-- Name: TABLE inventorytext; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.inventorytext TO admin;


--
-- Name: TABLE question; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.question TO admin;


--
-- Name: TABLE salt; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.salt TO admin;


--
-- Name: TABLE student; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.student TO admin;


--
-- Name: TABLE studentgroup; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.studentgroup TO admin;


--
-- Name: TABLE task; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.task TO admin;


--
-- Name: TABLE taskfile; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.taskfile TO admin;


--
-- Name: TABLE taskresult; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.taskresult TO admin;


--
-- Name: TABLE teacher; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.teacher TO admin;


--
-- Name: TABLE teachercours; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.teachercours TO admin;


--
-- Name: TABLE teachergroup; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.teachergroup TO admin;


--
-- Name: TABLE test_attempt; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.test_attempt TO admin;


--
-- Name: TABLE test_definition; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.test_definition TO admin;


--
-- Name: TABLE test_result; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.test_result TO admin;


--
-- Name: TABLE textitem; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.textitem TO admin;


--
-- Name: TABLE "time"; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base."time" TO admin;


--
-- Name: TABLE userrole; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.userrole TO admin;


--
-- Name: TABLE userroletype; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.userroletype TO admin;


--
-- Name: TABLE users; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.users TO admin;
GRANT SELECT ON TABLE base.users TO "publicUser";


--
-- Name: TABLE usertaskanswer; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.usertaskanswer TO admin;


--
-- Name: TABLE validation; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.validation TO admin;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: base; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA base GRANT ALL ON FUNCTIONS TO admin;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: base; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA base GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLES TO admin;


--
-- PostgreSQL database dump complete
--

