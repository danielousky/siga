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

  # ⚠️ Los de sistema van APARTE porque `bin/rails test` NO los corre, y un test
  # que nadie corre no protege nada.
  #
  # Es el único paso que abre un navegador de verdad, y por eso es el único que
  # puede ver un problema de LAYOUT. El desborde de MOR-194 —la página entera
  # corrida 189 px de lado en un teléfono, en las dieciocho pantallas— vivió
  # desde MOR-184 sin que nada lo notara: el HTML era correcto, todos los tests
  # estaban en verde, y lo que fallaba era una regla de CSS apuntando a una
  # clase que había dejado de existir.
  #
  # Cuesta unos segundos y necesita Chrome. Vale la pena: la mitad de los
  # usuarios de SIGA —los profesores cargando notas— entran desde el teléfono.
  step "Teléfono: ninguna pantalla se corre de lado", "bin/rails test:system"

  # Los seeds no son datos de adorno: son los casos de QA que hacen visible cada
  # regla del Reglamento (MOR-93). Si dejan de correr, se pierde la única forma
  # de VER lo que se construyó.
  #
  # ⚠️ El `db:test:prepare` del final NO es decorativo. Sin él, este paso deja la
  # base de test con 290 alumnos y 4 admins COMMITEADOS, y el siguiente
  # `bin/rails test` explota al cargar las fixtures:
  #
  #   PG::ForeignKeyViolation: update or delete on table "users" violates
  #   foreign key constraint on table "admins"
  #
  # Rails borra y reinserta las fixtures al arrancar, y para eso desactiva la
  # integridad referencial… lo cual **exige SUPERUSER**, que el rol de la app
  # deliberadamente no tiene (MOR-87). Así que el borrado respeta las FK y falla.
  #
  # Lo peor era el síntoma: `bin/ci` quedaba en verde y el que reventaba era el
  # `bin/rails test` de después. Purgando acá, el orden deja de importar.
  step "Seeds: siguen cargando de punta a punta",
       "env RAILS_ENV=test bin/rails db:seed:replant db:test:prepare"

  # La suite no toca HTTP real: no atrapa una vista con un error de Haml, un
  # `pagy_nav` sin `@pagy`, ni una traducción faltante. `bin/smoke` recorre la app
  # por HTTP con los cuatro roles y mira el log del server buscando excepciones,
  # deprecaciones y "Translation missing".
  #
  # ⚠️ Levanta las DOS piezas de producción, web y worker, y es lo único de este
  # pipeline que prueba que el worker arranca: exige que la cola quede vacía y
  # que nada haya fallado al procesarse. Con el web solo, el paso dependía de
  # cuánto llevara esperando lo que hubiera en la cola — y en GitHub, donde los
  # seeds dejan dos trabajos doce minutos antes, fallaba siempre.
  step "Humo: la app responde por HTTP en los cuatro roles", "bin/smoke ci"
end
