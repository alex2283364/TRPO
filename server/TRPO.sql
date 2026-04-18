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
    JOIN base.userrole ur ON ur.role_id = s.id
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
-- Name: get_students_by_username(character varying); Type: FUNCTION; Schema: base; Owner: postgres
--

CREATE FUNCTION base.get_students_by_username(p_user_name character varying) RETURNS TABLE(lastname character varying, firstname character varying, patronymic character varying, groupp character varying)
    LANGUAGE sql SECURITY DEFINER
    AS $$
    SELECT s.lastname, s.firstname, s.patronymic, g.name
    FROM base.student s
    JOIN base.userrole ur ON s.id = ur.role_id
    JOIN base.users u ON ur.user_id = u.id
    JOIN base.studentgroup sg on sg.student_id = s.id 
    JOIN base.groups g on g.id = sg.group_id
    WHERE u.user_name = p_user_name;
$$;


ALTER FUNCTION base.get_students_by_username(p_user_name character varying) OWNER TO postgres;

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

    INSERT INTO base.answerfile (taskresult_id,file_id)
    VALUES (v_taskresult_id_new,p_file_id);   

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
    comment_date date,
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
-- Name: courstest; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.courstest (
    test_id integer,
    inventory_id integer
);


ALTER TABLE base.courstest OWNER TO postgres;

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
-- Name: inventorytext; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.inventorytext (
    inventory_id integer NOT NULL,
    textitem_id integer
);


ALTER TABLE base.inventorytext OWNER TO postgres;

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
    student_id integer,
    group_id integer
);


ALTER TABLE base.teachergroup OWNER TO postgres;

--
-- Name: test; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.test (
    id integer NOT NULL,
    test_result_id integer,
    time_id integer NOT NULL,
    description text,
    attempts_count integer
);


ALTER TABLE base.test OWNER TO postgres;

--
-- Name: test_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.test_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.test_id_seq OWNER TO postgres;

--
-- Name: test_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.test_id_seq OWNED BY base.test.id;


--
-- Name: testresult; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.testresult (
    id integer NOT NULL,
    mark integer,
    create_date timestamp without time zone
);


ALTER TABLE base.testresult OWNER TO postgres;

--
-- Name: testresult_id_seq; Type: SEQUENCE; Schema: base; Owner: postgres
--

CREATE SEQUENCE base.testresult_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE base.testresult_id_seq OWNER TO postgres;

--
-- Name: testresult_id_seq; Type: SEQUENCE OWNED BY; Schema: base; Owner: postgres
--

ALTER SEQUENCE base.testresult_id_seq OWNED BY base.testresult.id;


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
-- Name: usertestanswer; Type: TABLE; Schema: base; Owner: postgres
--

CREATE TABLE base.usertestanswer (
    testresult_id integer,
    user_id integer,
    type character varying(255),
    relevance character varying(255)
);


ALTER TABLE base.usertestanswer OWNER TO postgres;

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
-- Name: test id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test ALTER COLUMN id SET DEFAULT nextval('base.test_id_seq'::regclass);


--
-- Name: testresult id; Type: DEFAULT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.testresult ALTER COLUMN id SET DEFAULT nextval('base.testresult_id_seq'::regclass);


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
-- Data for Name: answercomment; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.answercomment (taskresult_id, comment_id) FROM stdin;
\.


--
-- Data for Name: answerfile; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.answerfile (taskresult_id, file_id) FROM stdin;
12	13
13	14
6	6
\.


--
-- Data for Name: comment; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.comment (id, comment_text, comment_date, user_id) FROM stdin;
\.


--
-- Data for Name: contentorder; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.contentorder (id, type, cotent_order, inventory_id) FROM stdin;
1	text	0	1
2	file	1	1
3	text	2	1
4	file	3	1
5	task	4	1
6	text	0	2
7	task	1	2
8	text	0	3
9	task	1	3
10	task	5	1
\.


