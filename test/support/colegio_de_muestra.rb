# Lo que hace falta para probar el colegio de muestra (`Muestra`, spec
# `docs/specs/del-registro-al-cobro.md`, § 4.3).
#
# La muestra es una INSTANCIA, no un dato: se declara con una variable de
# entorno. Así que un test la «enciende» mientras dura un bloque y convierte un
# colegio de prueba en el de la muestra —su código DEA y los correos de sus
# puertas—.
module ColegioDeMuestra
  # La instancia, declarada muestra mientras dura el bloque.
  #
  # ⚠️ Se devuelve como estaba aunque el test falle: la variable es del proceso
  # entero, y una muestra que quedara encendida cambiaría la portada, el correo
  # y el registro de todos los tests que corran después.
  def en_la_muestra
    anterior = ENV[Muestra::VARIABLE]
    ENV[Muestra::VARIABLE] = "1"
    yield
  ensure
    ENV[Muestra::VARIABLE] = anterior
  end

  # Convierte un colegio de prueba en EL colegio de muestra: su código DEA es el
  # de `Muestra`, y su director y su profesor llevan los correos de las puertas.
  #
  # `vecino` es el segundo colegio, el que existe para que el aislamiento se vea.
  def montar_la_muestra(completo, vecino = nil)
    Current.sin_aislamiento do
      completo.colegio.update_columns(dea_code: Muestra::COLEGIO)
      completo.director.update_columns(email: Muestra.cuenta("director").correo)
      completo.profesor.update_columns(email: Muestra.cuenta("profesor").correo)
      vecino&.colegio&.update_columns(dea_code: Muestra::VECINO)
    end
    completo
  end
end
