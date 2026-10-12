# La dirección del formulario de «pedir una demostración», que ya no existe.
#
# ## Por qué salió
#
# Spec `docs/specs/del-registro-al-cobro.md`, decisiones 1 y 19. Daniel, 8 de
# octubre de 2026: *«No está claramente definido si la puerta de entrada es una
# solicitud demo (en cuyo caso no lo tenemos) o un registro»*. Eran dos puertas a
# dos productos distintos: el formulario dejaba una fila en `/siga/solicitudes`
# que no le avisaba a nadie, y quien entraba por ahí terminaba dado de alta a
# mano y sin suscripción. La puerta es el registro; quien quiere ver antes, mira
# el colegio de muestra; quien quiere conversar, escribe por WhatsApp.
#
# ## Por qué el controlador se queda
#
# La dirección está en buscadores, en mensajes reenviados y en los marcadores de
# quien la guardó. Un 404 ahí es un prospecto perdido: lleva a la portada, que
# es donde están las tres puertas de ahora.
#
# ⚠️ Lo que NO se borró: el modelo `DemoRequest` y `/siga/solicitudes`. Las
# solicitudes que entraron son historia del equipo de SIGA, y siguen ahí.
class DemoRequestsController < ApplicationController
  skip_before_action :authenticate_user!

  # 301: se mudó para siempre, y un buscador tiene que pasarle a la portada lo
  # que esta dirección había juntado.
  def new = redirect_to(root_path, status: :moved_permanently)

  def success = redirect_to(root_path, status: :moved_permanently)

  # ⚠️ Un envío que llegue —de una pestaña que quedó abierta desde antes— NO
  # crea nada: nadie va a leer esa solicitud. Va a la portada, sin fingir que se
  # recibió. 303 y no 301: es la respuesta a un POST.
  def create = redirect_to(root_path, status: :see_other)
end
