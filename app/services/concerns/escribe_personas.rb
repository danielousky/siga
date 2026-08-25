# Lo que comparten los dos escritores de planilla (MOR-126).
#
# `CargaDeMatricula` escribe alumnos y representantes, `CargaDePensum` escribe
# profesores, pero los tres se buscan igual y por la misma razón: una persona es
# de la PLATAFORMA y su rol es del colegio.
#
# Vive acá porque el razonamiento del `sin_aislamiento` es lo que arregló
# `MOR-142`, y copiado en dos archivos es una copia que alguien va a "limpiar".
module EscribePersonas
  extend ActiveSupport::Concern

  private

  # ⚠️ La búsqueda va SIN aislamiento, y no es un descuido.
  #
  # Una persona es de la plataforma, no de un colegio: la madre que ya
  # representa a un hijo en otro colegio de SIGA, el alumno que se trasladó
  # trayendo su cédula escolar nacional, el profesor que da clase en dos
  # planteles. Buscándola solo dentro de este colegio no se la encuentra, se
  # intenta crearla de nuevo, y choca contra el índice único de `users.document`
  # con un error que no dice nada — que es exactamente el bloqueo que arregló
  # `MOR-142`.
  def persona_existente(documento, cedula_escolar = nil)
    Current.sin_aislamiento do
      (documento.present? && User.find_by(document: documento)) ||
        (cedula_escolar.present? && User.find_by(cedula_escolar: cedula_escolar)) ||
        nil
    end
  end

  # Qué se le escribe encima a una persona que ya existía.
  #
  # Si ya tiene rol en ESTE colegio, la planilla es la fuente de verdad y se
  # actualiza. Si solo existe en OTRO colegio, se rellenan los huecos y nada
  # más: la planilla de un colegio no puede pisarle el nombre a la ficha que
  # otro colegio mantiene.
  def actualizar(persona, datos, ya_es_de_este_colegio)
    datos.compact_blank.each do |campo, valor|
      persona[campo] = valor if ya_es_de_este_colegio || persona[campo].blank?
    end
  end
end
