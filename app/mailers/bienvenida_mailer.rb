# El correo que recibe quien acaba de abrir su cuenta (MOR-196).
#
# Daniel: *«hay que enviarle un correo cuando se registren, eso no lo tenemos
# configurado»*. Y no lo estaba: el único correo del registro era
# `PlataformaMailer#colegio_registrado`, que va a SIGA para avisarnos a
# NOSOTROS. La persona que se registraba no recibía nada.
#
# ## Qué hace, además de saludar
#
# **Confirma que la dirección existe.** Es el único momento en que se puede
# comprobar sin costo: si el correo rebota, esa cuenta no va a poder recuperar
# su contraseña nunca — y desde `MOR-158` el registro es abierto, así que un
# dedazo en el correo es la forma más probable de perder una cuenta.
#
# **Y deja el enlace de entrada en su bandeja**, que es donde lo va a buscar en
# septiembre cuando vuelva a abrir SIGA después de tres semanas.
#
# ⚠️ NO lleva contraseña ni código: la persona acaba de elegir la suya y está
# con la sesión abierta. Un correo con credenciales adentro es exactamente lo
# que no hay que mandar.
class BienvenidaMailer < ApplicationMailer
  # ⚠️ Es de SIGA, no de un colegio: quien se registra todavía no tiene el suyo
  # armado. Por eso no llama `a_nombre_de`, y sale con la cabecera de la
  # plataforma. (Tuvo plantilla propia, `mailer_siga`, mientras la común estuvo
  # vacía; desde el 5 de octubre de 2026 hay una sola.)
  def cuenta_creada(usuario)
    @usuario = usuario
    @url     = root_url

    # Daniel: *«Bienvenido a SIGA: Sistema de Gestión Académica…»*. El nombre
    # completo va en el asunto y no en el cuerpo porque es la única línea que se
    # lee en la bandeja: quien se registró hace un minuto puede no acordarse de
    # qué es «SIGA».
    mail to: usuario.email, subject: "Bienvenido a SIGA · Sistema Integrado de Gestión Académica"
  end
end