--
-- Data for Name: cours; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.cours (id, name, description, start_date, end_date) FROM stdin;
1	Курс1	Описание Курс1	2026-01-01	2026-05-25
2	Курс2	Описание Курс2	2026-01-02	2026-05-26
3	КурсОбщий	Описание КурсОбщий	2026-05-27	2026-05-10
\.


--
-- Data for Name: coursgroup; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.coursgroup (course_id, groupe_id) FROM stdin;
1	1
2	2
3	1
3	2
\.


--
-- Data for Name: coursinventory; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.coursinventory (cours_id, inventory_id) FROM stdin;
1	1
2	2
3	3
\.


--
-- Data for Name: courstest; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.courstest (test_id, inventory_id) FROM stdin;
\.


--
-- Data for Name: file; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.file (id, file_name, path, extension, size) FROM stdin;
2	test	file/inventory/	pdf	\N
1	test	file/inventory/	txt	\N
3	task	file/task/	docx	\N
10	test	test/	file/test	8
12	АИС ЛР + 5-6 (1)...48ccee4c-c4fa-43e6-8b06-8e20c77e6aaf	./file/answers/	docx	27978
13	10.Доклад...7c6accb4-090d-453b-bb95-b8aee8541269	./file/answers/	docx	504607
14	Solid_AdultEn...304439e5-f09f-4dde-83d5-6605233c6f35	./file/answers/	xml	319785
4	FinOptimaProcess...1f22e1ea-b198-4596-8b7b-eacf2a98785c	./file/answers/	bpmn	11026
5	АИС. Лабораторные 5-6 теория...2843ef03-05a0-4d50-a1e7-fddd01dbabcd	./file/answers/	pdf	4768083
6	edited_image (8)...6f4e7fec-2ebb-4eb4-a3a3-c9bb0c38b907	./file/answers/	png	4620602
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.groups (id, name, academic_year, max_students) FROM stdin;
1	ЙЦУ-124	1	20
2	ЙЦУ-125	2	19
\.


--
-- Data for Name: inventory; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.inventory (id, create_state, que_date) FROM stdin;
1	2026-01-01 00:00:00	2026-05-25 00:00:00
2	2026-01-01 00:00:00	2026-05-25 00:00:00
3	2026-05-25 00:00:00	2026-06-25 00:00:00
\.


--
-- Data for Name: inventoryfile; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.inventoryfile (inventory_id, file_id) FROM stdin;
1	1
1	2
\.


--
-- Data for Name: inventorytask; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.inventorytask (inventory_id, tasklist_id) FROM stdin;
1	1
2	2
3	3
1	4
\.


--
-- Data for Name: inventorytext; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.inventorytext (inventory_id, textitem_id) FROM stdin;
1	1
1	2
2	3
3	4
\.


--
-- Data for Name: salt; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.salt (id, salt) FROM stdin;
1	_J9..at6Z
4	_J9..cBOB
6	_J9..opjZ
7	_J9..V3jC
8	_J9..Vv5y
14	_J9..PUAR
15	_J9..C9MO
16	_J9..fwxQ
21	_J9..2x4q
22	_J9..I.o5
24	_J9..6wmB
25	_J9..YNMr
27	_J9...I1R
32	_J9...JdO
33	$2a$06$qMfDNnl1e1LW1RuA5nUXrO
39	$2a$06$p.krzDlwa1udkp6GIlQjyu
44	$2a$06$VkyleTES55ANWX7qcb/5Cu
45	$2a$06$DJeumJs70nBt6DBp5uEFYO
48	$2a$06$LLgioi5aB6dNZbeUQH5Y/u
49	$2a$06$zu45OPPXKDkzaT8i1jOUA.
51	$2a$06$.1uERzu1Q8TqMxi3wswGbu
52	$2a$06$7h0nLhAl8pOdM3wxcFvEr.
82	$2a$06$V.EBj7v/7M.G6lOtZ3SeCO
\.


--
-- Data for Name: student; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.student (id, lastname, firstname, patronymic, student_code, role_id) FROM stdin;
1	Иванов	Иван	Иванович	АБВГ-012345	1
2	Иванов	Андрей	Иванович	АБВГ-012346	2
3	Иванов	Сергей	Иванович	АБВГ-012347	3
\.


