# Modelo de datos de SIGA

> **Generado desde `db/structure.sql`** con `bin/rails modelo:mapa`.
> No editar a mano: se regenera. Última generación: 22 de octubre de 2026.

48 tablas de dominio · 40 con RLS · 40 con `FORCE` · 11 de Solid Queue (sin RLS a propósito) · 3 de Active Storage

## Quién es de un colegio y quién no

```
GLOBALES (sin school_id, sin RLS)      POR COLEGIO (school_id + RLS + FORCE)
-------------------------------------  -------------------------------------
addresses                              academic_periods
demo_requests                          activity_competencies
planteles_oficiales                    activity_grades
schools                                activity_logs
setup                                  admins
siga_settings                          attendances
siga_staffs                            bell_schedules
users                                  charges
                                       competencies
                                       constancias
                                       departments
                                       enrollments
                                       evaluation_activities
                                       evaluation_moments
                                       fees
                                       final_grade_books
                                       grade_subjects
                                       grades
                                       importaciones
                                       indicators
                                       informes
                                       lessons
                                       mensaje_eventos
                                       mensajes
                                       mensajes_entrantes
                                       moment_grades
                                       payment_reports
                                       report_cards
                                       representatives
                                       rubrics
                                       section_closures
                                       sections
                                       student_representatives
                                       students
                                       subjects
                                       subscription_payments
                                       subscriptions
                                       teacher_sections
                                       teachers
                                       time_slots
```

## Tablas

### 🔒 `academic_periods`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `name` | texto NOT NULL |
| `start_date` | date NOT NULL |
| `end_date` | date NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `school_id` → `schools`

### 🔒 `activity_competencies`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `competency_id` | int8 NOT NULL |
| `evaluation_activity_id` | int8 NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `competency_id` → `competencies` · `evaluation_activity_id` → `evaluation_activities` · `school_id` → `schools`

**Únicos:** `(evaluation_activity_id, competency_id)`

### 🔒 `activity_grades`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `evaluation_activity_id` | int8 NOT NULL |
| `score` | numeric(4,2) NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `school_id` | int8 NOT NULL |
| `student_id` | int8 NOT NULL |

**Apunta a:** `evaluation_activity_id` → `evaluation_activities` · `school_id` → `schools` · `student_id` → `students`

**Únicos:** `(evaluation_activity_id, student_id)`

### 🔒 `activity_logs`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `user_id` | int8 NOT NULL |
| `action` | texto NOT NULL |
| `message` | texto NOT NULL |
| `subject_type` | texto |
| `subject_id` | int8 |
| `metadata` | jsonb |
| `ip_address` | texto |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `school_id` | int8 |

**Apunta a:** `school_id` → `schools` · `user_id` → `users`

### 🌐 `addresses`

PK: `id`

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `user_id` | int8 NOT NULL |
| `estado` | texto NOT NULL |
| `municipio` | texto NOT NULL |
| `parroquia` | texto NOT NULL |
| `location` | texto NOT NULL |
| `additional` | texto |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `user_id` → `users`

**Únicos:** `(user_id)`

### 🔒 `admins`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `user_id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `role` | int NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `id` | int8 NOT NULL |

**Apunta a:** `school_id` → `schools` · `user_id` → `users`

**Únicos:** `(user_id, school_id)`

### 🔒 `attendances`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `enrollment_id` | int8 NOT NULL |
| `recorded_by_id` | int8 |
| `date` | date NOT NULL |
| `status` | int |
| `justificacion` | text |
| `justificada_en` | fecha |
| `justificada_por_id` | int8 |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `enrollment_id` → `enrollments` · `recorded_by_id` → `users` · `justificada_por_id` → `users` · `school_id` → `schools`

**Únicos:** `(enrollment_id, date)`

### 🔒 `bell_schedules`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `academic_period_id` | int8 NOT NULL |
| `name` | texto NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `school_id` → `schools` · `academic_period_id` → `academic_periods`

**Únicos:** `(academic_period_id, name)`

### 🔒 `charges`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `enrollment_id` | int8 NOT NULL |
| `fee_id` | int8 NOT NULL |
| `monto` | numeric(10,2) NOT NULL |
| `vence_el` | date NOT NULL |
| `pagado_el` | fecha |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `payment_report_id` | int8 |

