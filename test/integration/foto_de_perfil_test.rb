require "test_helper"

# Subir la foto de una persona, desde el formulario de cualquiera de los roles.
#
# ⚠️ El modelo la aceptaba desde MOR-149 —`has_one_attached :foto`, con sus
# formatos y su tope de 2 MB— y `AvataresHelper` la dibujaba desde entonces.
# Lo que faltaba era el CAMPO: ningún formulario la mandaba, así que la única
# manera de que una persona tuviera foto era la consola.
#
#     ╭────────╮   [↑ Subir una foto]      PNG, JPG o WEBP
#     │   AL   │   [🗑 Quitar]             hasta 2 MB
#     ╰────────╯
class FotoDePerfilTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    sign_in @a.director
  end

  def una_foto
    Rack::Test::UploadedFile.new(Rails.root.join("db/seeds_assets/escudo_bolivar.png"), "image/png")
  end

  # ── El campo está en los cuatro formularios ───────────────────────────────

  {
    "alumno" => :new_student_path, "profesor" => :new_teacher_path,
    "administrador" => :new_admin_path, "representante" => :new_representative_path
  }.each do |quien, ruta|
    test "el formulario de #{quien} ofrece subir una foto" do
      get send(ruta)

      assert_response :success
      assert_select "input[type=file][name*=foto]"
      # ⚠️ Sin `multipart/form-data` el archivo llega como el NOMBRE del archivo,
      # una cadena, y Active Storage lo rechaza sin decir por qué.
      assert_select "form[enctype='multipart/form-data']"
    end
  end

  # ── Subir ─────────────────────────────────────────────────────────────────

  test "la foto se guarda con el resto de la ficha" do
    docente = @a.registro_de_profesor

    patch teacher_path(docente), params: { teacher: { user_attributes: {
      id: docente.user_id, first_name: docente.user.first_name, foto: una_foto
    } } }

    assert_redirected_to teacher_path(docente)
    assert docente.user.reload.foto.attached?, "el campo tiene que llegar hasta el modelo"
  end

  # ⚠️ Quitar es un CAMPO del formulario, no un botón que borra en el acto: con
  # un `DELETE` aparte, cancelar la edición dejaba la foto igualmente borrada.
  test "quitar la foto la borra al guardar" do
    docente = @a.registro_de_profesor
    docente.user.foto.attach(una_foto)

    perform_enqueued_jobs do
      patch teacher_path(docente), params: { teacher: { user_attributes: {
        id: docente.user_id, first_name: docente.user.first_name, quitar_foto: "1"
      } } }
    end

    assert_not docente.user.reload.foto.attached?
  end

  test "sin pedir que se quite, la foto se queda" do
    docente = @a.registro_de_profesor
    docente.user.foto.attach(una_foto)

    perform_enqueued_jobs do
      patch teacher_path(docente), params: { teacher: { user_attributes: {
        id: docente.user_id, first_name: "Corregido", quitar_foto: "0"
      } } }
    end

    assert docente.user.reload.foto.attached?, "corregir el nombre no puede borrar la foto"
  end

  # ── Lo que no es una foto ─────────────────────────────────────────────────

  test "un archivo que no es imagen se rechaza" do
    docente = @a.registro_de_profesor
    planilla = Rack::Test::UploadedFile.new(Rails.root.join("Gemfile"), "text/plain")

    patch teacher_path(docente), params: { teacher: { user_attributes: {
      id: docente.user_id, first_name: docente.user.first_name, foto: planilla
    } } }

    assert_response :unprocessable_entity
    assert_not docente.user.reload.foto.attached?
  end
end