--
-- Data for Name: studentgroup; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.studentgroup (student_id, group_id) FROM stdin;
1	1
2	2
3	2
\.


--
-- Data for Name: task; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.task (id, name, time_id, qdescription, adescription) FROM stdin;
2	Задание Курс2	1	Задание Курс2 описание	Описание ответа Курс2
3	Задание КурсОбщий	1	Задание КурсОбщий описание	Описание ответа 1 КурсОбщий
1	Задание1 Курс1	1	Задание 1 описание	Описание ответа 1
4	Задание2 Курс1	1	Задание 2 описание	Описание ответа 2
\.


--
-- Data for Name: taskfile; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.taskfile (task_id, file_id) FROM stdin;
1	3
\.


--
-- Data for Name: taskresult; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.taskresult (id, task_id, validation_id, create_date, result, answertext) FROM stdin;
12	3	2	2026-03-26 17:00:15.1		ТЕСТ ТЕСТ ТЕСТ ТЕСТ ТЕСТ ТЕСТ ТЕСТ ТЕСТ
13	3	3	2026-03-26 17:01:26.232		ТЕСТ ТЕСТ ТЕСТ ТЕСТ ТЕСТ ТЕСТ ТЕСТ ТЕСТ
6	1	8	2026-04-18 15:41:18.517234	\N	Новый ответ 3
\.


--
-- Data for Name: teacher; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.teacher (id, lastname, firstname, patronymic, teacher_code, role_id) FROM stdin;
\.


--
-- Data for Name: teachercours; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.teachercours (course_id, teacher_id) FROM stdin;
\.


--
-- Data for Name: teachergroup; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.teachergroup (student_id, group_id) FROM stdin;
\.


--
-- Data for Name: test; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.test (id, test_result_id, time_id, description, attempts_count) FROM stdin;
\.


--
-- Data for Name: testresult; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.testresult (id, mark, create_date) FROM stdin;
\.


--
-- Data for Name: textitem; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.textitem (id, "textсontent") FROM stdin;
2	Тест текста2
1	Тест текста1
3	Текст курс 2
4	Текст курс общий
\.


--
-- Data for Name: time; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base."time" (id, name, start_date, end_date) FROM stdin;
1	Первое второе	2026-01-01	2026-05-25
\.


--
-- Data for Name: userrole; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.userrole (user_id, role_id) FROM stdin;
48	1
49	2
60	3
\.


