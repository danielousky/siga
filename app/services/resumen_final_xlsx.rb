# El RESUMEN FINAL DEL RENDIMIENTO ESTUDIANTIL en Excel, formato `RR-DEA-04-03`.
#
# ## Por qué existe además del PDF
#
# El PDF es el documento terminado: sale como tiene que verse y no se toca. Pero
# este formato tiene tres bloques que SIGA **no puede llenar** —el Plan de
# Estudio, la Mención y todo lo de Educación para el Trabajo— y con solo el PDF
# el colegio queda esperando que nosotros modelemos eso para poder entregar su
# acta.
#
# Con la planilla, abre, escribe lo que falta, imprime y sigue. Es la misma
# decisión que ya llevaba la certificación 31059, y por la misma razón: **la
# versión editable no es un lujo mientras el formato tenga casillas nuestras sin
# modelar — es lo que evita que el colegio quede bloqueado.**
#
# Los datos son los MISMOS: los arma `ResumenFinalDeLaSeccion` y acá solo se
# decide cómo se ven.
class ResumenFinalXlsx
  COLUMNAS = ResumenFinalDeLaSeccion::COLUMNAS_DE_ASIGNATURA

  def initialize(datos)
    @d = datos
  end

  def to_stream = libro.to_stream

  def nombre_de_archivo
    c = @d["curso"]
    "resumen-final-#{"#{c['grado']} #{c['seccion']} #{c['anio_escolar']}".parameterize}.xlsx"
  end

  private

  def libro
    Axlsx::Package.new do |paquete|
      estilos(paquete.workbook)

      paquete.workbook.add_worksheet(name: "Resumen Final") do |hoja|
        @hoja = hoja
        encabezado
        datos_del_plantel
        rendimiento
        profesores
        pie
        ajustar
      end
    end
  end

  def estilos(libro)
    @titulo = libro.styles.add_style(sz: 12, b: true, alignment: { horizontal: :center })
    @codigo = libro.styles.add_style(sz: 8, fg_color: "666666", alignment: { horizontal: :center })
    @seccion = libro.styles.add_style(sz: 9, b: true)
    @rotulo = libro.styles.add_style(sz: 8, b: true)
    @valor = libro.styles.add_style(sz: 8, border: { style: :thin, color: "BBBBBB", edges: [ :bottom ] })
    @cabecera = libro.styles.add_style(sz: 8, b: true, bg_color: "F2F2F2",
                                       alignment: { horizontal: :center, vertical: :center, wrap_text: true },
                                       border: { style: :thin, color: "999999" })
    @celda = libro.styles.add_style(sz: 8, border: { style: :thin, color: "999999" })
    @centrada = libro.styles.add_style(sz: 8, alignment: { horizontal: :center },
                                       border: { style: :thin, color: "999999" })
    # ⚠️ Lo que hay que llenar a mano va con fondo, para que se vea dónde
    # escribir. Un formato con huecos invisibles se entrega incompleto.
    @por_llenar = libro.styles.add_style(sz: 8, bg_color: "FFF9E6",
                                         border: { style: :thin, color: "999999" })
  end

  def encabezado
    @hoja.add_row [ "RESUMEN FINAL DEL RENDIMIENTO ESTUDIANTIL" ], style: @titulo
    @hoja.add_row [ "(Régimen Regular) · Código del Formato RR-DEA-04-03" ], style: @codigo
    @hoja.add_row []
    @hoja.merge_cells("A1:#{ultima_columna}1")
    @hoja.merge_cells("A2:#{ultima_columna}2")
  end

  def datos_del_plantel
    p_ = @d["plantel"]
    c = @d["curso"]

    # ⚠️ Plan de Estudio y Mención van con el fondo de «llenar a mano»: SIGA no
    # los modela, y el colegio tiene que verlos para saber que le tocan a él.
    fila("I. Plan de Estudio:", nil, "Mención:", nil, por_llenar: true)
    fila("Año Escolar:", c["anio_escolar"], "Cód. DEA:", p_["dea"])
    fila("Plantel:", p_["nombre"], "Dirección:", p_["direccion"])
    fila("Municipio:", p_["municipio"], "Ent. Federal:", p_["entidad_federal"])
    fila("Director(a):", p_["director"], "Grado o Año / Sección:", "#{c['grado']} – #{c['seccion']}")
    @hoja.add_row []
  end

  def fila(rotulo, valor, rotulo2, valor2, por_llenar: false)
    estilo = por_llenar ? @por_llenar : @valor
    @hoja.add_row [ rotulo, valor, rotulo2, valor2 ], style: [ @rotulo, estilo, @rotulo, estilo ]
  end

  def rendimiento
    @hoja.add_row [ "III. Resumen Final del Rendimiento" ], style: @seccion
    @hoja.add_row [ "N°", "Cédula de Identidad", "Apellidos y Nombres" ] +
                  (1..COLUMNAS).map { |n| format("%02d", n) } + [ "Resumen" ],
                  style: @cabecera, height: 22

    @d["filas"].each do |f|
      notas = Array.new(COLUMNAS) { |i| f["notas"][i] }
      estilos = [ @centrada, @centrada, @celda ] + Array.new(COLUMNAS, @centrada) + [ @por_llenar ]
      @hoja.add_row([ f["numero"], f["cedula"], f["nombre"] ] + notas + [ nil ], style: estilos)
    end

    @hoja.add_row []
    @hoja.add_row [ "TOTAL DE ALUMNOS DE LA SECCIÓN:", @d["total_de_alumnos"] ],
                  style: [ @rotulo, @centrada ]
    @hoja.add_row []
  end

  def profesores
    @hoja.add_row [ "IV. Asignaturas y profesores" ], style: @seccion
    @hoja.add_row [ "N°", "Asignatura", "Apellidos y Nombres del Profesor",
                    "Cédula de Identidad", "Firma" ], style: @cabecera

    @d["asignaturas"].each do |a|
      @hoja.add_row [ a["codigo"], a["nombre"], a.dig("profesor", "nombre"),
                      a.dig("profesor", "documento"), nil ],
                    style: [ @centrada, @celda, @celda, @centrada, @por_llenar ]
    end
    @hoja.add_row []
  end

  def pie
    @hoja.add_row [ "V. Programas Cursados de Educación para el Trabajo / Horas-Alumnos Semanales de C/Uno." ],
                  style: @seccion
    @hoja.add_row [ nil ], style: @por_llenar
    @hoja.add_row [ "VI. Observaciones:" ], style: @seccion
    @hoja.add_row [ nil ], style: @por_llenar
    @hoja.add_row []
    @hoja.add_row [ "VII. Fecha de Remisión:", nil, "VIII. Fecha de Recepción:", nil ],
                  style: [ @rotulo, @por_llenar, @rotulo, @por_llenar ]
    @hoja.add_row [ "Director(a) — SELLO DEL PLANTEL", nil,
                    "Funcionario Receptor — SELLO DE LA ZONA EDUCATIVA", nil ],
                  style: [ @rotulo, nil, @rotulo, nil ]
    @hoja.add_row [ "Apellidos y Nombres:", @d.dig("firmante", "nombre"),
                    "Apellidos y Nombres:", nil ],
                  style: [ @rotulo, @valor, @rotulo, @por_llenar ]
    @hoja.add_row [ "Número de C.I.:", @d.dig("firmante", "documento"),
                    "Número de C.I.:", nil ],
                  style: [ @rotulo, @valor, @rotulo, @por_llenar ]
    @hoja.add_row [ "Firma:", nil, "Firma:", nil ],
                  style: [ @rotulo, @por_llenar, @rotulo, @por_llenar ]
  end

  def ultima_columna = ("A".."Z").to_a[COLUMNAS + 3]

  def ajustar
    @hoja.column_widths(5, 16, 30, *Array.new(COLUMNAS, 4.5), 12)
    @hoja.page_setup.set(orientation: :landscape, fit_to_width: 1, fit_to_height: 0)
  end
end
