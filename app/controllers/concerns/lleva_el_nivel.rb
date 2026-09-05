# El nivel de la sesión: preescolar, primaria o bachillerato.
#
# ## Por qué existe
#
# Un colegio venezolano de tamaño medio dicta los tres a la vez y en SIGA
# vivían mezclados en cada pantalla: al armar una sección el desplegable de
# grados ofrecía los catorce, de «1er Nivel» a «5to Año».
#
# Daniel: *«creo que la gestión de todo, además de dividirse en Año Escolar, el
# otro gran elemento divisor son los tipos que maneja la institución… seteas un
# Año Escolar y luego un tipo: vamos a trabajar Primaria»*.
#
# ## Gemelo de `LlevaElAnioEscolar`
#
# Son la misma clase de cosa y se comportan igual. Lo que cambia es la columna.
#
#     Current.school            del ROL       →  límite de SEGURIDAD
#     Current.academic_period   de la SESIÓN  →  preferencia de quien mira
#     Current.nivel             de la SESIÓN  →  preferencia de quien mira
#
# ⚠️ Se busca contra `Current.school.niveles_para_elegir`, o sea contra los
# grados que el colegio TIENE: un nivel guardado en la sesión que este colegio
# no dicta simplemente no está en la lista y cae a «todos». La comprobación la
# hace el dato, no un `if`.
module LlevaElNivel
  extend ActiveSupport::Concern

  CLAVE = :nivel_escolar
  TODOS = "todos".freeze

  included do
    # ⚠️ Una pantalla donde el nivel no significa nada tiene que DECIRLO.
    #
    # Es la parte que más fácil se hace mal: un filtro que aparece puesto y no
    # filtra es peor que no tenerlo. Quien ve «PRIMARIA» arriba y una lista de
    # ocho departamentos concluye que primaria tiene ocho departamentos.
    #
    # `class_attribute` y no una constante: se hereda, así que
    # `ApplicationController` puede dejarlo en nil y cada pantalla declararlo
    # sin tocar a las demás.
    class_attribute :motivo_sin_nivel, instance_writer: false

    before_action :fijar_el_nivel
    helper_method :nivel_de_la_sesion, :niveles_para_elegir, :mirando_todos_los_niveles?,
                  :puede_elegir_nivel?, :hay_nivel_que_elegir?, :nivel_no_aplica?,
                  :motivo_sin_nivel
  end

  class_methods do
    # Se declara arriba del controller, como `before_action`:
    #
    #     class DepartmentsController < ApplicationController
    #       el_nivel_no_aplica "los departamentos son de todo el colegio"
    #
    # ⚠️ El motivo se escribe en MINÚSCULA y sin punto: se lee pegado al
    # selector, como final de la frase que el propio control empieza.
    def el_nivel_no_aplica(motivo)
      self.motivo_sin_nivel = motivo
    end
  end

  private

  # Solo importa avisarlo cuando hay un nivel PUESTO: con «Todos» elegido no hay
  # nada que contradiga a la pantalla.
  def nivel_no_aplica? = motivo_sin_nivel.present? && !mirando_todos_los_niveles?

  # ⚠️ Corre DENTRO del `around_action` del colegio, igual que el año escolar:
  # sin `Current.school` fijado, el RLS devuelve cero grados y no habría ningún
  # nivel que elegir. Ver el comentario del `include` en `ApplicationController`.
  def fijar_el_nivel
    return if Current.school.nil?

    Current.nivel = nivel_del_enum
  end

  # La OPCIÓN elegida —`:primaria`— o `nil` si son todos.
  def nivel_de_la_sesion
    return @nivel_de_la_sesion if defined?(@nivel_de_la_sesion)

    @nivel_de_la_sesion = calcular_el_nivel
  end

  # Los valores del ENUM que esa opción abarca. Es lo que va a `Current`, y son
  # dos para bachillerato: `secundaria` y `media_tecnica`.
  def nivel_del_enum
    return nil if nivel_de_la_sesion.nil?

    GradoOficial.abarcados_por(nivel_de_la_sesion).presence
  end

  def calcular_el_nivel
    # ⚠️ El valor por defecto es «todos», y NO el primer nivel del colegio.
    #
    # Es la misma trampa que `AcademicPeriod.en_operacion` resolvió para el año,
    # y ya apareció tres veces en este proyecto: un valor por defecto
    # «razonable» que hace que el colegio abra su panel y lea un número que no
    # es el suyo. Un director de 360 alumnos que lee 142 no concluye «estoy en
    # primaria»: concluye que se perdieron los datos.
    #
    # Daniel lo pidió como un modo de trabajo —«vamos a trabajar Primaria»— y un
    # modo de trabajo se ENTRA, no se hereda.
    return nil unless puede_elegir_nivel?

    guardado = session[CLAVE].presence&.to_sym
    return nil if guardado.nil? || guardado.to_s == TODOS

    niveles_para_elegir.include?(guardado) ? guardado : nil
  end

  # Las opciones, en orden pedagógico.
  #
  # ⚠️ Para la DIRECCIÓN salen de los grados del colegio; para un PROFESOR, de
  # los grados que él dicta. Y esa diferencia es todo el punto: darle al de
  # Matemática de primaria un selector con «Bachillerato» adentro es ofrecerle
  # un modo de trabajo donde no tiene nada.
  def niveles_para_elegir
    @niveles_para_elegir ||= profesor? ? niveles_que_dicto : (Current.school&.niveles_para_elegir || [])
  end

  # Los niveles donde este profesor tiene secciones EN EL AÑO DE LA SESIÓN.
  #
  # ⚠️ Del año, no de siempre: un profesor que el año pasado dio primaria y este
  # año solo da media no necesita el selector — y con él vería un «Primaria» que
  # no le muestra nada.
  def niveles_que_dicto
    return [] if current_user&.teacher.nil?

    current_user.teacher.teacher_sections
                .del_anio_de_la_sesion
                .includes(section: :grade)
                .filter_map { |ts| GradoOficial.se_elige_como(ts.section.grade.level) }
                .uniq
                .sort_by { |nivel| GradoOficial::ABARCA.keys.index(nivel) || 99 }
  end

  # ⚠️ Con un solo nivel no hay selector, igual que con un solo año escolar: un
  # desplegable de una opción es un control que no decide nada.
  def hay_nivel_que_elegir? = puede_elegir_nivel? && niveles_para_elegir.many?

  def mirando_todos_los_niveles? = nivel_de_la_sesion.nil?

  # Quién elige.
  #
  # ## ⚠️ El profesor SÍ, y es un cambio de criterio
  #
  # Acá decía que no: *«para ellos el nivel no es una preferencia»*, con el
  # argumento —bueno— de que el AÑO ESCOLAR no se le da al profesor porque
  # sería una manera de cargar notas en el año equivocado sin enterarse.
  #
  # Pero el nivel no es eso. Elegir «Primaria» no le da acceso a nada nuevo ni
  # le mueve dónde escribe: acota lo que ve entre lo que ya es suyo. Y el
  # profesor que da los dos niveles es **el caso normal de un colegio mediano**
  # — en la demo, García dicta Matemática en nueve secciones de primaria y siete
  # de media, todas en una lista sola.
  #
  # Daniel, viéndolo: *«mira eso: primaria y media juntos y sin división… no
  # trabajas las cosas juntas, supongo que primero haces un primaria y luego
  # media»*.
  #
  # ⚠️ Y solo si dicta en MÁS DE UNO: `hay_nivel_que_elegir?` lo comprueba con
  # `.many?`. Al de primaria pura no le aparece nada.
  def puede_elegir_nivel?
    administrador? || equipo_de_siga? || profesor?
  end
end
