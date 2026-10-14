# Las formas de tutear que NO se confunden con la tercera persona.
#
# SIGA le habla de usted a quien la usa (13 de octubre de 2026), y lo cuidan
# `la_app_habla_de_usted_test` —las pantallas, los mensajes, las traducciones y
# el manual— y `documentos_comerciales_test` —el contrato y lo que se le entrega
# a un colegio o a un aliado—. «Toca al hijo» puede ser «la madre toca»: esas no
# las puede juzgar una expresión regular, y por eso no están en la lista.
module Tuteo
  PATRON = /
    \b(?:tú|tu|tus|te|ti|contigo|tuyo|tuya|tuyos|tuyas)\b
    | \b(?:tienes|puedes|quieres|debes|estás|eres|vas|haces|sabes|necesitas|hayas|podrás|tendrás|verás|
           recibirás|puedas|tengas|estés|seas|dictas|escribes|crees|imaginas|digas|elegiste|escribiste|
           olvidaste|marcaste|entraste|iniciaste|copiaste|dictaste|has\ (?:iniciado|sido|llegado|actualizado))\b
    | \b(?:pídele|escríbenos|comunícate|regístrate|asegúrate|fíjate|notificarte|avisarte|contactarte|
           ayudarte|verte|dime|dinos)\b
    | (?:^\s*|[.:¿¡"'>«]\s*|%[\w.\#-]+\s+)(?:Elige|Revisa|Agrega|Contacta|Recuerda|Escoge|Selecciona|Ingresa|Introduce|Verifica)\b
  /xi
end
