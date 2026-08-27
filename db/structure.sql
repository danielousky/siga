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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: academic_periods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.academic_periods (
    id bigint NOT NULL,
    school_id bigint NOT NULL,
    name character varying NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.academic_periods FORCE ROW LEVEL SECURITY;


--
-- Name: academic_periods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.academic_periods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: academic_periods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.academic_periods_id_seq OWNED BY public.academic_periods.id;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: activity_grades; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_grades (
    id bigint NOT NULL,
    evaluation_activity_id bigint NOT NULL,
    score numeric(4,2) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL,
    student_id bigint NOT NULL,
    CONSTRAINT activity_grades_score_escala_1_20 CHECK (((score IS NULL) OR ((score >= (1)::numeric) AND (score <= (20)::numeric))))
);

ALTER TABLE ONLY public.activity_grades FORCE ROW LEVEL SECURITY;


--
-- Name: activity_grades_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.activity_grades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activity_grades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.activity_grades_id_seq OWNED BY public.activity_grades.id;


--
-- Name: activity_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_logs (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    action character varying NOT NULL,
    message character varying NOT NULL,
    subject_type character varying,
    subject_id bigint,
    metadata jsonb DEFAULT '{}'::jsonb,
    ip_address character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint
);

ALTER TABLE ONLY public.activity_logs FORCE ROW LEVEL SECURITY;


--
-- Name: activity_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.activity_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activity_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.activity_logs_id_seq OWNED BY public.activity_logs.id;


--
-- Name: addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.addresses (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    estado character varying NOT NULL,
    municipio character varying NOT NULL,
    parroquia character varying NOT NULL,
    location character varying NOT NULL,
    additional character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.addresses_id_seq OWNED BY public.addresses.id;


--
-- Name: admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admins (
    user_id bigint NOT NULL,
    school_id bigint NOT NULL,
    role integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    id bigint NOT NULL
);

ALTER TABLE ONLY public.admins FORCE ROW LEVEL SECURITY;


--
-- Name: admins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admins_id_seq OWNED BY public.admins.id;


--
-- Name: admins_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admins_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admins_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admins_user_id_seq OWNED BY public.admins.user_id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: attendances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendances (
    id bigint NOT NULL,
    school_id bigint NOT NULL,
    enrollment_id bigint NOT NULL,
    recorded_by_id bigint,
    date date NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    justificacion text,
    justificada_en timestamp(6) without time zone,
    justificada_por_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT attendances_status_valido CHECK ((status = ANY (ARRAY[0, 1, 2])))
);

ALTER TABLE ONLY public.attendances FORCE ROW LEVEL SECURITY;


--
-- Name: attendances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attendances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attendances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attendances_id_seq OWNED BY public.attendances.id;


--
-- Name: demo_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.demo_requests (
    id bigint NOT NULL,
    name character varying NOT NULL,
    email character varying,
    institution character varying NOT NULL,
    phone character varying,
    message text,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    current_system integer,
    current_system_detail character varying,
    veces integer DEFAULT 1 NOT NULL,
    telefono_normalizado character varying(10)
);


--
-- Name: demo_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.demo_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: demo_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.demo_requests_id_seq OWNED BY public.demo_requests.id;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departments (
    id bigint NOT NULL,
    school_id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.departments FORCE ROW LEVEL SECURITY;


--
-- Name: departments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.departments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.departments_id_seq OWNED BY public.departments.id;


--
-- Name: enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enrollments (
    id bigint NOT NULL,
    section_id bigint NOT NULL,
    enrollment_date date NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL,
    student_id bigint NOT NULL
);

ALTER TABLE ONLY public.enrollments FORCE ROW LEVEL SECURITY;


--
-- Name: enrollments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enrollments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enrollments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enrollments_id_seq OWNED BY public.enrollments.id;


--
-- Name: evaluation_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evaluation_activities (
    id bigint NOT NULL,
    subject_id bigint NOT NULL,
    section_id bigint NOT NULL,
    evaluation_moment_id bigint NOT NULL,
    description character varying NOT NULL,
    weight_percentage numeric(5,2) NOT NULL,
    date_scheduled date NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL
);

ALTER TABLE ONLY public.evaluation_activities FORCE ROW LEVEL SECURITY;


--
-- Name: evaluation_activities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.evaluation_activities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: evaluation_activities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.evaluation_activities_id_seq OWNED BY public.evaluation_activities.id;


--
-- Name: evaluation_moments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evaluation_moments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    weight numeric(5,2) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    academic_period_id bigint NOT NULL,
    school_id bigint NOT NULL,
    starts_on date,
    ends_on date
);

ALTER TABLE ONLY public.evaluation_moments FORCE ROW LEVEL SECURITY;


--
-- Name: evaluation_moments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.evaluation_moments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: evaluation_moments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.evaluation_moments_id_seq OWNED BY public.evaluation_moments.id;


--
-- Name: final_grade_books; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.final_grade_books (
    id bigint NOT NULL,
    enrollment_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    annual_average numeric(4,2),
    remedial_exam_score numeric(4,2),
    final_score numeric(4,2),
    comments text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL,
    origen integer DEFAULT 0 NOT NULL,
    CONSTRAINT final_grade_books_annual_average_escala_1_20 CHECK (((annual_average IS NULL) OR ((annual_average >= (1)::numeric) AND (annual_average <= (20)::numeric)))),
    CONSTRAINT final_grade_books_final_score_escala_1_20 CHECK (((final_score IS NULL) OR ((final_score >= (1)::numeric) AND (final_score <= (20)::numeric)))),
    CONSTRAINT final_grade_books_remedial_exam_score_escala_1_20 CHECK (((remedial_exam_score IS NULL) OR ((remedial_exam_score >= (1)::numeric) AND (remedial_exam_score <= (20)::numeric))))
);

ALTER TABLE ONLY public.final_grade_books FORCE ROW LEVEL SECURITY;


--
-- Name: final_grade_books_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.final_grade_books_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: final_grade_books_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.final_grade_books_id_seq OWNED BY public.final_grade_books.id;


--
-- Name: grade_subjects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grade_subjects (
    id bigint NOT NULL,
    grade_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL
);

ALTER TABLE ONLY public.grade_subjects FORCE ROW LEVEL SECURITY;


--
-- Name: grade_subjects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.grade_subjects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grade_subjects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.grade_subjects_id_seq OWNED BY public.grade_subjects.id;


--
-- Name: grades; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grades (
    id bigint NOT NULL,
    name character varying NOT NULL,
    level integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL,
    escala integer DEFAULT 0 NOT NULL,
    coordinator_teacher_id bigint,
    orden integer,
    CONSTRAINT grades_escala_valida CHECK ((escala = ANY (ARRAY[0, 1])))
);

ALTER TABLE ONLY public.grades FORCE ROW LEVEL SECURITY;


--
-- Name: grades_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.grades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.grades_id_seq OWNED BY public.grades.id;


--
-- Name: importaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.importaciones (
    id bigint NOT NULL,
    school_id bigint NOT NULL,
    subido_por_id bigint NOT NULL,
    estado integer DEFAULT 0 NOT NULL,
    mapeo jsonb DEFAULT '{}'::jsonb NOT NULL,
    resultado jsonb DEFAULT '{}'::jsonb NOT NULL,
    nombre_del_archivo character varying,
    filas_leidas integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    academic_period_id bigint,
    tipo integer DEFAULT 0 NOT NULL,
    CONSTRAINT importaciones_estado_valido CHECK ((estado = ANY (ARRAY[0, 1, 2, 3]))),
    CONSTRAINT importaciones_tipo_valido CHECK ((tipo = ANY (ARRAY[0, 1, 2])))
);

ALTER TABLE ONLY public.importaciones FORCE ROW LEVEL SECURITY;


--
-- Name: importaciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.importaciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: importaciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.importaciones_id_seq OWNED BY public.importaciones.id;


--
-- Name: moment_grades; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.moment_grades (
    id bigint NOT NULL,
    enrollment_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    evaluation_moment_id bigint NOT NULL,
    final_moment_score numeric(4,2) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL,
    origen integer DEFAULT 0 NOT NULL,
    CONSTRAINT moment_grades_final_moment_score_escala_1_20 CHECK (((final_moment_score IS NULL) OR ((final_moment_score >= (1)::numeric) AND (final_moment_score <= (20)::numeric))))
);

ALTER TABLE ONLY public.moment_grades FORCE ROW LEVEL SECURITY;


--
-- Name: moment_grades_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.moment_grades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: moment_grades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.moment_grades_id_seq OWNED BY public.moment_grades.id;


--
-- Name: report_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_cards (
    id bigint NOT NULL,
    school_id bigint NOT NULL,
    enrollment_id bigint NOT NULL,
    evaluation_moment_id bigint,
    code character varying NOT NULL,
    snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    issued_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.report_cards FORCE ROW LEVEL SECURITY;


--
-- Name: report_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.report_cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: report_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.report_cards_id_seq OWNED BY public.report_cards.id;


--
-- Name: representatives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.representatives (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    school_id bigint NOT NULL,
    phone character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.representatives FORCE ROW LEVEL SECURITY;


--
-- Name: representatives_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.representatives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: representatives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.representatives_id_seq OWNED BY public.representatives.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: schools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schools (
    id bigint NOT NULL,
    dea_code character varying NOT NULL,
    name character varying NOT NULL,
    location character varying NOT NULL,
    school_type integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    entidad_federal character varying,
    municipio character varying,
    direccion character varying,
    telefono character varying,
    cdcee character varying,
    parroquia character varying,
    pasos_omitidos jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: schools_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.schools_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: schools_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.schools_id_seq OWNED BY public.schools.id;


--
-- Name: sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sections (
    id bigint NOT NULL,
    grade_id bigint NOT NULL,
    academic_period_id bigint NOT NULL,
    capacity integer NOT NULL,
    name character varying NOT NULL,
    classroom character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL,
    leader_teacher_id bigint
);

ALTER TABLE ONLY public.sections FORCE ROW LEVEL SECURITY;


--
-- Name: sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sections_id_seq OWNED BY public.sections.id;


--
-- Name: siga_staffs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.siga_staffs (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT siga_staffs_role_valido CHECK ((role = ANY (ARRAY[0, 1])))
);


--
-- Name: siga_staffs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.siga_staffs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: siga_staffs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.siga_staffs_id_seq OWNED BY public.siga_staffs.id;


--
-- Name: solid_queue_blocked_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_blocked_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    concurrency_key character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_blocked_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_blocked_executions_id_seq OWNED BY public.solid_queue_blocked_executions.id;


--
-- Name: solid_queue_claimed_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_claimed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    process_id bigint,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_claimed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_claimed_executions_id_seq OWNED BY public.solid_queue_claimed_executions.id;


--
-- Name: solid_queue_failed_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_failed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    error text,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_failed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_failed_executions_id_seq OWNED BY public.solid_queue_failed_executions.id;


--
-- Name: solid_queue_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_jobs (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    class_name character varying NOT NULL,
    arguments text,
    priority integer DEFAULT 0 NOT NULL,
    active_job_id character varying,
    scheduled_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    concurrency_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_jobs_id_seq OWNED BY public.solid_queue_jobs.id;


--
-- Name: solid_queue_pauses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_pauses (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_pauses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_pauses_id_seq OWNED BY public.solid_queue_pauses.id;


--
-- Name: solid_queue_processes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_processes (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    last_heartbeat_at timestamp(6) without time zone NOT NULL,
    supervisor_id bigint,
    pid integer NOT NULL,
    hostname character varying,
    metadata text,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL
);


--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_processes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_processes_id_seq OWNED BY public.solid_queue_processes.id;


--
-- Name: solid_queue_ready_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_ready_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_ready_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_ready_executions_id_seq OWNED BY public.solid_queue_ready_executions.id;


--
-- Name: solid_queue_recurring_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_recurring_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    task_key character varying NOT NULL,
    run_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_recurring_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_recurring_executions_id_seq OWNED BY public.solid_queue_recurring_executions.id;


--
-- Name: solid_queue_recurring_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_recurring_tasks (
    id bigint NOT NULL,
    key character varying NOT NULL,
    schedule character varying NOT NULL,
    command character varying(2048),
    class_name character varying,
    arguments text,
    queue_name character varying,
    priority integer DEFAULT 0,
    static boolean DEFAULT true NOT NULL,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_recurring_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_recurring_tasks_id_seq OWNED BY public.solid_queue_recurring_tasks.id;


--
-- Name: solid_queue_scheduled_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_scheduled_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    scheduled_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_scheduled_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_scheduled_executions_id_seq OWNED BY public.solid_queue_scheduled_executions.id;


--
-- Name: solid_queue_semaphores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_semaphores (
    id bigint NOT NULL,
    key character varying NOT NULL,
    value integer DEFAULT 1 NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_semaphores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_semaphores_id_seq OWNED BY public.solid_queue_semaphores.id;


--
-- Name: student_representatives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_representatives (
    id bigint NOT NULL,
    representative_id bigint NOT NULL,
    school_id bigint NOT NULL,
    parentesco integer DEFAULT 0 NOT NULL,
    principal boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    student_id bigint NOT NULL,
    CONSTRAINT student_representatives_parentesco_valido CHECK ((parentesco = ANY (ARRAY[0, 1, 2, 3])))
);

ALTER TABLE ONLY public.student_representatives FORCE ROW LEVEL SECURITY;


--
-- Name: student_representatives_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.student_representatives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: student_representatives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.student_representatives_id_seq OWNED BY public.student_representatives.id;


--
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.students (
    user_id bigint NOT NULL,
    school_card character varying NOT NULL,
    school_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    id bigint NOT NULL
);

ALTER TABLE ONLY public.students FORCE ROW LEVEL SECURITY;


--
-- Name: students_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.students_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: students_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.students_id_seq OWNED BY public.students.id;


--
-- Name: students_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.students_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: students_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.students_user_id_seq OWNED BY public.students.user_id;


--
-- Name: subjects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subjects (
    id bigint NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    department_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL,
    escala integer
);

ALTER TABLE ONLY public.subjects FORCE ROW LEVEL SECURITY;


--
-- Name: subjects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subjects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subjects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subjects_id_seq OWNED BY public.subjects.id;


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id bigint NOT NULL,
    school_id bigint NOT NULL,
    plan integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    matricula_facturada integer,
    precio_mensual integer,
    vigente_desde date,
    vigente_hasta date,
    dias_de_gracia integer DEFAULT 15 NOT NULL,
    notas text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT subscriptions_plan_valido CHECK ((plan = ANY (ARRAY[0, 1, 2, 3, 4]))),
    CONSTRAINT subscriptions_status_valido CHECK ((status = ANY (ARRAY[0, 1, 2, 3])))
);

ALTER TABLE ONLY public.subscriptions FORCE ROW LEVEL SECURITY;


--
-- Name: subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subscriptions_id_seq OWNED BY public.subscriptions.id;


--
-- Name: teacher_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teacher_sections (
    id bigint NOT NULL,
    section_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL,
    teacher_id bigint NOT NULL
);

ALTER TABLE ONLY public.teacher_sections FORCE ROW LEVEL SECURITY;


--
-- Name: teacher_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.teacher_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: teacher_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.teacher_sections_id_seq OWNED BY public.teacher_sections.id;


--
-- Name: teachers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teachers (
    user_id bigint NOT NULL,
    school_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    id bigint NOT NULL
);

ALTER TABLE ONLY public.teachers FORCE ROW LEVEL SECURITY;


--
-- Name: teachers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.teachers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: teachers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.teachers_id_seq OWNED BY public.teachers.id;


--
-- Name: teachers_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.teachers_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: teachers_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.teachers_user_id_seq OWNED BY public.teachers.user_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying,
    encrypted_password character varying,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    document character varying,
    first_name character varying,
    last_name character varying,
    document_type integer,
    cedula_escolar character varying,
    second_last_name character varying,
    birth_date date,
    sex integer,
    birth_place character varying,
    birth_country character varying,
    birth_state character varying,
    birth_municipality character varying
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: academic_periods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_periods ALTER COLUMN id SET DEFAULT nextval('public.academic_periods_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: activity_grades id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_grades ALTER COLUMN id SET DEFAULT nextval('public.activity_grades_id_seq'::regclass);


--
-- Name: activity_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs ALTER COLUMN id SET DEFAULT nextval('public.activity_logs_id_seq'::regclass);


--
-- Name: addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses ALTER COLUMN id SET DEFAULT nextval('public.addresses_id_seq'::regclass);


--
-- Name: admins user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins ALTER COLUMN user_id SET DEFAULT nextval('public.admins_user_id_seq'::regclass);


--
-- Name: admins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins ALTER COLUMN id SET DEFAULT nextval('public.admins_id_seq'::regclass);


--
-- Name: attendances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendances ALTER COLUMN id SET DEFAULT nextval('public.attendances_id_seq'::regclass);


--
-- Name: demo_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demo_requests ALTER COLUMN id SET DEFAULT nextval('public.demo_requests_id_seq'::regclass);


--
-- Name: departments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments ALTER COLUMN id SET DEFAULT nextval('public.departments_id_seq'::regclass);


--
-- Name: enrollments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments ALTER COLUMN id SET DEFAULT nextval('public.enrollments_id_seq'::regclass);


--
-- Name: evaluation_activities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_activities ALTER COLUMN id SET DEFAULT nextval('public.evaluation_activities_id_seq'::regclass);


--
-- Name: evaluation_moments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_moments ALTER COLUMN id SET DEFAULT nextval('public.evaluation_moments_id_seq'::regclass);


--
-- Name: final_grade_books id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.final_grade_books ALTER COLUMN id SET DEFAULT nextval('public.final_grade_books_id_seq'::regclass);


--
-- Name: grade_subjects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_subjects ALTER COLUMN id SET DEFAULT nextval('public.grade_subjects_id_seq'::regclass);


--
-- Name: grades id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades ALTER COLUMN id SET DEFAULT nextval('public.grades_id_seq'::regclass);


--
-- Name: importaciones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.importaciones ALTER COLUMN id SET DEFAULT nextval('public.importaciones_id_seq'::regclass);


--
-- Name: moment_grades id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moment_grades ALTER COLUMN id SET DEFAULT nextval('public.moment_grades_id_seq'::regclass);


--
-- Name: report_cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards ALTER COLUMN id SET DEFAULT nextval('public.report_cards_id_seq'::regclass);


--
-- Name: representatives id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.representatives ALTER COLUMN id SET DEFAULT nextval('public.representatives_id_seq'::regclass);


--
-- Name: schools id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools ALTER COLUMN id SET DEFAULT nextval('public.schools_id_seq'::regclass);


--
-- Name: sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections ALTER COLUMN id SET DEFAULT nextval('public.sections_id_seq'::regclass);


--
-- Name: siga_staffs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.siga_staffs ALTER COLUMN id SET DEFAULT nextval('public.siga_staffs_id_seq'::regclass);


--
-- Name: solid_queue_blocked_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_blocked_executions_id_seq'::regclass);


--
-- Name: solid_queue_claimed_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_claimed_executions_id_seq'::regclass);


--
-- Name: solid_queue_failed_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_failed_executions_id_seq'::regclass);


--
-- Name: solid_queue_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_jobs ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_jobs_id_seq'::regclass);


--
-- Name: solid_queue_pauses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_pauses ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_pauses_id_seq'::regclass);


--
-- Name: solid_queue_processes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_processes ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_processes_id_seq'::regclass);


--
-- Name: solid_queue_ready_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_ready_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_tasks_id_seq'::regclass);


--
-- Name: solid_queue_scheduled_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_scheduled_executions_id_seq'::regclass);


--
-- Name: solid_queue_semaphores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_semaphores ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_semaphores_id_seq'::regclass);


--
-- Name: student_representatives id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_representatives ALTER COLUMN id SET DEFAULT nextval('public.student_representatives_id_seq'::regclass);


--
-- Name: students user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students ALTER COLUMN user_id SET DEFAULT nextval('public.students_user_id_seq'::regclass);


--
-- Name: students id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students ALTER COLUMN id SET DEFAULT nextval('public.students_id_seq'::regclass);


--
-- Name: subjects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects ALTER COLUMN id SET DEFAULT nextval('public.subjects_id_seq'::regclass);


--
-- Name: subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions ALTER COLUMN id SET DEFAULT nextval('public.subscriptions_id_seq'::regclass);


--
-- Name: teacher_sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teacher_sections ALTER COLUMN id SET DEFAULT nextval('public.teacher_sections_id_seq'::regclass);


--
-- Name: teachers user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers ALTER COLUMN user_id SET DEFAULT nextval('public.teachers_user_id_seq'::regclass);


--
-- Name: teachers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers ALTER COLUMN id SET DEFAULT nextval('public.teachers_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: academic_periods academic_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_periods
    ADD CONSTRAINT academic_periods_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: activity_grades activity_grades_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_grades
    ADD CONSTRAINT activity_grades_pkey PRIMARY KEY (id);


--
-- Name: activity_logs activity_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs
    ADD CONSTRAINT activity_logs_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: attendances attendances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendances
    ADD CONSTRAINT attendances_pkey PRIMARY KEY (id);


--
-- Name: demo_requests demo_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demo_requests
    ADD CONSTRAINT demo_requests_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: enrollments enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT enrollments_pkey PRIMARY KEY (id);


--
-- Name: evaluation_activities evaluation_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_activities
    ADD CONSTRAINT evaluation_activities_pkey PRIMARY KEY (id);


--
-- Name: evaluation_moments evaluation_moments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_moments
    ADD CONSTRAINT evaluation_moments_pkey PRIMARY KEY (id);


--
-- Name: final_grade_books final_grade_books_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.final_grade_books
    ADD CONSTRAINT final_grade_books_pkey PRIMARY KEY (id);


--
-- Name: grade_subjects grade_subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_subjects
    ADD CONSTRAINT grade_subjects_pkey PRIMARY KEY (id);


--
-- Name: grades grades_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades
    ADD CONSTRAINT grades_pkey PRIMARY KEY (id);


--
-- Name: importaciones importaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.importaciones
    ADD CONSTRAINT importaciones_pkey PRIMARY KEY (id);


--
-- Name: moment_grades moment_grades_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moment_grades
    ADD CONSTRAINT moment_grades_pkey PRIMARY KEY (id);


--
-- Name: report_cards report_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards
    ADD CONSTRAINT report_cards_pkey PRIMARY KEY (id);


--
-- Name: representatives representatives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.representatives
    ADD CONSTRAINT representatives_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: schools schools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools
    ADD CONSTRAINT schools_pkey PRIMARY KEY (id);


--
-- Name: sections sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT sections_pkey PRIMARY KEY (id);


--
-- Name: siga_staffs siga_staffs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.siga_staffs
    ADD CONSTRAINT siga_staffs_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_blocked_executions solid_queue_blocked_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT solid_queue_blocked_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_claimed_executions solid_queue_claimed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT solid_queue_claimed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_failed_executions solid_queue_failed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT solid_queue_failed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_jobs solid_queue_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_jobs
    ADD CONSTRAINT solid_queue_jobs_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_pauses solid_queue_pauses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_pauses
    ADD CONSTRAINT solid_queue_pauses_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_processes solid_queue_processes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_processes
    ADD CONSTRAINT solid_queue_processes_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_ready_executions solid_queue_ready_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT solid_queue_ready_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_executions solid_queue_recurring_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT solid_queue_recurring_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_tasks solid_queue_recurring_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks
    ADD CONSTRAINT solid_queue_recurring_tasks_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_scheduled_executions solid_queue_scheduled_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT solid_queue_scheduled_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_semaphores solid_queue_semaphores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_semaphores
    ADD CONSTRAINT solid_queue_semaphores_pkey PRIMARY KEY (id);


--
-- Name: student_representatives student_representatives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_representatives
    ADD CONSTRAINT student_representatives_pkey PRIMARY KEY (id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- Name: subjects subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: teacher_sections teacher_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teacher_sections
    ADD CONSTRAINT teacher_sections_pkey PRIMARY KEY (id);


--
-- Name: teachers teachers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_academic_periods_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_academic_periods_on_school_id ON public.academic_periods USING btree (school_id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_activity_grades_on_activity_and_student; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_activity_grades_on_activity_and_student ON public.activity_grades USING btree (evaluation_activity_id, student_id);


--
-- Name: index_activity_grades_on_evaluation_activity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_grades_on_evaluation_activity_id ON public.activity_grades USING btree (evaluation_activity_id);


--
-- Name: index_activity_grades_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_grades_on_school_id ON public.activity_grades USING btree (school_id);


--
-- Name: index_activity_logs_on_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_logs_on_action ON public.activity_logs USING btree (action);


--
-- Name: index_activity_logs_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_logs_on_created_at ON public.activity_logs USING btree (created_at);


--
-- Name: index_activity_logs_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_logs_on_school_id ON public.activity_logs USING btree (school_id);


--
-- Name: index_activity_logs_on_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_logs_on_subject ON public.activity_logs USING btree (subject_type, subject_id);


--
-- Name: index_activity_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_logs_on_user_id ON public.activity_logs USING btree (user_id);


--
-- Name: index_addresses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_addresses_on_user_id ON public.addresses USING btree (user_id);


--
-- Name: index_admins_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_admins_on_school_id ON public.admins USING btree (school_id);


--
-- Name: index_admins_on_user_id_and_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_admins_on_user_id_and_school_id ON public.admins USING btree (user_id, school_id);


--
-- Name: index_attendances_on_enrollment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_attendances_on_enrollment_id ON public.attendances USING btree (enrollment_id);


--
-- Name: index_attendances_on_enrollment_id_and_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_attendances_on_enrollment_id_and_date ON public.attendances USING btree (enrollment_id, date);


--
-- Name: index_attendances_on_justificada_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_attendances_on_justificada_por_id ON public.attendances USING btree (justificada_por_id);


--
-- Name: index_attendances_on_recorded_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_attendances_on_recorded_by_id ON public.attendances USING btree (recorded_by_id);


--
-- Name: index_attendances_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_attendances_on_school_id ON public.attendances USING btree (school_id);


--
-- Name: index_attendances_on_school_id_and_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_attendances_on_school_id_and_date ON public.attendances USING btree (school_id, date);


--
-- Name: index_demo_requests_on_current_system; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_demo_requests_on_current_system ON public.demo_requests USING btree (current_system);


--
-- Name: index_demo_requests_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_demo_requests_on_email ON public.demo_requests USING btree (email);


--
-- Name: index_demo_requests_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_demo_requests_on_status ON public.demo_requests USING btree (status);


--
-- Name: index_demo_requests_on_telefono_normalizado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_demo_requests_on_telefono_normalizado ON public.demo_requests USING btree (telefono_normalizado);


--
-- Name: index_departments_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departments_on_school_id ON public.departments USING btree (school_id);


--
-- Name: index_departments_on_school_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departments_on_school_id_and_name ON public.departments USING btree (school_id, name);


--
-- Name: index_enrollments_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enrollments_on_school_id ON public.enrollments USING btree (school_id);


--
-- Name: index_enrollments_on_section_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enrollments_on_section_id ON public.enrollments USING btree (section_id);


--
-- Name: index_enrollments_on_section_id_and_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_enrollments_on_section_id_and_student_id ON public.enrollments USING btree (section_id, student_id);


--
-- Name: index_evaluation_activities_on_evaluation_moment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evaluation_activities_on_evaluation_moment_id ON public.evaluation_activities USING btree (evaluation_moment_id);


--
-- Name: index_evaluation_activities_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evaluation_activities_on_school_id ON public.evaluation_activities USING btree (school_id);


--
-- Name: index_evaluation_activities_on_section_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evaluation_activities_on_section_id ON public.evaluation_activities USING btree (section_id);


--
-- Name: index_evaluation_activities_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evaluation_activities_on_subject_id ON public.evaluation_activities USING btree (subject_id);


--
-- Name: index_evaluation_moments_on_academic_period_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evaluation_moments_on_academic_period_id ON public.evaluation_moments USING btree (academic_period_id);


--
-- Name: index_evaluation_moments_on_academic_period_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_evaluation_moments_on_academic_period_id_and_name ON public.evaluation_moments USING btree (academic_period_id, name);


--
-- Name: index_evaluation_moments_on_academic_period_id_and_starts_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evaluation_moments_on_academic_period_id_and_starts_on ON public.evaluation_moments USING btree (academic_period_id, starts_on);


--
-- Name: index_evaluation_moments_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evaluation_moments_on_school_id ON public.evaluation_moments USING btree (school_id);


--
-- Name: index_final_grade_books_on_enrollment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_final_grade_books_on_enrollment_id ON public.final_grade_books USING btree (enrollment_id);


--
-- Name: index_final_grade_books_on_enrollment_id_and_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_final_grade_books_on_enrollment_id_and_subject_id ON public.final_grade_books USING btree (enrollment_id, subject_id);


--
-- Name: index_final_grade_books_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_final_grade_books_on_school_id ON public.final_grade_books USING btree (school_id);


--
-- Name: index_final_grade_books_on_school_id_and_origen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_final_grade_books_on_school_id_and_origen ON public.final_grade_books USING btree (school_id, origen);


--
-- Name: index_final_grade_books_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_final_grade_books_on_subject_id ON public.final_grade_books USING btree (subject_id);


--
-- Name: index_grade_subjects_on_grade_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_grade_subjects_on_grade_id ON public.grade_subjects USING btree (grade_id);


--
-- Name: index_grade_subjects_on_grade_id_and_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_grade_subjects_on_grade_id_and_subject_id ON public.grade_subjects USING btree (grade_id, subject_id);


--
-- Name: index_grade_subjects_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_grade_subjects_on_school_id ON public.grade_subjects USING btree (school_id);


--
-- Name: index_grade_subjects_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_grade_subjects_on_subject_id ON public.grade_subjects USING btree (subject_id);


--
-- Name: index_grades_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_grades_on_school_id ON public.grades USING btree (school_id);


--
-- Name: index_grades_on_school_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_grades_on_school_id_and_name ON public.grades USING btree (school_id, name);


--
-- Name: index_grades_on_school_id_and_orden; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_grades_on_school_id_and_orden ON public.grades USING btree (school_id, orden);


--
-- Name: index_importaciones_on_academic_period_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_importaciones_on_academic_period_id ON public.importaciones USING btree (academic_period_id);


--
-- Name: index_importaciones_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_importaciones_on_school_id ON public.importaciones USING btree (school_id);


--
-- Name: index_importaciones_on_school_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_importaciones_on_school_id_and_created_at ON public.importaciones USING btree (school_id, created_at);


--
-- Name: index_importaciones_on_subido_por_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_importaciones_on_subido_por_id ON public.importaciones USING btree (subido_por_id);


--
-- Name: index_moment_grades_on_enrollment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moment_grades_on_enrollment_id ON public.moment_grades USING btree (enrollment_id);


--
-- Name: index_moment_grades_on_enrollment_subject_moment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_moment_grades_on_enrollment_subject_moment ON public.moment_grades USING btree (enrollment_id, subject_id, evaluation_moment_id);


--
-- Name: index_moment_grades_on_evaluation_moment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moment_grades_on_evaluation_moment_id ON public.moment_grades USING btree (evaluation_moment_id);


--
-- Name: index_moment_grades_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moment_grades_on_school_id ON public.moment_grades USING btree (school_id);


--
-- Name: index_moment_grades_on_school_id_and_origen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moment_grades_on_school_id_and_origen ON public.moment_grades USING btree (school_id, origen);


--
-- Name: index_moment_grades_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moment_grades_on_subject_id ON public.moment_grades USING btree (subject_id);


--
-- Name: index_report_cards_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_report_cards_on_code ON public.report_cards USING btree (code);


--
-- Name: index_report_cards_on_enrollment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_cards_on_enrollment_id ON public.report_cards USING btree (enrollment_id);


--
-- Name: index_report_cards_on_evaluation_moment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_cards_on_evaluation_moment_id ON public.report_cards USING btree (evaluation_moment_id);


--
-- Name: index_report_cards_on_issued_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_cards_on_issued_by_id ON public.report_cards USING btree (issued_by_id);


--
-- Name: index_report_cards_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_cards_on_school_id ON public.report_cards USING btree (school_id);


--
-- Name: index_representatives_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_representatives_on_school_id ON public.representatives USING btree (school_id);


--
-- Name: index_representatives_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_representatives_on_user_id ON public.representatives USING btree (user_id);


--
-- Name: index_representatives_on_user_id_and_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_representatives_on_user_id_and_school_id ON public.representatives USING btree (user_id, school_id);


--
-- Name: index_schools_on_dea_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_schools_on_dea_code ON public.schools USING btree (dea_code);


--
-- Name: index_sections_on_academic_period_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sections_on_academic_period_id ON public.sections USING btree (academic_period_id);


--
-- Name: index_sections_on_grade_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sections_on_grade_id ON public.sections USING btree (grade_id);


--
-- Name: index_sections_on_grade_period_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sections_on_grade_period_name ON public.sections USING btree (grade_id, academic_period_id, name);


--
-- Name: index_sections_on_leader_teacher_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sections_on_leader_teacher_id ON public.sections USING btree (leader_teacher_id);


--
-- Name: index_sections_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sections_on_school_id ON public.sections USING btree (school_id);


--
-- Name: index_siga_staffs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_siga_staffs_on_user_id ON public.siga_staffs USING btree (user_id);


--
-- Name: index_solid_queue_blocked_executions_for_maintenance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_blocked_executions_for_maintenance ON public.solid_queue_blocked_executions USING btree (expires_at, concurrency_key);


--
-- Name: index_solid_queue_blocked_executions_for_release; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_blocked_executions_for_release ON public.solid_queue_blocked_executions USING btree (concurrency_key, priority, job_id);


--
-- Name: index_solid_queue_blocked_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_blocked_executions_on_job_id ON public.solid_queue_blocked_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_claimed_executions_on_job_id ON public.solid_queue_claimed_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_process_id_and_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_claimed_executions_on_process_id_and_job_id ON public.solid_queue_claimed_executions USING btree (process_id, job_id);


--
-- Name: index_solid_queue_dispatch_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_dispatch_all ON public.solid_queue_scheduled_executions USING btree (scheduled_at, priority, job_id);


--
-- Name: index_solid_queue_failed_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_failed_executions_on_job_id ON public.solid_queue_failed_executions USING btree (job_id);


--
-- Name: index_solid_queue_jobs_for_alerting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_for_alerting ON public.solid_queue_jobs USING btree (scheduled_at, finished_at);


--
-- Name: index_solid_queue_jobs_for_filtering; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_for_filtering ON public.solid_queue_jobs USING btree (queue_name, finished_at);


--
-- Name: index_solid_queue_jobs_on_active_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_active_job_id ON public.solid_queue_jobs USING btree (active_job_id);


--
-- Name: index_solid_queue_jobs_on_class_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_class_name ON public.solid_queue_jobs USING btree (class_name);


--
-- Name: index_solid_queue_jobs_on_finished_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_finished_at ON public.solid_queue_jobs USING btree (finished_at);


--
-- Name: index_solid_queue_pauses_on_queue_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_pauses_on_queue_name ON public.solid_queue_pauses USING btree (queue_name);


--
-- Name: index_solid_queue_poll_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_poll_all ON public.solid_queue_ready_executions USING btree (priority, job_id);


--
-- Name: index_solid_queue_poll_by_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_poll_by_queue ON public.solid_queue_ready_executions USING btree (queue_name, priority, job_id);


--
-- Name: index_solid_queue_processes_on_last_heartbeat_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_processes_on_last_heartbeat_at ON public.solid_queue_processes USING btree (last_heartbeat_at);


--
-- Name: index_solid_queue_processes_on_name_and_supervisor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_processes_on_name_and_supervisor_id ON public.solid_queue_processes USING btree (name, supervisor_id);


--
-- Name: index_solid_queue_processes_on_supervisor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_processes_on_supervisor_id ON public.solid_queue_processes USING btree (supervisor_id);


--
-- Name: index_solid_queue_ready_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_ready_executions_on_job_id ON public.solid_queue_ready_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_job_id ON public.solid_queue_recurring_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_task_key_and_run_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_task_key_and_run_at ON public.solid_queue_recurring_executions USING btree (task_key, run_at);


--
-- Name: index_solid_queue_recurring_tasks_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_tasks_on_key ON public.solid_queue_recurring_tasks USING btree (key);


--
-- Name: index_solid_queue_recurring_tasks_on_static; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_recurring_tasks_on_static ON public.solid_queue_recurring_tasks USING btree (static);


--
-- Name: index_solid_queue_scheduled_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_scheduled_executions_on_job_id ON public.solid_queue_scheduled_executions USING btree (job_id);


--
-- Name: index_solid_queue_semaphores_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_semaphores_on_expires_at ON public.solid_queue_semaphores USING btree (expires_at);


--
-- Name: index_solid_queue_semaphores_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_semaphores_on_key ON public.solid_queue_semaphores USING btree (key);


--
-- Name: index_solid_queue_semaphores_on_key_and_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_semaphores_on_key_and_value ON public.solid_queue_semaphores USING btree (key, value);


--
-- Name: index_student_representatives_on_representative_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_student_representatives_on_representative_id ON public.student_representatives USING btree (representative_id);


--
-- Name: index_student_representatives_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_student_representatives_on_school_id ON public.student_representatives USING btree (school_id);


--
-- Name: index_student_representatives_unicos; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_student_representatives_unicos ON public.student_representatives USING btree (representative_id, student_id);


--
-- Name: index_students_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_students_on_school_id ON public.students USING btree (school_id);


--
-- Name: index_students_on_school_id_and_school_card; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_students_on_school_id_and_school_card ON public.students USING btree (school_id, school_card);


--
-- Name: index_students_on_user_id_and_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_students_on_user_id_and_school_id ON public.students USING btree (user_id, school_id);


--
-- Name: index_subjects_on_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subjects_on_department_id ON public.subjects USING btree (department_id);


--
-- Name: index_subjects_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subjects_on_school_id ON public.subjects USING btree (school_id);


--
-- Name: index_subjects_on_school_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subjects_on_school_id_and_code ON public.subjects USING btree (school_id, code);


--
-- Name: index_subscriptions_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subscriptions_on_school_id ON public.subscriptions USING btree (school_id);


--
-- Name: index_subscriptions_on_status_and_vigente_hasta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_status_and_vigente_hasta ON public.subscriptions USING btree (status, vigente_hasta);


--
-- Name: index_teacher_sections_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teacher_sections_on_school_id ON public.teacher_sections USING btree (school_id);


--
-- Name: index_teacher_sections_on_section_and_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_teacher_sections_on_section_and_subject ON public.teacher_sections USING btree (section_id, subject_id);


--
-- Name: index_teacher_sections_on_section_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teacher_sections_on_section_id ON public.teacher_sections USING btree (section_id);


--
-- Name: index_teacher_sections_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teacher_sections_on_subject_id ON public.teacher_sections USING btree (subject_id);


--
-- Name: index_teachers_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teachers_on_school_id ON public.teachers USING btree (school_id);


--
-- Name: index_teachers_on_user_id_and_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_teachers_on_user_id_and_school_id ON public.teachers USING btree (user_id, school_id);


--
-- Name: index_users_on_cedula_escolar; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_cedula_escolar ON public.users USING btree (cedula_escolar);


--
-- Name: index_users_on_document; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_document ON public.users USING btree (document);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email) WHERE (email IS NOT NULL);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: student_representatives fk_rails_08e2b9969f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_representatives
    ADD CONSTRAINT fk_rails_08e2b9969f FOREIGN KEY (student_id) REFERENCES public.students(id);


--
-- Name: students fk_rails_0adebddbd5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT fk_rails_0adebddbd5 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: final_grade_books fk_rails_0ae0be115a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.final_grade_books
    ADD CONSTRAINT fk_rails_0ae0be115a FOREIGN KEY (enrollment_id) REFERENCES public.enrollments(id);


--
-- Name: sections fk_rails_115ba89703; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT fk_rails_115ba89703 FOREIGN KEY (leader_teacher_id) REFERENCES public.teachers(id);


--
-- Name: students fk_rails_148c9e88f4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT fk_rails_148c9e88f4 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: representatives fk_rails_14baa23d4e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.representatives
    ADD CONSTRAINT fk_rails_14baa23d4e FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: student_representatives fk_rails_244edf660a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_representatives
    ADD CONSTRAINT fk_rails_244edf660a FOREIGN KEY (representative_id) REFERENCES public.representatives(id);


--
-- Name: report_cards fk_rails_2c9a394005; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards
    ADD CONSTRAINT fk_rails_2c9a394005 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: moment_grades fk_rails_2d57e5a5e4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moment_grades
    ADD CONSTRAINT fk_rails_2d57e5a5e4 FOREIGN KEY (evaluation_moment_id) REFERENCES public.evaluation_moments(id);


--
-- Name: solid_queue_recurring_executions fk_rails_318a5533ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT fk_rails_318a5533ed FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: admins fk_rails_347d90608b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT fk_rails_347d90608b FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: evaluation_moments fk_rails_35b3c9df71; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_moments
    ADD CONSTRAINT fk_rails_35b3c9df71 FOREIGN KEY (academic_period_id) REFERENCES public.academic_periods(id);


--
-- Name: admins fk_rails_378b9734e4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT fk_rails_378b9734e4 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: solid_queue_failed_executions fk_rails_39bbc7a631; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT fk_rails_39bbc7a631 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: grade_subjects fk_rails_3d59e815d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_subjects
    ADD CONSTRAINT fk_rails_3d59e815d2 FOREIGN KEY (grade_id) REFERENCES public.grades(id);


--
-- Name: activity_grades fk_rails_3e875748a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_grades
    ADD CONSTRAINT fk_rails_3e875748a2 FOREIGN KEY (evaluation_activity_id) REFERENCES public.evaluation_activities(id);


--
-- Name: grade_subjects fk_rails_456930f438; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_subjects
    ADD CONSTRAINT fk_rails_456930f438 FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: attendances fk_rails_4877a7c143; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendances
    ADD CONSTRAINT fk_rails_4877a7c143 FOREIGN KEY (enrollment_id) REFERENCES public.enrollments(id);


--
-- Name: addresses fk_rails_48c9e0c5a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT fk_rails_48c9e0c5a2 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: solid_queue_blocked_executions fk_rails_4cd34e2228; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT fk_rails_4cd34e2228 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: departments fk_rails_4ce931b154; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_rails_4ce931b154 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: subjects fk_rails_5434ae4d11; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT fk_rails_5434ae4d11 FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- Name: grades fk_rails_5441746b71; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades
    ADD CONSTRAINT fk_rails_5441746b71 FOREIGN KEY (coordinator_teacher_id) REFERENCES public.teachers(id);


--
-- Name: teachers fk_rails_579a190d8f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT fk_rails_579a190d8f FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: academic_periods fk_rails_5ad2b9b5bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_periods
    ADD CONSTRAINT fk_rails_5ad2b9b5bf FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: enrollments fk_rails_5cf88b78f2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT fk_rails_5cf88b78f2 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: importaciones fk_rails_5e5599990c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.importaciones
    ADD CONSTRAINT fk_rails_5e5599990c FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: sections fk_rails_61d9612b47; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT fk_rails_61d9612b47 FOREIGN KEY (grade_id) REFERENCES public.grades(id);


--
-- Name: activity_logs fk_rails_67d3da4464; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs
    ADD CONSTRAINT fk_rails_67d3da4464 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: report_cards fk_rails_6c37a9cb2c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards
    ADD CONSTRAINT fk_rails_6c37a9cb2c FOREIGN KEY (issued_by_id) REFERENCES public.users(id);


--
-- Name: enrollments fk_rails_6e4789b133; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT fk_rails_6e4789b133 FOREIGN KEY (section_id) REFERENCES public.sections(id);


--
-- Name: attendances fk_rails_728acf438a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendances
    ADD CONSTRAINT fk_rails_728acf438a FOREIGN KEY (recorded_by_id) REFERENCES public.users(id);


--
-- Name: importaciones fk_rails_74ec49d6ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.importaciones
    ADD CONSTRAINT fk_rails_74ec49d6ea FOREIGN KEY (subido_por_id) REFERENCES public.users(id);


--
-- Name: final_grade_books fk_rails_7517b472c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.final_grade_books
    ADD CONSTRAINT fk_rails_7517b472c0 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: evaluation_activities fk_rails_77d857f5b2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_activities
    ADD CONSTRAINT fk_rails_77d857f5b2 FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: subjects fk_rails_8103a56a88; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT fk_rails_8103a56a88 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: subscriptions fk_rails_81a71a1b70; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_81a71a1b70 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: solid_queue_ready_executions fk_rails_81fcbd66af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT fk_rails_81fcbd66af FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: sections fk_rails_833da4b940; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT fk_rails_833da4b940 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: grade_subjects fk_rails_863de54b91; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_subjects
    ADD CONSTRAINT fk_rails_863de54b91 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: siga_staffs fk_rails_9179172cf3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.siga_staffs
    ADD CONSTRAINT fk_rails_9179172cf3 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: activity_grades fk_rails_97effb690c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_grades
    ADD CONSTRAINT fk_rails_97effb690c FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: grades fk_rails_9803afc4f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades
    ADD CONSTRAINT fk_rails_9803afc4f6 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: representatives fk_rails_98bb8d7e02; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.representatives
    ADD CONSTRAINT fk_rails_98bb8d7e02 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: solid_queue_claimed_executions fk_rails_9cfe4d4944; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT fk_rails_9cfe4d4944 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: activity_grades fk_rails_9e041c690a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_grades
    ADD CONSTRAINT fk_rails_9e041c690a FOREIGN KEY (student_id) REFERENCES public.students(id);


--
-- Name: teacher_sections fk_rails_a4fe6be625; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teacher_sections
    ADD CONSTRAINT fk_rails_a4fe6be625 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: teachers fk_rails_a8c1458420; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT fk_rails_a8c1458420 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: attendances fk_rails_b1bda8f4f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendances
    ADD CONSTRAINT fk_rails_b1bda8f4f7 FOREIGN KEY (justificada_por_id) REFERENCES public.users(id);


--
-- Name: teacher_sections fk_rails_b2b858bbcc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teacher_sections
    ADD CONSTRAINT fk_rails_b2b858bbcc FOREIGN KEY (teacher_id) REFERENCES public.teachers(id);


--
-- Name: sections fk_rails_b68e820df3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT fk_rails_b68e820df3 FOREIGN KEY (academic_period_id) REFERENCES public.academic_periods(id);


--
-- Name: moment_grades fk_rails_b9000237d8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moment_grades
    ADD CONSTRAINT fk_rails_b9000237d8 FOREIGN KEY (enrollment_id) REFERENCES public.enrollments(id);


--
-- Name: report_cards fk_rails_c161237368; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards
    ADD CONSTRAINT fk_rails_c161237368 FOREIGN KEY (evaluation_moment_id) REFERENCES public.evaluation_moments(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: solid_queue_scheduled_executions fk_rails_c4316f352d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT fk_rails_c4316f352d FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: teacher_sections fk_rails_c4f969cf66; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teacher_sections
    ADD CONSTRAINT fk_rails_c4f969cf66 FOREIGN KEY (section_id) REFERENCES public.sections(id);


--
-- Name: activity_logs fk_rails_c9badf82db; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs
    ADD CONSTRAINT fk_rails_c9badf82db FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: report_cards fk_rails_ce32782863; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards
    ADD CONSTRAINT fk_rails_ce32782863 FOREIGN KEY (enrollment_id) REFERENCES public.enrollments(id);


--
-- Name: attendances fk_rails_d1a9c7df43; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendances
    ADD CONSTRAINT fk_rails_d1a9c7df43 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: importaciones fk_rails_d7eeace914; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.importaciones
    ADD CONSTRAINT fk_rails_d7eeace914 FOREIGN KEY (academic_period_id) REFERENCES public.academic_periods(id);


--
-- Name: evaluation_activities fk_rails_d7f6d58aee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_activities
    ADD CONSTRAINT fk_rails_d7f6d58aee FOREIGN KEY (section_id) REFERENCES public.sections(id);


--
-- Name: final_grade_books fk_rails_dbeb5931bb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.final_grade_books
    ADD CONSTRAINT fk_rails_dbeb5931bb FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: evaluation_moments fk_rails_dd1331b651; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_moments
    ADD CONSTRAINT fk_rails_dd1331b651 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: moment_grades fk_rails_e3ac358938; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moment_grades
    ADD CONSTRAINT fk_rails_e3ac358938 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: moment_grades fk_rails_ea6319b00e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moment_grades
    ADD CONSTRAINT fk_rails_ea6319b00e FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: evaluation_activities fk_rails_eea9a40e62; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_activities
    ADD CONSTRAINT fk_rails_eea9a40e62 FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: enrollments fk_rails_f01c555e06; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT fk_rails_f01c555e06 FOREIGN KEY (student_id) REFERENCES public.students(id);


--
-- Name: teacher_sections fk_rails_f438bac6b6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teacher_sections
    ADD CONSTRAINT fk_rails_f438bac6b6 FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: student_representatives fk_rails_f78ed5cecb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_representatives
    ADD CONSTRAINT fk_rails_f78ed5cecb FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: evaluation_activities fk_rails_f8b76eb396; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_activities
    ADD CONSTRAINT fk_rails_f8b76eb396 FOREIGN KEY (evaluation_moment_id) REFERENCES public.evaluation_moments(id);


--
-- Name: academic_periods; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.academic_periods ENABLE ROW LEVEL SECURITY;

--
-- Name: activity_grades; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_grades ENABLE ROW LEVEL SECURITY;

--
-- Name: activity_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: admins; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

--
-- Name: academic_periods aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.academic_periods USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: activity_grades aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.activity_grades USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: activity_logs aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.activity_logs USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: admins aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.admins USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: attendances aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.attendances USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: departments aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.departments USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: enrollments aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.enrollments USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: evaluation_activities aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.evaluation_activities USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: evaluation_moments aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.evaluation_moments USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: final_grade_books aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.final_grade_books USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: grade_subjects aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.grade_subjects USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: grades aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.grades USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: importaciones aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.importaciones USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: moment_grades aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.moment_grades USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: report_cards aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.report_cards USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: representatives aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.representatives USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: sections aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.sections USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: student_representatives aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.student_representatives USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: students aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.students USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: subjects aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.subjects USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: subscriptions aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.subscriptions USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: teacher_sections aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.teacher_sections USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: teachers aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.teachers USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: attendances; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attendances ENABLE ROW LEVEL SECURITY;

--
-- Name: departments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

--
-- Name: enrollments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;

--
-- Name: evaluation_activities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.evaluation_activities ENABLE ROW LEVEL SECURITY;

--
-- Name: evaluation_moments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.evaluation_moments ENABLE ROW LEVEL SECURITY;

--
-- Name: final_grade_books; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.final_grade_books ENABLE ROW LEVEL SECURITY;

--
-- Name: grade_subjects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.grade_subjects ENABLE ROW LEVEL SECURITY;

--
-- Name: grades; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;

--
-- Name: importaciones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.importaciones ENABLE ROW LEVEL SECURITY;

--
-- Name: moment_grades; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.moment_grades ENABLE ROW LEVEL SECURITY;

--
-- Name: report_cards; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.report_cards ENABLE ROW LEVEL SECURITY;

--
-- Name: representatives; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.representatives ENABLE ROW LEVEL SECURITY;

--
-- Name: sections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;

--
-- Name: student_representatives; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.student_representatives ENABLE ROW LEVEL SECURITY;

--
-- Name: students; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

--
-- Name: subjects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;

--
-- Name: subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: teacher_sections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.teacher_sections ENABLE ROW LEVEL SECURITY;

--
-- Name: teachers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260827230000'),
('20260827220000'),
('20260827200000'),
('20260827120000'),
('20260826040000'),
('20260826020000'),
('20260825200000'),
('20260825160000'),
('20260825140000'),
('20260824220000'),
('20260824200000'),
('20260824180000'),
('20260824140000'),
('20260821030000'),
('20260820210000'),
('20260820180000'),
('20260820040000'),
('20260816120000'),
('20260815120000'),
('20260814150000'),
('20260814140000'),
('20260814120000'),
('20260814070000'),
('20260814050000'),
('20260814031041'),
('20260812040000'),
('20260811220000'),
('20260811163539'),
('20260811162243'),
('20260811143914'),
('20260811143045'),
('20260811141846'),
('20260811134521'),
('20260803140000'),
('20260803120000'),
('20260308004602'),
('20260219042304'),
('20260219021639'),
('20260218210017'),
('20260218210016'),
('20260218210015'),
('20260218210014'),
('20260218210013'),
('20260218210012'),
('20260218210011'),
('20260218210010'),
('20260218210009'),
('20260218210008'),
('20260218210007'),
('20260218210006'),
('20260218210005'),
('20260218210004'),
('20260218210003'),
('20260218210002'),
('20260218210001'),
('20260218210000'),
('20260218204207'),
('20260217181235');

