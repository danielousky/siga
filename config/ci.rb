# El pipeline de verificación. Se corre con `bin/ci`.
#
# Es UNA sola definición: la misma que corre en la máquina de desarrollo antes de
# subir algo y la que corre en GitHub Actions. Un CI que verifica cosas distintas
# de las que uno puede correr en su máquina se vuelve un oráculo: falla y hay que
# adivinar por qué.
#
# El orden es a propósito: primero lo que falla rápido y explica más.
#
# Ver MOR-105.
CI.run do
  # ⚠️ Va PRIMERO, y no es ceremonia.
  #
  # Si el rol de la base es superusuario o tiene BYPASSRLS, PostgreSQL se salta
  # las políticas de RLS antes de mirarlas: el aislamiento entre colegios deja de
  # existir y NADA MÁS EN ESTE PIPELINE SE DARÍA CUENTA. Los tests seguirían en
  # verde, porque el `default_scope` de la app filtra igual.
  #
  # Pasó exactamente eso durante el desarrollo (MOR-87): políticas creadas, FORCE
  # encendido, y una consulta cruda devolviendo los 290 alumnos de los dos
  # colegios. Este paso es la única cosa del pipeline que lo detecta.
  step "Aislamiento: el rol de la base no puede saltarse el RLS", "bin/rails rls:verificar"

  step "Seguridad: auditoría de dependencias de importmap", "bin/importmap audit"

  # Adoptado con una sola regla apagada y otra ajustada — ver `.rubocop.yml`.
  # Sin eso arrancaba con 398 infracciones, de las cuales 367 eran una preferencia
  # cosmética sobre los corchetes. Un linter que grita 400 veces el primer día no
  # se lee: se apaga.
  step "Estilo", "bundle exec rubocop --format simple"

  step "Tests", "bin/rails test"

  # Los seeds no son datos de adorno: son los casos de QA que hacen visible cada
  # regla del Reglamento (MOR-93). Si dejan de correr, se pierde la única forma
  # de VER lo que se construyó.
  step "Seeds: siguen cargando de punta a punta", "env RAILS_ENV=test bin/rails db:seed:replant"

  # La suite no toca HTTP real: no atrapa una vista con un error de Haml, un
  # `pagy_nav` sin `@pagy`, ni una traducción faltante. `bin/smoke` recorre la app
  # por HTTP con los cuatro roles y mira el log del server buscando excepciones,
  # deprecaciones y "Translation missing".
  step "Humo: la app responde por HTTP en los cuatro roles", "bin/smoke ci"
end
