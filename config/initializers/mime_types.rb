# ⚠️ Rails NO conoce `xlsx` de fábrica.
#
# Sin esto, `/secciones/12/alumnos.xlsx` devuelve **406 Not Acceptable** y
# `respond_to { |f| f.xlsx }` ni siquiera compila — `Mime[:xlsx]` es `nil`.
#
# El tipo largo es el de OOXML y es el que hace que el navegador ofrezca
# «Guardar» en vez de intentar mostrar el binario, y que Excel lo abra al
# doble clic en vez de preguntar con qué programa.
Mime::Type.register "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", :xlsx
