# El buscador que atraviesa toda la app (MOR-149).
#
# ## Qué problema resuelve
#
# Hoy para llegar a un alumno hay que saber que vive en «Estudiantes», ir al
# menú, esperar la página, escribir en el buscador de esa pantalla y elegir. Son
# cuatro pasos y dos cargas para algo que la secretaria hace cuarenta veces al
# día — porque la mamá está del otro lado del mostrador preguntando por su hijo.
#
# Con `⌘K` es: escribir el apellido y apretar Enter.
#
# ## Por qué busca en cuatro cosas y no en todo
#
# Un buscador que devuelve de todo obliga a leer la lista antes de elegir, y eso
# es más lento que ir al menú. Estos cuatro son los que se buscan por NOMBRE:
#
#     alumnos      «pérez» · el 80 % de las búsquedas reales
#     profesores   «garcía»
#     secciones    «1er año a»
#     materias     «matemática» o su código
#
# Lo que NO entra: boletines, constancias, importaciones. Nadie busca «el boletín
# de noviembre» por nombre — se llega a ellos desde la persona o desde la sección.
#
# ## ⚠️ Respeta el aislamiento, y eso no es negociable
#
# Todo sale por los `default_scope` de `SchoolScoped`, sin `unscoped` en ninguna
# parte. Un buscador global que cruzara colegios sería la peor filtración posible:
# escribir tres letras y ver alumnos de otro plantel.
class BusquedaGlobal
  # Cuántos de cada tipo. Cinco es lo que entra en una pantalla sin hacer scroll,
  # y quien busca «pérez» y ve cinco Pérez ya sabe que tiene que afinar.
  POR_TIPO = 5

  # Menos de dos letras devuelve medio colegio: no es una búsqueda, es un listado.
  MINIMO = 2

  Resultado = Struct.new(:tipo, :titulo, :detalle, :ruta, :icono, :persona, keyword_init: true)

  def self.para(termino, rutas:)
    new(termino, rutas: rutas).resultados
  end

  # `rutas` es el helper de rutas del controlador. Se pasa en vez de incluir
  # `Rails.application.routes.url_helpers` para que este servicio no tenga que
  # saber nada del host ni del protocolo.
  def initialize(termino, rutas:)
    @termino = termino.to_s.strip
    @rutas = rutas
  end

  def suficiente? = @termino.length >= MINIMO

  def resultados
    return [] unless suficiente?

    alumnos + profesores + secciones + materias
  end

  private

  # ── las personas ──────────────────────────────────────────────────────────

  def alumnos
    personas(Student, :alumnos) do |alumno|
      Resultado.new(
        tipo: "Estudiante",
        titulo: alumno.user.apellidos_y_nombres,
        detalle: [ alumno.user.identificador, seccion_de(alumno) ].compact_blank.join(" · "),
        ruta: @rutas.student_path(alumno),
        icono: :alumnos,
        persona: alumno.user
      )
    end
  end

  def profesores
    personas(Teacher, :profesores) do |profesor|
      Resultado.new(
        tipo: "Profesor",
        titulo: profesor.user.apellidos_y_nombres,
        detalle: profesor.user.email.presence || profesor.user.identificador,
        ruta: @rutas.teacher_path(profesor),
        icono: :profesores,
        persona: profesor.user
      )
    end
  end

  # ⚠️ Se busca por NOMBRE y por CÉDULA en la misma consulta.
  #
  # La secretaria escribe el apellido cuando la mamá está delante, y la cédula
  # cuando tiene el papel en la mano. Obligar a elegir entre dos buscadores es
  # obligar a saber de antemano qué se tiene.
  def personas(rol, _cual)
    ids = User.where(*BusquedaSinAcentos.condicion(
      %w[users.first_name users.last_name users.second_last_name users.document users.cedula_escolar],
      @termino
    )).select(:id)

    rol.where(user_id: ids)
       .includes(:user)
       .limit(POR_TIPO)
       .map { |registro| yield registro }
  end

  def seccion_de(alumno)
    inscripcion = alumno.enrollments.detect(&:regular?)
    return nil if inscripcion.nil?

    "#{inscripcion.section.grade.name} #{inscripcion.section.name}"
  end

  # ── lo académico ──────────────────────────────────────────────────────────

  # ⚠️ «1er año a» vive en DOS tablas: el grado tiene «1er Año» y la sección «A».
  #
  # Lo natural sería concatenarlas en SQL —`grades.name || ' ' || sections.name`—
  # pero `BusquedaSinAcentos` rechaza cualquier expresión que no sea
  # `tabla.columna`, y con razón: sus campos vienen de constantes hoy, y una
  # validación floja es lo que un día recibe un parámetro del usuario.
  #
  # Así que se parte el término. La ÚLTIMA palabra es la sección si es corta —«A»,
  # «B», «02»— y lo de adelante es el grado. Si no calza, se busca solo por grado,
  # que cubre «1er año» a secas.
  LARGO_DE_UNA_SECCION = 2

  def secciones
    nombre_del_grado, letra = partir_seccion

    consulta = Section.joins(:grade, :academic_period).includes(:grade, :academic_period)
    if nombre_del_grado.present?
      consulta = consulta.where(*BusquedaSinAcentos.condicion(%w[grades.name], nombre_del_grado))
    end
    consulta = consulta.where(*BusquedaSinAcentos.condicion(%w[sections.name], letra)) if letra.present?

    # ⚠️ Primero las del año en curso.
    #
    # Un colegio con cinco años cargados tiene cinco «1er Año A», y quien busca
    # una sección casi siempre quiere la de AHORA: la de 2021 se busca desde el
    # historial, no desde el buscador. Sin este orden, los cinco resultados
    # ocupaban el cupo con años viejos y el vigente no aparecía.
    consulta.order("academic_periods.start_date DESC")
            .limit(POR_TIPO)
            .map do |seccion|
              Resultado.new(
                tipo: "Sección",
                titulo: "#{seccion.grade.name} #{seccion.name}",
                detalle: seccion.academic_period.name,
                ruta: @rutas.section_path(seccion),
                icono: :secciones
              )
            end
  end

  def partir_seccion
    partes = @termino.split(/\s+/)
    return [ @termino, nil ] if partes.size < 2

    ultima = partes.last
    return [ @termino, nil ] if ultima.length > LARGO_DE_UNA_SECCION

    [ partes[0..-2].join(" "), ultima ]
  end

  def materias
    Subject.where(*BusquedaSinAcentos.condicion(%w[subjects.name subjects.code], @termino))
           .limit(POR_TIPO)
           .map do |materia|
             Resultado.new(
               tipo: Vocabulario::AREA_CORTA,
               titulo: materia.name,
               detalle: materia.code,
               ruta: @rutas.subject_path(materia),
               icono: :materias
             )
           end
  end
end
