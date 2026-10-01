# Varios documentos oficiales en un mismo PDF: uno por alumno.
#
# Un certificado se pide de dos maneras, y es el mismo papel las dos veces:
#
#     la mamá en la secretaría   →  el de SU hijo        →  un documento
#     la secretaria en julio     →  el de toda la sección →  veinticuatro
#
# Hasta el 1 de octubre de 2026 solo existía la primera, y los tres dibujantes
# —primaria, Inicial y la 31059— guardaban los datos de UN alumno. Ver
# `docs/specs/certificados-en-documentos.md`.
#
# ## Por qué un solo PDF y no veinticuatro
#
# Es lo que la secretaria quiere: un archivo para mandar a imprimir, no
# veinticuatro adjuntos. Es la misma decisión de los boletines (`MOR-98`), que
# además lo midieron: una sección entera es medio segundo.
#
# ## ⚠️ `@d` cambia en cada vuelta, y por eso nada se memoriza
#
# Cada clase dibuja leyendo `@d`. Al pasar al alumno siguiente, `@d` es otro —
# y cualquier valor guardado «para no calcularlo dos veces» se queda con el del
# anterior. No falla nada: el PDF sale, con veinticuatro páginas, y la segunda
# dice el colegio, el tipo o el nombre de la primera. Por eso lo que depende de
# `@d` va como MÉTODO y no como variable de instancia.
module UnDocumentoPorAlumno
  extend ActiveSupport::Concern

  # `datos` es el de un alumno —lo que arma `DocumentoDePrimaria` y sus
  # hermanos— o la lista de los de una sección.
  #
  # ⚠️ `Array.wrap` y no `Array()`: los datos son un Hash, y `Array(hash)` lo
  # desarma en pares `[clave, valor]` en vez de envolverlo.
  def initialize(datos)
    @documentos = Array.wrap(datos)
    @d = @documentos.first
  end

  def render
    # Sin esto el PDF saldría igual —una página en blanco— y un papel oficial
    # vacío es peor que un error: alguien lo imprime.
    raise ArgumentError, "no hay ningún documento que dibujar" if @documentos.empty?

    pdf = Prawn::Document.new(page_size: "LETTER", margin: self.class::MARGEN, info: {
      Title: titulo_del_archivo, Creator: "SIGA", CreationDate: Time.current
    })

    @documentos.each_with_index do |datos, i|
      # ⚠️ Página NUEVA, no «la que siga»: la 31059 puede ocupar más de una, así
      # que el alumno siguiente no arranca donde terminó el anterior sino arriba.
      pdf.start_new_page if i.positive?
      @d = datos
      dibujar(pdf)
    end

    pdf.render
  end
end