**Apunta a:** `enrollment_id` → `enrollments` · `school_id` → `schools` · `fee_id` → `fees` · `payment_report_id` → `payment_reports`

**Únicos:** `(enrollment_id, fee_id)`

### 🔒 `competencies`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `section_id` | int8 NOT NULL |
| `subject_id` | int8 NOT NULL |
| `evaluation_moment_id` | int8 NOT NULL |
| `descripcion` | text NOT NULL |
| `descripcion_canonica` | text NOT NULL |
| `orden` | int |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `evaluation_moment_id` → `evaluation_moments` · `school_id` → `schools` · `subject_id` → `subjects` · `section_id` → `sections`

**Únicos:** `(section_id, subject_id, evaluation_moment_id, descripcion_canonica)`

### 🔒 `constancias`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `enrollment_id` | int8 NOT NULL |
| `issued_by_id` | int8 NOT NULL |
| `code` | texto NOT NULL |
| `snapshot` | jsonb |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `enrollment_id` → `enrollments` · `issued_by_id` → `users` · `school_id` → `schools`

**Únicos:** `(code)`

### 🌐 `demo_requests`

PK: `id`

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `name` | texto NOT NULL |
| `email` | texto |
| `institution` | texto NOT NULL |
| `phone` | texto |
| `message` | text |
| `status` | int |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `current_system` | int |
| `current_system_detail` | texto |
| `veces` | int |
| `telefono_normalizado` | texto(10) |

### 🔒 `departments`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `name` | texto NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `school_id` → `schools`

**Únicos:** `(school_id, name)`

### 🔒 `enrollments`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `section_id` | int8 NOT NULL |
| `enrollment_date` | date NOT NULL |
| `status` | int |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `school_id` | int8 NOT NULL |
| `student_id` | int8 NOT NULL |

**Apunta a:** `school_id` → `schools` · `section_id` → `sections` · `student_id` → `students`

**Únicos:** `(section_id, student_id)`

### 🔒 `evaluation_activities`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `subject_id` | int8 NOT NULL |
| `section_id` | int8 NOT NULL |
| `evaluation_moment_id` | int8 NOT NULL |
| `description` | texto NOT NULL |
| `weight_percentage` | numeric(5,2) NOT NULL |
| `date_scheduled` | date NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `school_id` | int8 NOT NULL |

**Apunta a:** `subject_id` → `subjects` · `section_id` → `sections` · `school_id` → `schools` · `evaluation_moment_id` → `evaluation_moments`

### 🔒 `evaluation_moments`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `name` | texto NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `academic_period_id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `starts_on` | date |
| `ends_on` | date |

**Apunta a:** `academic_period_id` → `academic_periods` · `school_id` → `schools`

**Únicos:** `(academic_period_id, name)`

### 🔒 `fees`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `academic_period_id` | int8 NOT NULL |
| `nombre` | texto NOT NULL |
| `monto` | numeric(10,2) NOT NULL |
| `vence_el` | date NOT NULL |
| `orden` | int |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `academic_period_id` → `academic_periods` · `school_id` → `schools`

**Únicos:** `(academic_period_id, nombre)`

### 🔒 `final_grade_books`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `enrollment_id` | int8 NOT NULL |
| `subject_id` | int8 NOT NULL |
| `annual_average` | numeric(4,2) |
| `remedial_exam_score` | numeric(4,2) |
| `final_score` | numeric(4,2) |
| `comments` | text |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `school_id` | int8 NOT NULL |
| `origen` | int |

**Apunta a:** `enrollment_id` → `enrollments` · `school_id` → `schools` · `subject_id` → `subjects`

**Únicos:** `(enrollment_id, subject_id)`

### 🔒 `grade_subjects`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `grade_id` | int8 NOT NULL |
| `subject_id` | int8 NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `school_id` | int8 NOT NULL |
| `weekly_hours` | int |

**Apunta a:** `grade_id` → `grades` · `subject_id` → `subjects` · `school_id` → `schools`

**Únicos:** `(grade_id, subject_id)`

### 🔒 `grades`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `name` | texto NOT NULL |
| `level` | int NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `school_id` | int8 NOT NULL |
| `escala` | int |
| `coordinator_teacher_id` | int8 |
| `orden` | int |

