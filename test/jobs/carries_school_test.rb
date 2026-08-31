require "test_helper"

# Estos tests corren contra la base de verdad, con el RLS encendido, porque lo
# que se está probando es justamente que el aislamiento llegue hasta el worker.
# Un doble en memoria no probaría nada.
class CarriesSchoolTest < ActiveJob::TestCase
  # Cuenta grados. Es el job más simple que sirve para la pregunta: ¿cuántas
  # filas ve este job?
  class JobDeColegio < ApplicationJob
    cattr_accessor :vistos, default: []
    def perform = self.class.vistos << [Current.school&.name, Grade.count]
  end

  class JobDePlataforma < ApplicationJob
    de_toda_la_plataforma
    cattr_accessor :vistos, default: []
    def perform = self.class.vistos << Grade.count
  end

  class JobSinColegio < ApplicationJob
    colegio_opcional
    cattr_accessor :vistos, default: []
    def perform = self.class.vistos << Grade.count
  end

  setup do
    JobDeColegio.vistos = []
    JobDePlataforma.vistos = []
    JobSinColegio.vistos = []

    Current.sin_aislamiento do
      @bolivar = School.create!(name: "Bolívar QA", dea_code: "QA-BOL", location: "Caracas")
      @bello   = School.create!(name: "Bello QA",   dea_code: "QA-BEL", location: "Valencia")

      # Mismo nombre en los dos: si el aislamiento fallara, el job los contaría juntos.
      Grade.create!(school: @bolivar, name: "1er Año", level: :secundaria)
      Grade.create!(school: @bolivar, name: "2do Año", level: :secundaria)
      Grade.create!(school: @bello,   name: "1er Año", level: :secundaria)
    end
  end

  teardown do
    Current.sin_aislamiento do
      Grade.where(school_id: [@bolivar.id, @bello.id]).delete_all
      School.where(id: [@bolivar.id, @bello.id]).delete_all
    end
    Current.reset
  end

  test "un job encolado desde un colegio procesa solo los datos de ese colegio" do
    encolar_desde(@bolivar) { JobDeColegio.perform_later }
    perform_enqueued_jobs

    assert_equal [["Bolívar QA", 2]], JobDeColegio.vistos
  end

  test "dos jobs de colegios distintos en el mismo worker no se contaminan" do
    encolar_desde(@bolivar) { JobDeColegio.perform_later }
    encolar_desde(@bello)   { JobDeColegio.perform_later }
    perform_enqueued_jobs

    # Si el contexto sobreviviera al primer job, el segundo vería 2 y no 1.
    assert_equal [["Bolívar QA", 2], ["Bello QA", 1]], JobDeColegio.vistos
  end

  test "el contexto no sobrevive al job" do
    encolar_desde(@bolivar) { JobDeColegio.perform_later }
    perform_enqueued_jobs

    assert_nil Current.school
    assert_equal "", variable_de_sesion
  end

  # El caso que casi se escapa: `SET LOCAL` pertenece a la transacción más
  # externa, así que un job corrido en línea dentro de una petición le dejaría su
  # colegio puesto a la petición que sigue ejecutándose.
  test "un job corrido en línea le devuelve el contexto a la petición" do
    Current.school = @bolivar
    fijar_contexto(@bolivar.id)

    JobDeColegio.perform_now

    assert_equal @bolivar.id.to_s, variable_de_sesion, "el job se quedó con el contexto de la petición"
    assert_equal @bolivar, Current.school
    assert_equal 2, Grade.count
  end

  test "un job sin colegio falla ruidoso en vez de correr sin filtro" do
    JobDeColegio.perform_later   # sin Current.school

    error = assert_raises(CarriesSchool::SinColegio) { perform_enqueued_jobs }
    assert_match(/se encoló sin colegio/, error.message)
    assert_empty JobDeColegio.vistos
  end

  test "un job de plataforma sí ve todos los colegios, y hay que pedirlo por escrito" do
    JobDePlataforma.perform_later
    perform_enqueued_jobs

    assert_equal 3, JobDePlataforma.vistos.sole
  end

  test "un job de colegio opcional encolado sin sesión no explota y no ve nada" do
    JobSinColegio.perform_later
    perform_enqueued_jobs

    # Cero, no todos: sin contexto el RLS filtra todo. Es el modo correcto de fallar.
    assert_equal 0, JobSinColegio.vistos.sole
  end

  test "el RLS aplica dentro del job, no solo el default_scope" do
    JobDeColegio.class_eval do
      def perform = self.class.vistos << ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM grades").to_i
    end

    encolar_desde(@bolivar) { JobDeColegio.perform_later }
    perform_enqueued_jobs

    # SQL crudo, sin ActiveRecord de por medio: lo filtra Postgres.
    assert_equal 2, JobDeColegio.vistos.sole
  ensure
    JobDeColegio.class_eval { def perform = self.class.vistos << [Current.school&.name, Grade.count] }
  end

  # ActiveJob deserializa los argumentos ANTES de correr los `around_perform`.
  # Si el contexto se pusiera ahí, un job que recibe un objeto de ActiveRecord
  # resolvería su GlobalID sin colegio — cero filas y DeserializationError. Por
  # eso `CarriesSchool` engancha `perform_now`, que envuelve también eso.
  class JobConObjeto < ApplicationJob
    cattr_accessor :vistos, default: []
    def perform(grado) = self.class.vistos << grado.name
  end

  test "un job puede recibir objetos de ActiveRecord: el contexto llega antes de deserializar" do
    JobConObjeto.vistos = []
    grado = Current.sin_aislamiento { Grade.find_by(school_id: @bolivar.id, name: "1er Año") }

    encolar_desde(@bolivar) { JobConObjeto.perform_later(grado) }
    Current.reset
    perform_enqueued_jobs

    assert_equal ["1er Año"], JobConObjeto.vistos
  end

  test "el correo se entrega por un job que lleva colegio" do
    assert_equal MailerDeliveryJob, ApplicationMailer.delivery_job,
                 "el default de Rails (ActionMailer::MailDeliveryJob) no lleva colegio"
    assert_equal :opcional, MailerDeliveryJob.modo_de_colegio
  end

  private

  # Simula el momento del encolado: dentro de una petición, con contexto puesto.
  def encolar_desde(colegio)
    Current.school = colegio
    yield
  ensure
    Current.school = nil
  end

  def variable_de_sesion
    ActiveRecord::Base.connection.select_value("SELECT current_setting('siga.school_id', true)").to_s
  end

  def fijar_contexto(id)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array(["SELECT set_config('siga.school_id', ?, true)", id.to_s])
    )
  end
end
