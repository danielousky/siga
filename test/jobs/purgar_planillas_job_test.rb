require "test_helper"

# Los archivos de las importaciones no viven para siempre (MOR-126).
#
# Traen nombre, cédula, fecha de nacimiento y dirección de 360 menores. Treinta
# días después ya no le sirven a nadie, y un servidor con el padrón de treinta
# colegios adentro es un objetivo.
class PurgarPlanillasJobTest < ActiveJob::TestCase
  setup do
    @a = escenario_academico(nombre: "Colegio A")
    @b = escenario_academico(nombre: "Colegio B")
  end

  # ⚠️ Se borra el ARCHIVO, no la importación. La fila es la bitácora —quién
  # importó qué, cuándo y con qué resultado— y eso se conserva.
  test "borra el archivo y deja la fila" do
    importacion = importacion_en(@a, estado: :confirmada, hace: 40.days)

    PurgarPlanillasJob.perform_now

    assert Current.sin_aislamiento { Importacion.unscoped.exists?(importacion.id) },
           "la bitácora se conserva"
    assert_not adjunto?(importacion, @a)
  end

  test "no toca las recientes" do
    importacion = importacion_en(@a, estado: :confirmada, hace: 3.days)

    PurgarPlanillasJob.perform_now

    assert adjunto?(importacion, @a)
  end

  # ⚠️ El caso que se quedaba para siempre: alguien sube una planilla, se
  # confunde y se va. Que quede a medias no la vuelve menos sensible.
  test "también borra las que quedaron a medias" do
    importacion = importacion_en(@a, estado: :cargada, hace: 40.days)

    PurgarPlanillasJob.perform_now

    assert_not adjunto?(importacion, @a)
  end

  # ⚠️ La obligación es de SIGA, no de un colegio: un worker con contexto de uno
  # solo dejaría los archivos de los otros veintinueve.
  test "cruza colegios: no deja los archivos de los demás" do
    de_a = importacion_en(@a, estado: :confirmada, hace: 40.days)
    de_b = importacion_en(@b, estado: :confirmada, hace: 40.days)

    PurgarPlanillasJob.perform_now

    assert_not adjunto?(de_a, @a)
    assert_not adjunto?(de_b, @b)
  end

  test "no revienta cuando no hay nada que borrar" do
    assert_equal 0, PurgarPlanillasJob.perform_now
  end

  private

  # ⚠️ Recargar DENTRO del colegio, no fuera.
  #
  # El job corre `de_toda_la_plataforma` y al terminar deja `Current.school` en
  # nil; un `importacion.reload` después no encuentra la fila —el RLS sin
  # contexto devuelve CERO, que es lo que tiene que hacer— y el test falla por
  # una razón que no es la que se está probando.
  def adjunto?(importacion, escenario)
    con_el_colegio(escenario.colegio) { Importacion.find(importacion.id).archivo.attached? }
  end

  def importacion_en(escenario, estado:, hace:)
    con_el_colegio(escenario.colegio) do
      importacion = Importacion.create!(
        school: escenario.colegio, subido_por: escenario.alumno.user,
        nombre_del_archivo: "matricula.csv", estado: estado, filas_leidas: 3
      )
      importacion.archivo.attach(
        io: StringIO.new("NOMBRE,CEDULA\nPÉREZ ANA,V-1\n"),
        filename: "matricula.csv", content_type: "text/csv"
      )
      # `update_column` para saltarse el `touch` de `updated_at`, que es
      # justamente la columna que decide si está vencida.
      importacion.update_column(:updated_at, hace.ago)
      importacion
    end
  end
end