**Apunta a:** `coordinator_teacher_id` → `teachers` · `school_id` → `schools`

**Únicos:** `(school_id, name)`

### 🔒 `importaciones`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `subido_por_id` | int8 NOT NULL |
| `estado` | int |
| `mapeo` | jsonb |
| `resultado` | jsonb |
| `nombre_del_archivo` | texto |
| `filas_leidas` | int |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `academic_period_id` | int8 |
| `tipo` | int |

**Apunta a:** `school_id` → `schools` · `subido_por_id` → `users` · `academic_period_id` → `academic_periods`

### 🔒 `indicators`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `competency_id` | int8 NOT NULL |
| `descripcion` | text NOT NULL |
| `descripcion_canonica` | text NOT NULL |
| `orden` | int |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `evaluation_activity_id` | int8 |

**Apunta a:** `school_id` → `schools` · `evaluation_activity_id` → `evaluation_activities` · `competency_id` → `competencies`

**Únicos:** `(competency_id, descripcion_canonica)`

### 🔒 `informes`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `enrollment_id` | int8 NOT NULL |
| `evaluation_moment_id` | int8 NOT NULL |
| `escrito_por_id` | int8 NOT NULL |
| `cuerpo` | text NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `enrollment_id` → `enrollments` · `evaluation_moment_id` → `evaluation_moments` · `school_id` → `schools` · `escrito_por_id` → `users`

**Únicos:** `(enrollment_id, evaluation_moment_id)`

### 🔒 `lessons`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `academic_period_id` | int8 NOT NULL |
| `section_id` | int8 NOT NULL |
| `subject_id` | int8 NOT NULL |
| `teacher_id` | int8 |
| `time_slot_id` | int8 NOT NULL |
| `day` | int NOT NULL |
| `starts_min` | int NOT NULL |
| `ends_min` | int NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `school_id` → `schools` · `academic_period_id` → `academic_periods` · `teacher_id` → `teachers` · `subject_id` → `subjects`

### 🔒 `mensaje_eventos`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `mensaje_id` | int8 NOT NULL |
| `tipo` | texto NOT NULL |
| `ocurrio_en` | fecha NOT NULL |
| `detalle` | jsonb |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `school_id` → `schools` · `mensaje_id` → `mensajes`

**Únicos:** `(mensaje_id, tipo, ocurrio_en)`

### 🔒 `mensajes`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `destinatario_id` | int8 NOT NULL |
| `remitente_id` | int8 NOT NULL |
| `asunto` | texto NOT NULL |
| `cuerpo` | text NOT NULL |
| `correo` | texto NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `token` | texto |

**Apunta a:** `remitente_id` → `users` · `destinatario_id` → `users` · `school_id` → `schools`

**Únicos:** `(token)`

### 🔒 `mensajes_entrantes`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `mensaje_id` | int8 |
| `de` | texto NOT NULL |
| `asunto` | texto |
| `cuerpo` | text |
| `recibido_en` | fecha NOT NULL |
| `leido_en` | fecha |
| `crudo` | jsonb |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `school_id` → `schools` · `mensaje_id` → `mensajes`

### 🔒 `moment_grades`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `enrollment_id` | int8 NOT NULL |
| `subject_id` | int8 NOT NULL |
| `evaluation_moment_id` | int8 NOT NULL |
| `final_moment_score` | numeric(4,2) |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `school_id` | int8 NOT NULL |
| `origen` | int |
| `descripcion` | text |

**Apunta a:** `evaluation_moment_id` → `evaluation_moments` · `enrollment_id` → `enrollments` · `school_id` → `schools` · `subject_id` → `subjects`

**Únicos:** `(enrollment_id, subject_id, evaluation_moment_id)`

### 🔒 `payment_reports`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `representative_id` | int8 NOT NULL |
| `referencia` | texto NOT NULL |
| `banco` | texto NOT NULL |
| `monto` | numeric(10,2) NOT NULL |
| `pagado_el` | date NOT NULL |
| `depositante_nombre` | texto NOT NULL |
| `depositante_documento` | texto |
| `nota` | text |
| `estado` | texto |
| `revisado_por_id` | int8 |
| `revisado_el` | fecha |
| `motivo` | text |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `cobros_declarados` | jsonb |
| `corregido_el` | fecha |

