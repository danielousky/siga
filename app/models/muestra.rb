# El colegio de muestra (spec `docs/specs/del-registro-al-cobro.md`, § 4.3 y
# decisiones 2 y 13).
#
#     ES UNA INSTANCIA APARTE    demo.sigaeducando.com, con su propia base
#     NO HAY NADIE REAL          por eso la clave puede estar escrita en la pantalla
#     NO SALE NINGÚN CORREO      ni aunque alguien le configure el SMTP
#     CADA NOCHE VUELVE          a su estado sembrado
#
# Daniel, 8 de octubre de 2026: *«un colegio de muestra con datos, con
# credenciales por rol —directivo, profesor y representante— y clave 123123»*.
#
# ## ⚠️ Se declara con UNA variable, y solo en esa instancia
#
#     SIGA_MUESTRA=1
#
# Es una variable NUEVA a propósito, y no la `SIGA_ENTORNO_DEMO` que ya abría
# los seeds. Aquella se usó contra producción cuando la demo vivía allá: si
# hubiera quedado puesta, desplegar este código convertiría el sistema de los
# colegios en la muestra —con la entrada de un clic y el restablecido de cada
# noche—. Una variable que nunca existió no puede haber quedado en ningún lado.
#
# ## ⚠️ Lo que NO es
#
# No es un modo de la aplicación que un colegio pueda encender, ni un rol, ni un
# plan. Es la instancia entera, y todo lo que se hace distinto aquí pregunta
# `Muestra.activa?` en un solo sitio.
module Muestra
  VARIABLE = "SIGA_MUESTRA".freeze

  # La clave de TODAS las cuentas de la muestra. Pública: está escrita en la
  # pantalla de entrada. Los seeds la toman de aquí, así que la pantalla no
  # puede decir una clave que no abre.
  CLAVE = "123123".freeze

  # El código DEA del colegio de muestra y el de su vecino, que existe para que
  # el aislamiento entre colegios se pueda ver. Por CÓDIGO y no por nombre: el
  # nombre se guarda en mayúscula y con acentos, y ya falló una comparación así
  # (`demo:es_solo_demo`).
  COLEGIO = "BOL001".freeze
  VECINO  = "AND002".freeze
  COLEGIOS = [ COLEGIO, VECINO ].freeze

  # El sitio de verdad, a donde se manda a quien quiere registrar SU colegio.
  SITIO = "https://sigaeducando.com".freeze

  # Una puerta de la muestra: con qué correo se entra, qué rol tiene que tener
  # esa persona y en qué colegio.
  #
  # ⚠️ `rol` va como TEXTO, no como la clase: esto es una constante de un
  # módulo que se recarga, y una clase guardada aquí se queda con la versión
  # vieja al primer cambio en desarrollo.
  Cuenta = Data.define(:clave, :correo, :rol, :colegio, :titulo, :quien, :que_ve) do
    def modelo = rol.constantize
  end

  # Las tres puertas que pidió Daniel: directivo, profesor y representante.
  #
  # ⚠️ El correo del director lo fijó él («pongámosles
  # director.bolivar@mail.com»); los otros dos siguen su forma.
  CUENTAS = [
    Cuenta.new(clave: "director", correo: "director.bolivar@mail.com", rol: "Admin", colegio: COLEGIO,
               titulo: "Dirección", quien: "Ramón Díaz, director",
               que_ve: "El colegio completo: alumnos, secciones, notas, boletines, " \
                       "constancias, la cobranza a las familias y la suscripción."),
    Cuenta.new(clave: "profesor", correo: "profesor.bolivar@mail.com", rol: "Teacher", colegio: COLEGIO,
               titulo: "Profesor", quien: "Carlos García, Matemática",
               que_ve: "Sus secciones de primaria y de bachillerato: el plan de " \
                       "evaluación, la carga de notas y la asistencia de su sección."),
    Cuenta.new(clave: "representante", correo: "representante.bolivar@mail.com", rol: "Representative",
               colegio: COLEGIO,
               titulo: "Representante", quien: "Andreína Suárez, tres hijos",
               que_ve: "Lo que ve una familia: las notas de cada hijo el mismo día, " \
                       "sus boletines, la asistencia y lo que debe al colegio.")
  ].freeze

  # Las otras miradas. No las pidió nadie para vender: están para poder recorrer
  # lo que las tres principales no enseñan —quién no llega a Finanzas, qué ve un
  # alumno, cómo queda un colegio que dejó de pagar—.
  OTRAS = [
    Cuenta.new(clave: "coordinacion", correo: "coord.bolivar@siga.edu", rol: "Admin", colegio: COLEGIO,
               titulo: "Coordinación", quien: "Carmen Rodríguez",
               que_ve: "Lo académico, sin la cobranza ni la suscripción."),
    Cuenta.new(clave: "secretaria", correo: "secretaria.bolivar@siga.edu", rol: "Admin", colegio: COLEGIO,
               titulo: "Secretaría", quien: "Yaneth Bastidas",
               que_ve: "Alumnos, inscripciones y documentos."),
    Cuenta.new(clave: "finanzas", correo: "finanzas.bolivar@siga.edu", rol: "Admin", colegio: COLEGIO,
               titulo: "Finanzas", quien: "Régulo Marcano",
               que_ve: "La cobranza y la suscripción, y nada de lo académico."),
    Cuenta.new(clave: "maestra", correo: "maestra.torres@bolivar.edu", rol: "Teacher", colegio: COLEGIO,
               titulo: "Maestra de primaria", quien: "María Torres",
               que_ve: "El plan por competencias, los indicadores y los informes descriptivos."),
    Cuenta.new(clave: "alumno", correo: "alvaro.lopez001@bolivar.edu", rol: "Student", colegio: COLEGIO,
               titulo: "Alumno", quien: "Álvaro López, bachillerato",
               que_ve: "Sus propias notas."),
    Cuenta.new(clave: "dos-colegios", correo: "maria.perez@familia.test", rol: "Representative",
               colegio: COLEGIO,
               titulo: "Representante en dos colegios", quien: "María Pérez",
               que_ve: "Un hijo en cada colegio, y el selector para pasar de uno a otro."),
    Cuenta.new(clave: "vencido", correo: "director.bello@siga.edu", rol: "Admin", colegio: VECINO,
               titulo: "Un colegio que dejó de pagar", quien: "Luisa Martínez, U.E. Andrés Bello",
               que_ve: "La suscripción vencida: consulta y descarga todo, y no puede cargar nada nuevo.")
  ].freeze

  TODAS = (CUENTAS + OTRAS).freeze

  def self.activa? = ENV[VARIABLE] == "1"

  def self.cuenta(clave) = TODAS.find { |c| c.clave == clave.to_s }

  def self.correos = TODAS.map(&:correo)

  # La persona de una puerta, o nil si hoy no se puede entrar por ella.
  #
  # ⚠️ No alcanza con que exista el correo: tiene que tener ESE rol en ESE
  # colegio. Es lo que impide que la entrada de un clic abra una cuenta que no
  # es de la muestra —alguien que se llamara igual en otra base— y lo que hace
  # que una puerta rota se note aquí y no tres pantallas después, en un «sin rol
  # asignado».
  #
  # Sin aislamiento, por lo mismo que `ApplicationController#colegio_de`: quien
  # entra todavía no tiene colegio.
  def self.usuario_de(cuenta)
    Current.sin_aislamiento do
      usuario = User.find_by(email: cuenta.correo)
      colegio = School.find_by(dea_code: cuenta.colegio)
      next nil if usuario.nil? || colegio.nil?

      usuario if cuenta.modelo.unscoped.exists?(user_id: usuario.id, school_id: colegio.id)
    end
  end

  # ¿Es una de las puertas? Lo preguntan `User` y los roles para no dejar que
  # un visitante le cambie la clave o la borre: la muestra es de todos los que
  # la visitan, y hasta la noche no hay quien la repare.
  #
  # ⚠️ Se pregunta por el correo que TIENE en la base, no por el que trae el
  # formulario: cambiarle el correo es justo lo que hay que poder ver.
  def self.protege?(usuario)
    return false unless activa? && usuario

    correos.include?(usuario.email_in_database.presence || usuario.email)
  end

  def self.url_del_registro = "#{SITIO}/registrarse"

  # Dónde vive la muestra, para las instancias que NO lo son: es a donde la
  # portada del sitio manda a quien quiere verla. Es un ajuste —`Setup`, que el
  # fundador cambia en `/siga/ajustes`— y no una variable de entorno: era
  # `SIGA_MUESTRA_URL` hasta que Daniel pidió moverla (decisión 35). Sin
  # dirección no hay muestra que enseñar, y el enlace no se dibuja.
  def self.direccion = Setup.url_de_la_muestra
end