--
-- Data for Name: userroletype; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.userroletype (id, role_name, permission_oid) FROM stdin;
1	student	0BLA-Yqh
2	student	0BLA-Yqt
3	student	0BLA-Yqe
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.users (id, user_name, password_hash, email, is_active, create_at, salt_id) FROM stdin;
1	john_doe	520feeb8898dad775fa6e6fe8d03824fbfa27a3d6d759b61ab6873ddc0dc5108	john@example.com	t	2026-03-10 19:30:41.573	1
4	john_doe2	0ac49be484e36fb89558af5e84f12981f23e69da2528b458380283bdf9d10c7c	john2@example.com	t	2026-03-10 19:41:22.263	4
6	john_doe3	530b3351ebced3a7f39c13270fe2705e60b8f7fc0d71de314e3dd572169f4876	john3@example.com	t	2026-03-10 19:50:54.084	6
7	john_doe4	b5a80c883bd9605c9f2c91a6638ca0b5b8543e2ce1964e5237662984d2c64457	john4@example.com	t	2026-03-10 19:52:14.832	7
8	qwe	feb00bddfade771c0bc54be021c411d68026bad6f726ebbd25cdeda4b85d4d9b	asd	t	2026-03-10 20:21:39.302	8
14	alice	64e46e292d6dcc75ceb86f85f81e24641e0270cc23e764945f00a96c3f4ab573	alice@example.com	t	2026-03-10 17:45:51.008	14
15	alice2	1250d7c38bd70cc8f72ecac1522c00fac65feb5599e5a1228cf1652ca4063d51	alice2@example.com	t	2026-03-10 17:46:12.109	15
16	alice3	466033cf0e644844b6e1f1ba560e45e3c5abe77a650c35a6ed0ed028629ce80d	alice3@example.com	t	2026-03-10 17:55:42.626	16
21	alice4	51593e9a1ba3fdfd72caf4909e769e5c5c7e581041bebe6d339f1638467a9fa9	alice4@example.com	t	2026-03-10 18:21:22.726	21
25	test	a8f90766339d02ee501143a4fb5d578e5b2730835adcf88174d5170950fefb00	test@yandex.ru	t	2026-03-10 20:02:04.069	25
32	test2	0025b5d01641eb5a135ddfdd8d03fb75154da5bc2c458b8817e61389dae4dcb5	tes2t@yandex.ru	t	2026-03-10 20:04:10.89	32
33	test3	a16c7942d98c1486d35cd290ae999262d29a5a92b743b6ba16ca718f79db8808	test3@test.test	t	2026-03-10 20:07:22.706	33
39	john_doe5	8d6617d1ad9589ed09e207745e4f9675c02362abf2f39aa2973804eff1d8f84f	john5@example.com	t	2026-03-11 12:16:09.18	39
44	qwe2	ddae3ad6d9f6c392f39384b41e637c4873dd8f26a7e7dfb91b97ad87a6752b2e	asd2	t	2026-03-11 12:23:48.419	44
45	qwe3	263c2ef0980c7248a68ba360d0950d7f77b4979653dbbca01a30628389a049c1	asd3	t	2026-03-11 12:24:35.377	45
48	test5	bc2701ae59b1b1e377b01913519bb31e88bdd75451643e1beb0e970aeba873e2	test5@test.test	t	2026-03-11 09:38:57.54	48
49	test6	1cf9df01b9dabdacd419a7ff5827c475d6f2d2bfa2c4b2986f1721bb1add53b3	test6@test.test	t	2026-03-11 11:03:44.151	49
60	test7	09668eaf712691a57ea4f346a5e86a4278c2f178a218326aa86f9f4347abb5c5	test7@test.test	t	2026-04-10 11:09:01.588094	82
\.


--
-- Data for Name: usertaskanswer; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.usertaskanswer (taskresult_id, user_id) FROM stdin;
12	49
13	48
6	48
\.


--
-- Data for Name: usertestanswer; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.usertestanswer (testresult_id, user_id, type, relevance) FROM stdin;
\.


--
-- Data for Name: validation; Type: TABLE DATA; Schema: base; Owner: postgres
--

COPY base.validation (id, validation, user_id, change_date, task_id) FROM stdin;
1	verification	1	2026-04-01 00:00:00	\N
2	verification	1	2026-04-01 00:00:00	\N
3	verification	1	2026-04-01 00:00:00	\N
5	verification	48	2026-04-18 17:26:58.811061	\N
6	verification	48	2026-04-18 15:31:48.360321	\N
7	verification	48	2026-04-18 15:32:21.944682	\N
8	verification	48	2026-04-18 15:41:18.517234	1
\.


--
-- Name: comment_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.comment_id_seq', 1, false);


--
-- Name: contentorder_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.contentorder_id_seq', 1, false);


--
-- Name: cours_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.cours_id_seq', 1, false);


--
-- Name: file_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.file_id_seq', 6, true);


--
-- Name: groups_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.groups_id_seq', 1, false);


--
-- Name: inventory_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.inventory_id_seq', 1, false);


--
-- Name: salt_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.salt_id_seq', 82, true);


--
-- Name: student_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.student_id_seq', 1, false);


--
-- Name: task_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.task_id_seq', 1, false);


--
-- Name: taskresult_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.taskresult_id_seq', 6, true);


--
-- Name: teacher_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.teacher_id_seq', 1, false);


--
-- Name: test_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.test_id_seq', 1, false);


