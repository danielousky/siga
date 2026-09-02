# La vista previa del correo de bienvenida (MOR-206).
#
# Se mira en `/rails/mailers/bienvenida_mailer/cuenta_creada` con el servidor de
# desarrollo. ⚠️ Existe porque un correo NO se revisa leyendo su HTML: hay que
# verlo, y sobre todo verlo angosto — la mitad de los directores lo va a abrir
# desde el teléfono.
class BienvenidaMailerPreview < ActionMailer::Preview
  def cuenta_creada
    BienvenidaMailer.cuenta_creada(
      User.new(first_name: "YOLEIMA", last_name: "CONTRERAS",
               email: "yoleima@sucolegio.edu")
    )
  end
end
