require "test_helper"

# El registro de una importación de matrícula (MOR-126).
class ImportacionTest < ActiveSupport::TestCase
  setup do
    @escenario = escenario_academico
    @colegio = @escenario.colegio
    @usuario = User.create!(first_name: "Ana", last_name: "Secretaria",
                            document: "99777001", document_type: :cedula_v,
                            email: "ana.secretaria@colegio.test", password: "123123")
  end

  # ── leer el archivo adjunto ───────────────────────────────────────────────

  test "lee la planilla desde el archivo adjunto" do
    con_el_colegio(@colegio) do
      importacion = importar(<<~CSV)
        APELLIDOS Y NOMBRES,C.I.,AÑO/SECC,REPRESENTANTE,CEDULA REPRESENTANTE
        PÉREZ GÓMEZ ANA,V-31222333,1er Año A,MARÍN GONZÁLEZ MARÍA,V-12345678
      CSV

      assert_equal 1, importacion.planilla.filas.size
      assert_equal "PÉREZ GÓMEZ ANA", importacion.planilla.filas.first["APELLIDOS Y NOMBRES"]
    end
  end

  # El adjunto se guarda con un nombre aleatorio, así que la extensión real hay
  # que llevarla aparte o roo no sabe con qué backend abrirlo.
  test "respeta la extensión original aunque el adjunto se llame distinto" do
    con_el_colegio(@colegio) do
      importacion = importar("A,B,C\n1,2,3\n")

      assert_equal "matricula.csv", importacion.nombre_del_archivo
      assert_nothing_raised { importacion.planilla }
    end
  end

  # ── el mapeo sugerido ─────────────────────────────────────────────────────

  test "propone el mapeo solo, para que solo haya que corregir" do
    con_el_colegio(@colegio) do
      importacion = importar(<<~CSV)
        Nº,APELLIDOS Y NOMBRES,C.I.,AÑO/SECC,REPRESENTANTE,CEDULA REPRESENTANTE,CORREO REPRESENTANTE
        1,PÉREZ GÓMEZ ANA,V-31222333,1er Año A,MARÍN GONZÁLEZ MARÍA,V-12345678,m@m.com
      CSV

      sugerido = importacion.mapeo_sugerido

      assert_equal "nombre_completo", sugerido["APELLIDOS Y NOMBRES"]
      assert_equal "documento", sugerido["C.I."]
      assert_equal "seccion", sugerido["AÑO/SECC"]
      assert_equal "representante", sugerido["REPRESENTANTE"]
      assert_equal "correo_del_representante", sugerido["CORREO REPRESENTANTE"]
    end
  end

  # Una columna que SIGA no usa no se mapea a nada. Inventarle un destino sería
  # peor que ignorarla.
  test "las columnas que no reconoce quedan fuera del mapeo" do
    con_el_colegio(@colegio) do
      importacion = importar("Nº,OBSERVACIONES,APELLIDOS Y NOMBRES\n1,repitió,PÉREZ ANA\n")

      assert_not importacion.mapeo_sugerido.key?("Nº")
      assert_not importacion.mapeo_sugerido.key?("OBSERVACIONES")
      assert importacion.mapeo_sugerido.key?("APELLIDOS Y NOMBRES")
    end
  end

  test "el mapeo guardado gana sobre el sugerido" do
    con_el_colegio(@colegio) do
      importacion = importar("APELLIDOS Y NOMBRES,C.I.\nPÉREZ ANA,V-31222333\n")
      importacion.update!(mapeo: { "C.I." => "cedula_escolar" })

      assert_equal "cedula_escolar", importacion.mapeo_efectivo["C.I."]
    end
  end

  # ── lo que bloquea el avance ──────────────────────────────────────────────

  # ⚠️ Rellenar una columna obligatoria con un valor por defecto sería inventar
  # datos de un alumno. Mientras falte alguna, no se avanza.
  test "no se puede previsualizar sin las columnas obligatorias" do
    con_el_colegio(@colegio) do
      importacion = importar("APELLIDOS Y NOMBRES,C.I.\nPÉREZ ANA,V-31222333\n")

      assert_not importacion.lista_para_previsualizar?
      faltantes = importacion.obligatorias_sin_mapear.map(&:clave)

      assert_includes faltantes, :seccion
      assert_includes faltantes, :representante
      assert_includes faltantes, :cedula_del_representante
      assert_not_includes faltantes, :nombre_completo
    end
  end

  test "con las cuatro obligatorias mapeadas, se puede previsualizar" do
    con_el_colegio(@colegio) do
      importacion = importar(<<~CSV)
        APELLIDOS Y NOMBRES,AÑO/SECC,REPRESENTANTE,CEDULA REPRESENTANTE
        PÉREZ ANA,1er Año A,MARÍN MARÍA,V-12345678
      CSV

      assert importacion.lista_para_previsualizar?
      assert_empty importacion.obligatorias_sin_mapear
    end
  end

  # ── el aislamiento ────────────────────────────────────────────────────────

  # La tabla es `SchoolScoped` y lleva su política de RLS. Lo que aísla al
  # ARCHIVO es esta fila: Active Storage no tiene school_id, así que sin poder
  # ver la importación no hay cómo llegar al adjunto.
  test "una importación de otro colegio no se ve" do
    otro = escenario_academico(nombre: "U.E. Vecina").colegio

    ajena = con_el_colegio(otro) do
      Importacion.create!(school: otro, subido_por: @usuario, nombre_del_archivo: "ajena.csv")
    end

    con_el_colegio(@colegio) do
      assert_nil Importacion.find_by(id: ajena.id)
    end
  end

  # ── el archivo no vive para siempre ───────────────────────────────────────

  # Trae los datos personales de 360 menores. Guardarlo indefinidamente
  # convierte al servidor en un archivo de datos de menores sin ninguna razón.
  test "el archivo de una importación vieja se puede purgar" do
    con_el_colegio(@colegio) do
      importacion = importar("A,B\n1,2\n")

      assert_not importacion.purgable?, "recién subida no se purga"

      importacion.update!(estado: :confirmada)

      assert_not importacion.purgable?, "recién confirmada tampoco"

      importacion.update_column(:updated_at, 31.days.ago)

      assert importacion.reload.purgable?
    end
  end

  test "una importación a medias no se purga aunque sea vieja" do
    con_el_colegio(@colegio) do
      importacion = importar("A,B\n1,2\n")
      importacion.update_column(:updated_at, 90.days.ago)

      assert_not importacion.reload.purgable?
    end
  end

  private

  def importar(contenido, nombre: "matricula.csv")
    importacion = Importacion.create!(school: @colegio, subido_por: @usuario,
                                      nombre_del_archivo: nombre)
    importacion.archivo.attach(
      io: StringIO.new(contenido), filename: nombre, content_type: "text/csv"
    )
    importacion
  end
end