**Apunta a:** `school_id` → `schools` · `revisado_por_id` → `users` · `representative_id` → `representatives`

**Únicos:** `(school_id, referencia)`

### 🌐 `planteles_oficiales`

PK: `id`

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `dea_code` | texto |
| `nombre` | texto NOT NULL |
| `entidad_federal` | texto |
| `busqueda` | texto NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `municipio` | texto |

### 🔒 `report_cards`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `enrollment_id` | int8 NOT NULL |
| `evaluation_moment_id` | int8 |
| `code` | texto NOT NULL |
| `snapshot` | jsonb |
| `issued_by_id` | int8 |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `liberado_el` | fecha |
| `liberado_por_id` | int8 |

**Apunta a:** `school_id` → `schools` · `issued_by_id` → `users` · `liberado_por_id` → `users` · `evaluation_moment_id` → `evaluation_moments` · `enrollment_id` → `enrollments`

**Únicos:** `(code)`

### 🔒 `representatives`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `user_id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `phone` | texto |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `user_id` → `users` · `school_id` → `schools`

**Únicos:** `(user_id, school_id)`

### 🔒 `rubrics`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `code` | texto NOT NULL |
| `name` | texto NOT NULL |
| `description` | text |
| `valor` | int NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `school_id` → `schools`

**Únicos:** `(school_id, code)` · `(school_id, valor)`

### 🌐 `schools`

PK: `id`

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `dea_code` | texto |
| `name` | texto NOT NULL |
| `location` | texto |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `entidad_federal` | texto |
| `municipio` | texto |
| `direccion` | texto |
| `telefono` | texto |
| `cdcee` | texto |
| `parroquia` | texto |
| `pasos_omitidos` | jsonb |
| `registrado_por_id` | int8 |
| `tope_de_arrastre` | int |

**Apunta a:** `registrado_por_id` → `users`

**Únicos:** `(dea_code)`

### 🔒 `section_closures`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `section_id` | int8 NOT NULL |
| `evaluation_moment_id` | int8 NOT NULL |
| `cerrado_por_id` | int8 NOT NULL |
| `cerrado_el` | fecha NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `cerrado_por_id` → `users` · `school_id` → `schools` · `evaluation_moment_id` → `evaluation_moments` · `section_id` → `sections`

**Únicos:** `(section_id, evaluation_moment_id)`

### 🔒 `sections`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `grade_id` | int8 NOT NULL |
| `academic_period_id` | int8 NOT NULL |
| `capacity` | int NOT NULL |
| `name` | texto NOT NULL |
| `classroom` | texto |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `school_id` | int8 NOT NULL |
| `leader_teacher_id` | int8 |
| `bell_schedule_id` | int8 |
| `timetable_published_at` | fecha |

**Apunta a:** `leader_teacher_id` → `teachers` · `grade_id` → `grades` · `school_id` → `schools` · `bell_schedule_id` → `bell_schedules` · `academic_period_id` → `academic_periods`

**Únicos:** `(id, academic_period_id)` · `(grade_id, academic_period_id, name)`

### 🌐 `setup`

PK: `id`

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `nombre` | texto NOT NULL |
| `valor` | text |
| `actualizado_por_id` | int8 |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `actualizado_por_id` → `users`

**Únicos:** `(nombre)`

### 🌐 `siga_settings`

PK: `id`

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `titular` | texto |
| `documento` | texto |
| `pago_movil_banco` | texto |
| `pago_movil_telefono` | texto |
| `cuenta` | texto |
| `actualizado_por_id` | int8 |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `actualizado_por_id` → `users`

### 🌐 `siga_staffs`

PK: `id`

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `user_id` | int8 NOT NULL |
| `role` | int |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `user_id` → `users`

**Únicos:** `(user_id)`

### 🔒 `student_representatives`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `representative_id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `parentesco` | int |
| `principal` | boolean |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `student_id` | int8 NOT NULL |

**Apunta a:** `student_id` → `students` · `representative_id` → `representatives` · `school_id` → `schools`

**Únicos:** `(representative_id, student_id)`

