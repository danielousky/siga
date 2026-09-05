# Constructores del plan de evaluación por competencias (MOR-136).
#
# Vive acá y no dentro de un test porque lo necesitan tres: el plan, el
# etiquetado de evaluaciones y la boleta. Una copia privada en cada uno es una
# copia que se despareja.
module PlanesDeEvaluacion
  # Una competencia del plan, con `cuantos` indicadores.
  #
  # ⚠️ Se llama DENTRO de `con_el_colegio`: `Competency` es `SchoolScoped`, así
  # que sin contexto de inquilino el RLS no deja escribir.
  def competencia_con(cuantos, descripcion = "Resuelve problemas de adición y sustracción",
                      seccion: nil, materia: nil, lapso: nil)
    competencia = Competency.create!(
      section: seccion || @a.seccion,
      subject: materia || @a.escenario.materia,
      evaluation_moment: lapso || @lapso,
      descripcion: descripcion
    )
    cuantos.times { |i| competencia.indicators.create!(descripcion: "Indicador #{i + 1}", orden: i) }
    competencia
  end

  # La rúbrica de los cinco niveles que propone SIGA.
  def con_rubrica(colegio)
    con_el_colegio(colegio) { colegio.restablecer_la_rubrica! }
  end
end
