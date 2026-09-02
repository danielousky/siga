# Crea las materias oficiales de un colegio, y las cuelga de sus grados (MOR-208).
#
# ## El paso que desaparece
#
# Antes, un colegio nuevo tenía que cargar sus materias una por una y después
# decir en qué grado se cursa cada una. Con seis grados de primaria y seis
# materias son treinta y seis decisiones, todas iguales en los 3.900 colegios
# del país.
#
# Es el mismo argumento de `SembrarGrados` y se resuelve igual: se propone lo
# que dice el MPPE y el colegio ajusta. Ver `MateriaOficial`.
#
# ## ⚠️ Es idempotente, y tiene que serlo
#
# Un colegio que dicta primaria agrega bachillerato dos años después y vuelve a
# pasar por acá. Las materias que ya existen **no se tocan**: pueden tener
# evaluaciones, notas y años de historia colgando. Solo se crean las que faltan,
# y solo se agregan los `GradeSubject` que faltan.
#
# ## ⚠️ Y NO borra nada
#
# Quitar un grado no puede llevarse las materias que se dictaban en él. Para eso
# está el borrado explícito, que ya avisa qué se lleva por delante.
class SembrarMaterias
  Resultado = Data.define(:materias, :ya_estaban, :asignaciones) do
    # ⚠️ `uniq`, y sin él el número miente.
    #
    # Tres materias del catálogo comparten código entre niveles —«Matemática» de
    # primaria y «Matemáticas» de bachillerato son las dos `MAT`—, así que en un
    # colegio completo la MISMA materia se procesa dos veces: se crea la primera
    # vez y cae en `ya_estaban` la segunda. Sumando los dos tamaños salían 20
    # materias donde la base tiene 17.
    def total = (materias + ya_estaban).uniq.size
    def alguna_nueva? = materias.any?
  end

  def self.para(colegio)
    new(colegio).sembrar
  end

  def initialize(colegio)
    @colegio = colegio
  end

  def sembrar
    creadas, ya_estaban, asignaciones = [], [], 0

    # Una transacción sola: un colegio con las materias a medias —Física sí,
    # Química no— es peor que uno sin ninguna, porque nadie sabe cuál falta.
    ActiveRecord::Base.transaction do
      MateriaOficial.para(nombres_de_los_grados).each do |entrada, grados|
        materia = existente(entrada)

        if materia
          ya_estaban << materia
        else
          materia = crear(entrada)
          creadas << materia
        end

        asignaciones += colgar_de_los_grados(materia, grados)
      end
    end

    Resultado.new(materias: creadas, ya_estaban: ya_estaban, asignaciones: asignaciones)
  end

  private

  attr_reader :colegio

  def nombres_de_los_grados = grados_por_nombre.keys

  # ⚠️ `reload`, y no es paranoia — es la misma trampa que documentó
  # `SembrarGrados`: si este servicio corre después de sembrar los grados en la
  # misma petición, la asociación viene CACHEADA sin ellos y acá no habría de
  # qué colgar las materias. El síntoma sería un colegio con materias y sin
  # ninguna asignada, o sea sin poder cargar una nota.
  def grados_por_nombre
    @grados_por_nombre ||= colegio.grades.reload.index_by { |g| GradoOficial.normalizar(g.name) }
  end

  # ⚠️ Se busca por CÓDIGO y no por nombre.
  #
  # «Matemática» (primaria) y «Matemáticas» (bachillerato) son la misma materia
  # con dos nombres, y las dos proponen `MAT`. Buscando por nombre se crearían
  # dos, y la segunda chocaría contra el índice único de `subjects.code` con un
  # error que no le explica nada a nadie.
  #
  # Es la misma regla que ya usa el importador de pensum: si el colegio ya tiene
  # `MAT`, la planilla que trae «Matemática» lo reutiliza.
  def existente(entrada)
    materias_por_codigo[entrada.codigo]
  end

  def materias_por_codigo
    @materias_por_codigo ||= colegio.subjects.reload.index_by(&:code)
  end

  def crear(entrada)
    # ⚠️ Sin departamento, a propósito (decisión de Daniel). El arranque crea
    # las materias «directamente, dejando a un lado el departamento»; el colegio
    # los crea después si los quiere, y ahí les asigna sus materias.
    materia = Subject.create!(school: colegio, name: entrada.nombre, code: entrada.codigo)
    materias_por_codigo[materia.code] = materia
    materia
  end

  # Devuelve cuántas asignaciones NUEVAS se hicieron.
  def colgar_de_los_grados(materia, nombres)
    nombres.count do |nombre|
      grado = grados_por_nombre[GradoOficial.normalizar(nombre)]
      next false if grado.nil?

      # `find_or_create_by` y no `create`: correrlo dos veces no puede duplicar
      # el pensum de un grado.
      GradeSubject.find_or_create_by!(grade: grado, subject: materia).previously_new_record?
    end
  end
end