### 🔒 `students`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `user_id` | int8 NOT NULL |
| `school_card` | texto NOT NULL |
| `school_id` | int8 NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `id` | int8 NOT NULL |

**Apunta a:** `school_id` → `schools` · `user_id` → `users`

**Únicos:** `(school_id, school_card)` · `(user_id, school_id)`

### 🔒 `subjects`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `code` | texto NOT NULL |
| `name` | texto NOT NULL |
| `department_id` | int8 |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `school_id` | int8 NOT NULL |
| `escala` | int |

**Apunta a:** `department_id` → `departments` · `school_id` → `schools`

**Únicos:** `(school_id, code)`

### 🔒 `subscription_payments`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `reportado_por_id` | int8 NOT NULL |
| `medio` | texto NOT NULL |
| `monto` | numeric(14,2) NOT NULL |
| `referencia` | texto |
| `pagado_el` | date NOT NULL |
| `nota` | text |
| `alumnos` | int NOT NULL |
| `precio_por_alumno` | numeric(6,2) NOT NULL |
| `minimo_mensual` | numeric(8,2) NOT NULL |
| `precio_mensual` | numeric(10,2) NOT NULL |
| `estado` | texto |
| `revisado_por_id` | int8 |
| `revisado_el` | fecha |
| `motivo` | text |
| `cubre_desde` | date |
| `cubre_hasta` | date |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `school_id` → `schools` · `revisado_por_id` → `users` · `reportado_por_id` → `users`

**Únicos, con condición:** `(school_id, referencia)` si `((referencia IS NOT NULL) AND ((estado)::text <> 'rechazado'::text))` · `(school_id)` si `((estado)::text = 'en_revision'::text)`

### 🔒 `subscriptions`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `plan` | int |
| `status` | int |
| `matricula_facturada` | int |
| `precio_mensual` | numeric(10,2) |
| `vigente_desde` | date |
| `vigente_hasta` | date |
| `dias_de_gracia` | int |
| `notas` | text |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `precio_por_alumno` | numeric(6,2) |
| `minimo_mensual` | numeric(8,2) |
| `aviso_enviado` | int |
| `aviso_del_vencimiento` | date |

**Apunta a:** `school_id` → `schools`

**Únicos:** `(school_id)`

### 🔒 `teacher_sections`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `section_id` | int8 NOT NULL |
| `subject_id` | int8 NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `school_id` | int8 NOT NULL |
| `teacher_id` | int8 NOT NULL |

**Apunta a:** `school_id` → `schools` · `teacher_id` → `teachers` · `section_id` → `sections` · `subject_id` → `subjects`

**Únicos:** `(section_id, subject_id, teacher_id)` · `(section_id, subject_id)`

### 🔒 `teachers`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `user_id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `id` | int8 NOT NULL |

**Apunta a:** `school_id` → `schools` · `user_id` → `users`

**Únicos:** `(user_id, school_id)`

### 🔒 `time_slots`

PK: `id` · RLS + FORCE

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `school_id` | int8 NOT NULL |
| `bell_schedule_id` | int8 NOT NULL |
| `starts_min` | int NOT NULL |
| `ends_min` | int NOT NULL |
| `kind` | int |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |

**Apunta a:** `bell_schedule_id` → `bell_schedules` · `school_id` → `schools`

**Únicos:** `(id, starts_min, ends_min)`

### 🌐 `users`

PK: `id`

| Columna | Tipo |
| -- | -- |
| `id` | int8 NOT NULL |
| `email` | texto |
| `encrypted_password` | texto |
| `reset_password_token` | texto |
| `reset_password_sent_at` | fecha |
| `remember_created_at` | fecha |
| `created_at` | fecha NOT NULL |
| `updated_at` | fecha NOT NULL |
| `document` | texto |
| `first_name` | texto |
| `last_name` | texto |
| `document_type` | int |
| `cedula_escolar` | texto |
| `second_last_name` | texto |
| `birth_date` | date |
| `sex` | int |
| `birth_place` | texto |
| `birth_country` | texto |
| `birth_state` | texto |
| `birth_municipality` | texto |
| `rif` | texto |

**Únicos:** `(cedula_escolar)` · `(document)` · `(email)` · `(reset_password_token)` · `(rif)`

