# Crea los grados oficiales de un colegio a partir de los niveles que dicta.
#
# ## El paso que desaparece
#
# Antes, un director recién llegado tenía que crear catorce grados a mano, uno
# por uno, escribiendo el nombre y eligiendo el nivel en un desplegable. Catorce
# formularios para escribir información que **no es suya**: la fija el
# Reglamento de la LOE y es idéntica en los 3.900 colegios del país.
#
# Ahora marca hasta tres casillas y los catorce nacen con su nombre correcto, su
# nivel y su orden. Ver `GradoOficial`.
#
# ## ⚠️ Es idempotente, y tiene que serlo
#
# Un colegio que dicta primaria agrega bachillerato dos años después, y vuelve a
# pasar por acá. Los grados que ya existen **no se tocan**: tienen secciones,
# materias y años de historia colgando. Solo se crean los que faltan.
#
# Y por lo mismo **no borra nada**. Desmarcar «primaria» no puede eliminar seis
# grados con sus alumnos adentro; para eso está el borrado explícito de un
# grado, que ya avisa qué se lleva por delante.
class SembrarGrados
  Resultado = Data.define(:creados, :ya_estaban) do
    def total = creados.size + ya_estaban.size
    def alguno_nuevo? = creados.any?
  end

  def self.para(colegio, niveles:)
    new(colegio, niveles).sembrar
  end

  def initialize(colegio, niveles)
    @colegio = colegio
    @niveles = Array(niveles).compact_blank.map(&:to_sym) & GradoOficial::NIVELES
  end

  def sembrar
    creados, ya_estaban = [], []

    # Una transacción sola: si el catálogo se crea a medias, el colegio queda
    # con «1er Año» y sin «2do Año», y eso confunde más que no tener ninguno.
    ActiveRecord::Base.transaction do
      GradoOficial.de_niveles(@niveles).each do |entrada|
        existente = grados_actuales[GradoOficial.normalizar(entrada.nombre)]

        if existente
          ya_estaban << existente
        else
          # `level` y `orden` los deduce el modelo del nombre: no se pasan.
          creados << Grade.create!(school: @colegio, name: entrada.nombre)
        end
      end
    end

    Resultado.new(creados: creados, ya_estaban: ya_estaban)
  end

  private

  # Se compara normalizado, no por igualdad exacta: un colegio que ya tenía
  # «1ER AÑO» cargado a mano —o traído por una importación— no debe terminar con
  # dos grados que son el mismo.
  # ⚠️ `reload`, y no es paranoia.
  #
  # Al sembrar por segunda vez —un colegio que agrega bachillerato— la
  # asociación `colegio.grades` viene CACHEADA de la primera llamada, sin los
  # grados que esa llamada creó. Sin recargar, el servicio cree que no existen,
  # los vuelve a crear y revienta contra el índice único con un «Nombre ya está
  # en uso» que no le explica nada a nadie.
  def grados_actuales
    @grados_actuales ||= @colegio.grades.reload.index_by { |g| GradoOficial.normalizar(g.name) }
  end
end