--
-- Name: testresult_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.testresult_id_seq', 1, false);


--
-- Name: textitem_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.textitem_id_seq', 1, false);


--
-- Name: time_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.time_id_seq', 1, false);


--
-- Name: userroletype_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.userroletype_id_seq', 1, false);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.users_id_seq', 60, true);


--
-- Name: validation_id_seq; Type: SEQUENCE SET; Schema: base; Owner: postgres
--

SELECT pg_catalog.setval('base.validation_id_seq', 8, true);


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
-- Name: test test_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test
    ADD CONSTRAINT test_pkey PRIMARY KEY (id);


--
-- Name: testresult testresult_pkey; Type: CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.testresult
    ADD CONSTRAINT testresult_pkey PRIMARY KEY (id);


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
-- Name: courstest courstest_inventory_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.courstest
    ADD CONSTRAINT courstest_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES base.inventory(id);


--
-- Name: courstest courstest_test_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.courstest
    ADD CONSTRAINT courstest_test_id_fkey FOREIGN KEY (test_id) REFERENCES base.test(id);


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
    ADD CONSTRAINT teachergroup_student_id_fkey FOREIGN KEY (student_id) REFERENCES base.teacher(id);


--
-- Name: test test_test_result_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test
    ADD CONSTRAINT test_test_result_id_fkey FOREIGN KEY (test_result_id) REFERENCES base.testresult(id);


--
-- Name: test test_time_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.test
    ADD CONSTRAINT test_time_id_fkey FOREIGN KEY (time_id) REFERENCES base."time"(id);


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
-- Name: usertestanswer usertestanswer_testresult_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.usertestanswer
    ADD CONSTRAINT usertestanswer_testresult_id_fkey FOREIGN KEY (testresult_id) REFERENCES base.testresult(id);


--
-- Name: usertestanswer usertestanswer_user_id_fkey; Type: FK CONSTRAINT; Schema: base; Owner: postgres
--

ALTER TABLE ONLY base.usertestanswer
    ADD CONSTRAINT usertestanswer_user_id_fkey FOREIGN KEY (user_id) REFERENCES base.users(id);


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
-- Name: FUNCTION get_contentorder_by_course(p_course_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_contentorder_by_course(p_course_id integer) TO admin;


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
-- Name: FUNCTION get_students_by_username(p_user_name character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_students_by_username(p_user_name character varying) TO admin;


--
-- Name: FUNCTION get_taskresult_by_task_and_user(p_task_id integer, p_user_name character varying); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_taskresult_by_task_and_user(p_task_id integer, p_user_name character varying) TO admin;


--
-- Name: FUNCTION get_tasks_by_inventory(p_inventory_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_tasks_by_inventory(p_inventory_id integer) TO admin;


--
-- Name: FUNCTION get_textcontent_by_inventory(p_inventory_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_textcontent_by_inventory(p_inventory_id integer) TO admin;


--
-- Name: FUNCTION get_time_by_id(p_time_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.get_time_by_id(p_time_id integer) TO admin;


--
-- Name: FUNCTION set_answer(p_username character varying, p_answer_id integer, p_task_id integer, p_answertext text, p_file_id integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.set_answer(p_username character varying, p_answer_id integer, p_task_id integer, p_answertext text, p_file_id integer) TO admin;


--
-- Name: FUNCTION upload_file(p_file_name character varying, p_path character varying, p_extension character varying, p_size integer); Type: ACL; Schema: base; Owner: postgres
--

GRANT ALL ON FUNCTION base.upload_file(p_file_name character varying, p_path character varying, p_extension character varying, p_size integer) TO admin;


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
-- Name: TABLE courstest; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.courstest TO admin;


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
-- Name: TABLE inventorytext; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.inventorytext TO admin;


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
-- Name: TABLE test; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.test TO admin;


--
-- Name: TABLE testresult; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.testresult TO admin;


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
-- Name: TABLE usertestanswer; Type: ACL; Schema: base; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE base.usertestanswer TO admin;


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

