# Propone las horas semanales del plan oficial donde el colegio todavía no
# escribió ninguna.
#
#     CargaHorariaOficial.proponer!
#     # => propuestas: 62 · fuera_del_plan: ["Computación", "Educación para el Trabajo"]
#
# Las horas son las de `MateriaOficial` —la Resolución DM/0033 de 2017—. Esto es
# solo el puente entre esa tabla y el pensum de un colegio de verdad.
#
# ## ⚠️ Se reconoce por el NOMBRE del área, no por su código
#
# Los códigos son elecciones de cada colegio y no coinciden con los del plan: en
# la propia siembra «Castellano y Literatura» es `LEN` y no `CAS`, y Educación
# Física es `EDF` y no `EF`. Emparejando por código, medio colegio quedaba en
# blanco sin que nada lo dijera. Es el mismo criterio de `Subject.area_del_31059`:
# el nombre limpio —sin acentos ni mayúsculas— y por cómo EMPIEZA, que es lo que
# aguanta «Matemática» y «Matemáticas», «Inglés» e «Inglés y otras lenguas».
#
# ## ⚠️ No pisa nada
#
# Solo llena las casillas vacías. Un colegio que ya decidió que Inglés lleva
# cuatro horas y no seis —como el de la foto que motivó el diseño— no puede
# perder esa decisión por tocar un botón.
#
# ## ⚠️ «Fuera del plan» es un AVISO, y solo de Media General
#
# Informática, Dibujo o Técnicas de estudio son áreas del colegio y el plan no
# dice nada de ellas: se listan para que alguien las escriba a mano. Lo mismo un
# área del plan dictada en un año donde el plan no la pone —Soberanía Nacional
# en 1er Año—. Las de Primaria y las del 6to Año no se listan: ahí el plan no
# trae horas para nadie, así que no hay nada que haya quedado afuera.
class CargaHorariaOficial
  Resultado = Data.define(:propuestas, :fuera_del_plan) do
    def nada? = propuestas.zero? && fuera_del_plan.empty?
  end

  # Cómo puede empezar el nombre de un área para ser esa del plan. Va por el
  # código OFICIAL —el de `MateriaOficial`—, que es estable; lo que varía de un
  # colegio a otro es el nombre.
  SE_RECONOCE_POR = {
    # ⚠️ «lengua» a secas NO: se llevaría puestas a «Lenguas extranjeras».
    "CAS" => [ "castellano", "lengua y literatura", "lengua y comunicacion", "lenguaje" ],
    "MAT" => [ "matematica" ],
    "EF"  => [ "educacion fisica" ],
    "ING" => [ "ingles", "lenguas extranjeras", "idioma" ],
    "OYC" => [ "orientacion" ],
    "GHC" => [ "geografia", "ghc" ],
    "PGC" => [ "participacion en grupos", "grupo de creacion", "grupos de creacion", "gcrp" ],
    "CN"  => [ "ciencias naturales" ],
    "ART" => [ "arte" ],
    "FIS" => [ "fisica" ],
    "QUI" => [ "quimica" ],
    "BIO" => [ "biologia" ],
    "FSN" => [ "formacion para la soberania", "soberania" ],
    "CT"  => [ "ciencias de la tierra" ]
  }.freeze

  # Cuántas horas fija el plan para esa área en ese grado, o `nil` si el plan no
  # dice nada —porque no la reconoce, o porque en ese grado no se cursa—.
  def self.horas_para(nombre_del_area, nombre_del_grado)
    comparable = Normaliza.limpiar(nombre_del_area).gsub(/[^a-z0-9 ]/, "")

    oficial = MateriaOficial.con_horas.find do |entrada|
      SE_RECONOCE_POR.fetch(entrada.codigo).any? { |inicio| comparable.start_with?(inicio) }
    end

    oficial&.horas_en(nombre_del_grado)
  end

  # ¿El plan trae horas para ese grado? Solo de 1er a 5to Año.
  def self.cubre?(nombre_del_grado)
    buscado = GradoOficial.normalizar(nombre_del_grado)

    MateriaOficial::BACHILLERATO.any? { |grado| GradoOficial.normalizar(grado) == buscado }
  end

  def self.proponer!(pensum = GradeSubject.all)
    propuestas = 0
    fuera_del_plan = []

    pensum.where(weekly_hours: nil).includes(:grade, :subject).find_each do |renglon|
      horas = horas_para(renglon.subject.name, renglon.grade.name)

      if horas
        renglon.update!(weekly_hours: horas)
        propuestas += 1
      elsif cubre?(renglon.grade.name)
        fuera_del_plan << renglon.subject.name
      end
    end

    Resultado.new(propuestas: propuestas, fuera_del_plan: fuera_del_plan.uniq.sort)
  end
end
