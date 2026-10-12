# Alguien del equipo de SIGA (MOR-133).
#
# **No incluye `SchoolScoped` y no tiene `school_id`**, y eso no es un olvido: es
# la corrección del error que produjo cuatro agujeros seguidos. El equipo de SIGA
# no pertenece a ningún colegio; tratarlo como un `Admin` con rol especial fue
# lo que hizo que el director de un colegio cliente viera el pipeline comercial.
#
#     Admin           → una persona DENTRO de un colegio
#     SigaStaff       → una persona de la PLATAFORMA
#
# Son dos ejes distintos. Que `Admin#role` los mezclara —`desarrollador` junto a
# `director` y `secretaria`— es la raíz del problema, no un detalle de nombres.
class SigaStaff < ApplicationRecord
  self.table_name = "siga_staffs"

  include EntraAlSistema

  belongs_to :user

  enum :role, { operaciones: 0, fundador: 1 }

  ETIQUETAS = { "operaciones" => "Operaciones", "fundador" => "Fundador" }.freeze

  validates :user_id, uniqueness: { message: "ya pertenece al equipo de SIGA" }

  def etiqueta = ETIQUETAS.fetch(role, role)

  # Dar de alta colegios y tocar suscripciones es de fundador; mirar el pipeline
  # y responder solicitudes es de operaciones.
  def puede_dar_de_alta_colegios? = fundador?

  # Validar el pago de un colegio y cambiar los datos con que se cobra —el
  # WhatsApp, las cuentas— también (decisión 22 del spec `del-registro-al-cobro`):
  # cada una le abre o le cierra el sistema a un colegio, o le cambia a dónde
  # manda su dinero. Operaciones lo ve todo y no lo cambia.
  def maneja_el_cobro? = fundador?

  # ⚠️ Sin aislamiento a propósito, y por la misma razón que `colegio_de` en
  # `ApplicationController`: averiguar QUIÉN es alguien es anterior a poder
  # filtrar por colegio. Acá además no hay colegio que filtrar.
  def self.para(usuario)
    return nil if usuario.blank?

    Current.sin_aislamiento { find_by(user_id: usuario.id) }
  end
end
