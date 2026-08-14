# El equipo de SIGA puede entrar a un colegio y ver lo que ve el colegio.
#
# ## Es una decisión con fecha de vencimiento, y conviene que se lea así
#
# Decisión de Daniel, 14 de agosto de 2026:
#
# > *"Por ahora que conviva la misma base de datos, la misma tabla user, con
# > diferentes roles… y que puedan tener estos desarrolladores acceso total por
# > ahora. Ya más adelante, cuando vaya incrementándose la demanda, planificamos
# > la migración y la exclusión de este tipo de usuarios del sistema."*
#
# La razón es buena: para responderle a un colegio hay que poder ver lo que él
# ve, en el momento, y hoy la demanda no justifica una plataforma aparte.
#
# ⚠️ **Pero es exactamente el vector que describe `MOR-92`**, que sigue abierto a
# propósito: una credencial que atraviesa el aislamiento por diseño es la forma
# del incidente de Canvas. No hizo falta vulnerar nada; alcanzó con usar la
# cuenta que legítimamente lo cruzaba.
#
# Lo que se hace mientras tanto, que no cuesta nada y sirve para el día que haya
# que explicarlo:
#
#   1. **Hay que elegir el colegio explícitamente.** Tener el rol no mete a
#      nadie en ningún lado: la sesión arranca sin colegio.
#   2. **Queda registrado en el historial DEL COLEGIO**, así que el colegio lo ve.
#   3. **Se ve en pantalla, imposible de ignorar**, mientras dura.
#
# No es `MOR-92` —no hay motivo declarado, ni vencimiento, ni concesión— pero
# deja el rastro que convierte esto en algo defendible frente a un cliente, y el
# camino de migración cuando toque cerrarlo.
module AccesoDelEquipoDeSiga
  extend ActiveSupport::Concern

  included do
    helper_method :equipo_de_siga?, :colegio_visitado, :visitando_un_colegio?
  end

  private

  def equipo_de_siga?
    return @equipo_de_siga if defined?(@equipo_de_siga)

    @equipo_de_siga = current_user.present? && SigaStaff.para(current_user).present?
  end

  # El colegio que el equipo de SIGA eligió visitar, si eligió alguno.
  #
  # ⚠️ La sesión SELECCIONA, no concede: el `equipo_de_siga?` de adelante es lo
  # que decide. Meter un `colegio_visitado_id` en la cookie sin ser del equipo no
  # hace absolutamente nada — la misma regla que el selector de colegio del
  # portal de representantes (`MOR-110`).
  def colegio_visitado
    return nil unless equipo_de_siga?
    return @colegio_visitado if defined?(@colegio_visitado)

    @colegio_visitado =
      if session[:colegio_visitado_id].present?
        Current.sin_aislamiento { School.find_by(id: session[:colegio_visitado_id]) }
      end
  end

  def visitando_un_colegio? = colegio_visitado.present?
end
