# La rúbrica del colegio: con qué palabras se lee una nota (MOR-136).
#
# ## Una pantalla, un guardado
#
# Los cinco niveles se editan juntos porque una rúbrica es una ESCALERA: sus
# peldaños solo tienen sentido unos respecto de otros —«PA» cubre de 17 a 18
# *porque* «PC» empieza en 19—. Un CRUD de cinco pantallas dejaría al colegio
# pasando por estados con huecos y solapes, y esos estados se pueden guardar.
#
# ## ⚠️ No tener rúbrica no rompe nada
#
# Un colegio sin filas ve el número, que es exactamente lo que ve hoy. Por eso
# la pantalla PROPONE la de SIGA en vez de crearla sola: igual que el plan de
# competencias, lo que nadie miró es lo que nadie entiende.
class RubricsController < ApplicationController
  el_nivel_no_aplica "la rúbrica es de todo el colegio"
  before_action :require_direccion!

  # ⚠️ Cuando no hay ninguna, se muestran las cinco de la propuesta SIN GUARDAR.
  # El colegio las ve, las ajusta y las guarda de una vez — en vez de estrenar
  # la pantalla con una tabla vacía y un formulario en blanco.
  def show
    @colegio = Current.school
    @propuesta = !Rubric.definida?
    @rubricas = @propuesta ? Rubric::POR_DEFECTO.map { |datos| Rubric.new(datos) } : Rubric.en_orden.to_a
  end

  def update
    @colegio = Current.school

    if @colegio.update(datos_de_la_rubrica)
      auditar("definió la rúbrica")
      redirect_to rubrica_path, notice: "Listo: así se leerán las notas de primaria en la boleta."
    else
      # ⚠️ Se repinta con lo que la persona escribió, no con lo que hay en la
      # base: perder cinco filas de texto por un código repetido es la manera
      # de que nadie vuelva a tocar esta pantalla.
      @rubricas = @colegio.rubrics.to_a
      @propuesta = false
      flash.now[:alert] = "Revise los niveles marcados."
      render :show, status: :unprocessable_entity
    end
  end

  # Vuelve a la propuesta de SIGA.
  #
  # ⚠️ Es reversible en el sentido que importa —ninguna nota cambia— pero borra
  # los nombres que el colegio escribió, así que la vista pide confirmación.
  def restablecer
    Current.school.restablecer_la_rubrica!
    auditar("restableció la rúbrica que propone SIGA")

    redirect_to rubrica_path, notice: "La rúbrica volvió a los cinco niveles que propone SIGA."
  end

  private

  # ⚠️ Token propio y no `colegio_updated`, por lo mismo que `estructura_copiada`
  # (MOR-166): en la pantalla que contesta «¿por qué la boleta de mi hijo se lee
  # distinto que en diciembre?», «alguien editó el colegio» no dice nada. Y el
  # mensaje guarda los NIVELES que quedaron: es lo único que explica el cambio,
  # porque ninguna nota se movió.
  def auditar(que_hizo)
    niveles = Rubric.en_orden.map { |r| "#{r.code} desde #{r.valor}" }.join(" · ")

    log_activity(
      action:  "rubrica_definida",
      subject: Current.school,
      message: "#{current_user.nombre_completo} #{que_hizo}: #{niveles.presence || 'sin niveles'}"
    )
  end

  def datos_de_la_rubrica
    params.require(:school).permit(
      rubrics_attributes: [ :id, :code, :name, :description, :valor, :_destroy ]
    )
  end
end
