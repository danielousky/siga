# Los correos de la CUENTA: recuperar la contraseña, y avisar que cambió.
#
# Son los de Devise. Existe esta clase —y no alcanza con `Devise::Mailer`— por
# una sola razón: decir de quién es el correo antes de armarlo.
#
# ## Del colegio, si la persona es de uno solo
#
# Decisión de Daniel, 5 de octubre de 2026. La cuenta es de la plataforma, pero
# una mamá no piensa en «mi cuenta de SIGA»: piensa en el sistema del colegio de
# su hija. Si no hay duda de cuál es, el correo sale con su escudo.
#
#     de UN colegio                  →  cabecera y pie del colegio
#     de dos, o de ninguno           →  de SIGA
#     (hijos en dos colegios · el equipo de SIGA · una cuenta recién creada)
#
# ⚠️ Quien pide recuperar su contraseña NO tiene sesión. Por eso el colegio no
# sale de `Current.school` —que está vacío— sino de `User#unico_colegio`.
class CuentaMailer < Devise::Mailer
  # Las plantillas siguen en `devise/mailer/`, que es donde Devise las busca.
  default template_path: "devise/mailer"

  def reset_password_instructions(persona, token, opciones = {})
    a_nombre_de(persona.unico_colegio)
    super
  end

  def password_change(persona, opciones = {})
    a_nombre_de(persona.unico_colegio)
    super
  end

  private

  # ⚠️ El canal de ElasticEmail conserva su nombre: `siga-devise-…`.
  #
  # Se arma del nombre de la clase, así que al pasar de `Devise::Mailer` a
  # `CuentaMailer` quedaría `siga-cuenta-…` — y las estadísticas del correo más
  # frecuente de la app se partirían en dos, con la mitad vieja congelada.
  def familia_del_canal = "devise"
end
