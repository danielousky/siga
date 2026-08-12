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
    student_id bigint NOT NULL,
    score numeric(4,2) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL,
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
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.admins FORCE ROW LEVEL SECURITY;


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
-- Name: demo_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.demo_requests (
    id bigint NOT NULL,
    name character varying NOT NULL,
    email character varying NOT NULL,
    institution character varying NOT NULL,
    phone character varying,
    message text,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    current_system integer,
    current_system_detail character varying
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
    student_id bigint NOT NULL,
    enrollment_date date NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL
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
    school_id bigint NOT NULL
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
    leader_teacher_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL
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
    updated_at timestamp(6) without time zone NOT NULL
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
    school_id bigint NOT NULL
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
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.students (
    user_id bigint NOT NULL,
    school_card character varying NOT NULL,
    school_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.students FORCE ROW LEVEL SECURITY;


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
    school_id bigint NOT NULL
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
-- Name: teacher_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teacher_sections (
    id bigint NOT NULL,
    teacher_id bigint NOT NULL,
    section_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    school_id bigint NOT NULL
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
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.teachers FORCE ROW LEVEL SECURITY;


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
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    id_card character varying,
    name character varying,
    last_name character varying
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
-- Name: moment_grades id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moment_grades ALTER COLUMN id SET DEFAULT nextval('public.moment_grades_id_seq'::regclass);


--
-- Name: report_cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards ALTER COLUMN id SET DEFAULT nextval('public.report_cards_id_seq'::regclass);


--
-- Name: schools id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools ALTER COLUMN id SET DEFAULT nextval('public.schools_id_seq'::regclass);


--
-- Name: sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections ALTER COLUMN id SET DEFAULT nextval('public.sections_id_seq'::regclass);


--
-- Name: students user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students ALTER COLUMN user_id SET DEFAULT nextval('public.students_user_id_seq'::regclass);


--
-- Name: subjects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects ALTER COLUMN id SET DEFAULT nextval('public.subjects_id_seq'::regclass);


--
-- Name: teacher_sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teacher_sections ALTER COLUMN id SET DEFAULT nextval('public.teacher_sections_id_seq'::regclass);


--
-- Name: teachers user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers ALTER COLUMN user_id SET DEFAULT nextval('public.teachers_user_id_seq'::regclass);


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
    ADD CONSTRAINT admins_pkey PRIMARY KEY (user_id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


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
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (user_id);


--
-- Name: subjects subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (id);


--
-- Name: teacher_sections teacher_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teacher_sections
    ADD CONSTRAINT teacher_sections_pkey PRIMARY KEY (id);


--
-- Name: teachers teachers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_pkey PRIMARY KEY (user_id);


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
-- Name: index_activity_grades_on_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_grades_on_student_id ON public.activity_grades USING btree (student_id);


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
-- Name: index_enrollments_on_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enrollments_on_student_id ON public.enrollments USING btree (student_id);


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
-- Name: index_sections_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sections_on_school_id ON public.sections USING btree (school_id);


--
-- Name: index_students_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_students_on_school_id ON public.students USING btree (school_id);


--
-- Name: index_students_on_school_id_and_school_card; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_students_on_school_id_and_school_card ON public.students USING btree (school_id, school_card);


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
-- Name: index_teacher_sections_on_teacher_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teacher_sections_on_teacher_id ON public.teacher_sections USING btree (teacher_id);


--
-- Name: index_teachers_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teachers_on_school_id ON public.teachers USING btree (school_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_id_card; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_id_card ON public.users USING btree (id_card);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


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
-- Name: students fk_rails_148c9e88f4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT fk_rails_148c9e88f4 FOREIGN KEY (user_id) REFERENCES public.users(id);


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
-- Name: addresses fk_rails_48c9e0c5a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT fk_rails_48c9e0c5a2 FOREIGN KEY (user_id) REFERENCES public.users(id);


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
    ADD CONSTRAINT fk_rails_5441746b71 FOREIGN KEY (leader_teacher_id) REFERENCES public.teachers(user_id);


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
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: activity_grades fk_rails_9e041c690a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_grades
    ADD CONSTRAINT fk_rails_9e041c690a FOREIGN KEY (student_id) REFERENCES public.students(user_id);


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
-- Name: teacher_sections fk_rails_b2b858bbcc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teacher_sections
    ADD CONSTRAINT fk_rails_b2b858bbcc FOREIGN KEY (teacher_id) REFERENCES public.teachers(user_id);


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
    ADD CONSTRAINT fk_rails_f01c555e06 FOREIGN KEY (student_id) REFERENCES public.students(user_id);


--
-- Name: teacher_sections fk_rails_f438bac6b6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teacher_sections
    ADD CONSTRAINT fk_rails_f438bac6b6 FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


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
-- Name: moment_grades aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.moment_grades USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: report_cards aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.report_cards USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: sections aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.sections USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: students aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.students USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: subjects aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.subjects USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: teacher_sections aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.teacher_sections USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


--
-- Name: teachers aislamiento_por_colegio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aislamiento_por_colegio ON public.teachers USING (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint)))) WITH CHECK (((current_setting('siga.bypass_rls'::text, true) = 'on'::text) OR (NOT (school_id IS DISTINCT FROM (NULLIF(current_setting('siga.school_id'::text, true), ''::text))::bigint))));


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
-- Name: moment_grades; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.moment_grades ENABLE ROW LEVEL SECURITY;

--
-- Name: report_cards; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.report_cards ENABLE ROW LEVEL SECURITY;

--
-- Name: sections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;

--
-- Name: students; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

--
-- Name: subjects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;

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

