require "test_helper"

# Lo que el modelo EXIGE, el navegador lo pide antes de enviar (MOR-201).
#
# Daniel, con el formulario del colegio en blanco: *«el form no validó los
# campos, me permitió guardar sin decir los campos requeridos (todos)»*.
#
# Y no había ni un `required` en toda la app: el servidor rechazaba y pintaba el
# error, pero el navegador dejaba enviar. Un viaje de ida y vuelta para
# enterarse de algo que se sabía antes de salir — y en una conexión de colegio
# ese viaje se nota.
#
# ⚠️ `required` NO reemplaza la validación del modelo. Son las mismas tres capas
# que `campo-filtrado`: el navegador ataja lo obvio, el modelo ataja lo que
# llega por otra puerta —el importador, la API, el JavaScript apagado— y ninguna
# sobra.
class CamposObligatoriosTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  # Las altas donde el modelo exige algo, con el campo que exige.
  #
  # ⚠️ La ruta va por HELPER y por eso se resuelve dentro del test: los helpers
  # no existen todavía en el cuerpo de la clase.
  def exigidos
    { new_subject_path    => %w[subject[code] subject[name]],
      new_department_path => %w[department[name]],
      new_grade_path      => %w[grade[name]] }
  end

  test "los campos que el modelo exige llevan `required`" do
    sin_marcar = exigidos.flat_map do |ruta, campos|
      get ruta
      campos.filter_map do |nombre|
        entrada = css_select("[name='#{nombre}']").first
        next "#{ruta}: no existe #{nombre}" if entrada.nil?

        "#{ruta}: #{nombre}" unless entrada["required"]
      end
    end

    assert_empty sin_marcar,
      "el modelo los exige y el navegador deja enviar sin ellos:\n  " + sin_marcar.join("\n  ")
  end

  # ⚠️ Se deduce del MODELO, no se escribe. Escrito a mano funciona el primer
  # día: alguien afloja una validación y el `required` se queda impidiendo
  # enviar algo que ya es opcional.
  test "requerido? sale de los validadores, no de una lista" do
    assert requerido?(School, :name)
    assert requerido?(Subject, :code)
    # ⚠️ Y este es el ejemplo de por qué se deduce en vez de escribirse: el DEA
    # era obligatorio y dejó de serlo (`MOR-208`, segunda mitad). Escrito a
    # mano, el `required` habría quedado impidiendo enviar un campo que ya es
    # opcional — y nadie lo habría notado hasta que un colegio no pudiera
    # registrarse.
    assert_not requerido?(School, :dea_code), "el DEA se carga después del registro"
    assert_not requerido?(User, :email), "el correo es opcional desde MOR-142"
    assert_not requerido?(User, :document), "document o cedula_escolar, no los dos"
  end

  # Una presencia CONDICIONAL no es una presencia: marcarla obligaría a llenar
  # el campo justo en el caso en que no lo es.
  test "una presencia condicional no cuenta como obligatoria" do
    clase = Class.new do
      include ActiveModel::Model
      attr_accessor :a, :b
      validates :a, presence: true
      validates :b, presence: true, if: -> { false }
    end

    assert requerido?(clase, :a)
    assert_not requerido?(clase, :b)
  end

  private

  def requerido?(...) = ApplicationController.helpers.requerido?(...)
end
