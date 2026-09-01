require "test_helper"

# `/salud`: si el worker se cayó, ¿alguien se entera? (MOR-167)
#
# El modo de fallo que este endpoint existe para ver es el peor que hay: la app
# **sigue respondiendo 200 en todas sus pantallas**. Nada se rompe. Solo que los
# promedios se quedan viejos y el colegio lo descubre en el boletín.
#
# Verificado a mano en desarrollo el 1 de septiembre: con el worker apagado
# devolvió 503 con siete trabajos esperando y el más viejo de cuatro días;
# levantando `bin/jobs`, 200 con la cola en cero.
class SaludTest < ActionDispatch::IntegrationTest
  # ⚠️ Sin sesión: un monitor externo no tiene una, y el chequeo tiene que
  # funcionar justamente cuando la app está mal.
  test "contesta sin sesión y sin colegio" do
    get salud_path

    assert_response :success
    cuerpo = response.parsed_body
    assert cuerpo["base"], "no dijo si la base contesta"
    assert cuerpo["cola"].key?("esperando"), "no informa el largo de la cola"
    assert cuerpo["cola"].key?("workers"), "no informa si hay algún worker vivo"
  end

  test "con la cola al día, dice que todo está bien" do
    get salud_path

    assert_response :success
    assert response.parsed_body["ok"]
    assert_equal 0, response.parsed_body["cola"]["mas_viejo_en_segundos"]
  end

  # El caso que importa: un trabajo encolado hace rato y nadie que lo tome.
  test "una cola trancada devuelve 503, que es lo que hace sonar un monitor" do
    encolar_hace(2.hours)

    get salud_path

    assert_response :service_unavailable
    cuerpo = response.parsed_body
    assert_not cuerpo["ok"]
    assert_equal 1, cuerpo["cola"]["esperando"]
    assert cuerpo["cola"]["mas_viejo_en_segundos"] > SaludController::TOLERANCIA.to_i,
           "no midió cuánto lleva esperando el trabajo más viejo"
  end

  # Encolar y ejecutar en el mismo segundo es el funcionamiento NORMAL. Si
  # cualquier trabajo en cola pusiera esto en rojo, el aviso sonaría todo el día
  # y dejaría de leerse.
  test "un trabajo recién encolado no es una alarma" do
    encolar_hace(0.seconds)

    get salud_path

    assert_response :success
    assert response.parsed_body["ok"]
  end

  # ⚠️ Un job que reventó por un dato raro se queda ahí para siempre. Si eso
  # dejara el endpoint en rojo, el monitor avisaría todos los días hasta que
  # alguien limpie la tabla. Lo que urge es que la cola AVANCE.
  test "un trabajo fallido se informa pero no pone todo en rojo" do
    job = encolar_hace(0.seconds)
    SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
    SolidQueue::FailedExecution.create!(job: job, error: '{"message":"lo que sea"}')

    get salud_path

    assert_response :success
    assert response.parsed_body["ok"]
    assert_equal 1, response.parsed_body["cola"]["fallidos"]
  end

  # ⚠️ `/up` y `/salud` no se pueden intercambiar. Si Dokku mirara `/salud`, un
  # worker caído impediría desplegar la corrección que lo arregla.
  test "«up» sigue siendo verde aunque la cola esté trancada" do
    encolar_hace(2.hours)

    get rails_health_check_path
    assert_response :success

    get salud_path
    assert_response :service_unavailable
  end

  private

  # ⚠️ `SolidQueue::Job.create!` crea su propio `ReadyExecution` —eso es lo que
  # significa encolar— así que crearlo a mano choca contra el índice único.
  def encolar_hace(antiguedad)
    SolidQueue::Job.create!(queue_name: "default", class_name: "RecalcularSeccionJob",
                            arguments: "{}", priority: 0).tap do |job|
      job.update_column(:created_at, antiguedad.ago) if antiguedad.positive?
    end
  end
end
