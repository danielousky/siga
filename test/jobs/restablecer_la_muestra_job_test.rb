require "test_helper"

# El trabajo que restablece la muestra cada noche (`RestablecerLaMuestraJob`).
#
# Lo que borra y cuándo se niega lo prueba `restablecer_la_muestra_test`. Aquí
# van los dos cerrojos que son del trabajo: que no esté agendado donde no debe,
# y que si igual corriera, no haga nada.
class RestablecerLaMuestraJobTest < ActiveJob::TestCase
  include ColegioDeMuestra

  # El trabajo, con el proceso aparte reemplazado: anota si lo lanzaron y
  # contesta lo que el test le diga.
  class DeMentira < RestablecerLaMuestraJob
    cattr_accessor :lanzado, :respuesta

    private

    def lanzar
      self.class.lanzado = true
      self.class.respuesta
    end
  end

  setup do
    DeMentira.lanzado = false
    DeMentira.respuesta = [ "✅ La muestra volvió a su estado sembrado.", true ]
  end

  test "fuera de la muestra, sale sin hacer nada" do
    assert_equal false, DeMentira.perform_now

    assert_not DeMentira.lanzado, "no puede llegar a lanzar la tarea que borra la base"
  end

  test "en la muestra lanza la tarea" do
    en_la_muestra { assert DeMentira.perform_now }

    assert DeMentira.lanzado
  end

  # Un proceso APARTE: los seeds dejan constantes y métodos sueltos en quien
  # los corre, y un worker vive semanas.
  test "y la tarea que lanza es la de restablecer, con el bin/rails de la app" do
    orden = RestablecerLaMuestraJob::ORDEN

    assert_equal "muestra:restablecer", orden.last
    assert File.executable?(orden.first), "#{orden.first} tiene que poder ejecutarse"
    assert_match(/^  task restablecer: :environment/, Rails.root.join("lib/tasks/muestra.rake").read,
                 "y la tarea tiene que existir con ese nombre")
  end

  # ⚠️ Un restablecido que falla tiene que QUEDAR como fallido: es lo único que
  # alguien puede llegar a mirar.
  test "y si la tarea falla, el trabajo falla" do
    DeMentira.respuesta = [ "🚫 En esta base hay colegios que NO son de la muestra", false ]

    en_la_muestra do
      error = assert_raises(RestablecerLaMuestraJob::NoSePudo) { DeMentira.perform_now }

      assert_match(/NO son de la muestra/, error.message)
    end
  end

  # ── Dónde está agendado ───────────────────────────────────────────────────

  test "el calendario lo agenda SOLO con la muestra declarada" do
    assert_not_includes tareas_agendadas, "restablecer_la_muestra"

    en_la_muestra { assert_includes tareas_agendadas, "restablecer_la_muestra" }
  end

  private

  # Lo que `config/recurring.yml` agenda en producción, leído como lo lee Solid
  # Queue: pasando por ERB.
  def tareas_agendadas
    archivo = Rails.root.join("config/recurring.yml")
    ActiveSupport::ConfigurationFile.parse(archivo).fetch("production").keys
  end
end
