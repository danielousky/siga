require "test_helper"

# El importador vive donde están los datos (MOR-204).
#
# Daniel: *«esos enlaces a importar directamente deberían estar en sus
# respectivas listas: Materias / Profesores, Estudiantes e Inscripciones»*.
#
# Antes vivían SOLO en Configuración → Importar datos: para subir la matrícula
# había que salir de Alumnos, entrar a otra sección y elegir de cuál de las tres
# planillas se trataba. La pantalla que ya sabe de qué datos se habla puede
# decirlo por uno.
class ImportarDesdeLaListaTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  def listados
    { subjects_path        => "pensum",
      teachers_path        => "pensum",
      students_path        => "matricula",
      representatives_path => "matricula",
      enrollments_path     => "matricula" }
  end

  test "cada listado ofrece subir SU planilla" do
    faltan = listados.filter_map do |ruta, tipo|
      get ruta
      enlace = css_select(".cabecera-de-lista a[href*='importaciones/new']").first
      next "#{ruta}: no ofrece importar" if enlace.nil?
      next "#{ruta}: apunta a #{enlace['href']}, y esperaba tipo=#{tipo}" unless enlace["href"].include?("tipo=#{tipo}")

      nil
    end

    assert_empty faltan
  end

  # ⚠️ Índigo y no azul: MOR-172 reserva `btn-accion` para lo que hace MUCHO de
  # una vez. Una planilla carga trescientas filas; «Agregar» carga una, y que se
  # distingan es el punto de esa regla.
  test "el botón de importar se distingue del de agregar" do
    get students_path

    assert css_select(".cabecera-de-lista a.btn-accion[href*='importaciones/new']").any?,
           "el importador tiene que ir en el tono de las acciones masivas"
    # ⚠️ `btn-guardar` y ya no `btn-primary`: desde el 8 de septiembre el alta
    # es verde, porque el verde significa «esto queda guardado» y lo llevan por
    # igual el enlace que va al formulario y el submit que lo envía.
    assert css_select(".cabecera-de-lista a.btn-guardar[href*='alumnos/new']").any?,
           "el alta va en el tono de guardar"
  end
end
