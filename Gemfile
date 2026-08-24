source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.9"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.0"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Authentication with Devise [https://github.com/heartcombo/devise]
gem "devise"

# Haml templates for Rails [https://github.com/haml/haml-rails]
gem "haml-rails"

# Pagination [https://github.com/ddnexus/pagy]
gem "pagy"

# La cola de trabajos, respaldada por la MISMA base de PostgreSQL.
#
# Hasta acá el adaptador era `:async`, que guarda la cola **en memoria del
# proceso web**: un reinicio —un deploy, un `systemctl restart`, un OOM— se
# lleva lo encolado sin dejar rastro. El único job que hay hoy recalcula los
# promedios de una sección entera cuando cambia una ponderación, así que
#
#     profesor cambia un peso  →  job encolado  →  deploy  →  job perdido
#                              →  los 30 alumnos quedan con el promedio viejo
#
# y nadie se entera hasta que alguien mira. `bin/rails notas:recalcular` repara,
# pero hay que acordarse de correrlo.
#
# Solid Queue es el adaptador por defecto de Rails 8 y **no agrega
# infraestructura**: sus tablas viven en el mismo PostgreSQL que ya existe. No
# hay Redis que instalar, monitorear ni pagar — que en un producto de 25 $ al
# mes no es un detalle.
gem "solid_queue", "~> 1.6"

# Traducciones de Rails y Active Record al español. Sin esto, cualquier error de
# validación se muestra como "Translation missing" — la app no traía es.yml.
gem "rails-i18n"

# Use Redis adapter to run Action Cable in production
# gem "redis", "~> 4.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Sass to process CSS
# gem "sassc-rails"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Boletines en PDF (MOR-98). Prawn genera el PDF en Ruby puro: no necesita ningún
# binario del sistema.
#
# Es la razón por la que se eligió sobre las alternativas. `wicked_pdf` y
# `pdfkit` dependen de `wkhtmltopdf`, que sus propios autores archivaron; `grover`
# necesita Node y Chromium, y esta app usa importmap justamente para no tener
# Node. Y sobre todo: **el entorno de despliegue todavía no está decidido**, así
# que atarlo a un binario del sistema sería tomar esa decisión de costado.
# El código QR del boletín: `rqrcode_core` es SOLO el algoritmo —devuelve la
# matriz de módulos— sin ninguna dependencia de imagen. Los cuadraditos se
# dibujan como vectores con Prawn, que imprime más nítido que un PNG rasterizado
# y no arrastra `chunky_png` ni `image_processing` a un PDF.
gem "rqrcode_core", "~> 2.1"

gem "prawn", "~> 2.5"
gem "prawn-table", "~> 0.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

group :development, :test do
  gem "rubocop-rails-omakase", require: false
end

# Leer la planilla que trae el colegio (MOR-126).
#
# `roo` da UNA sola interfaz para xlsx, csv y ods; `roo-xls` le suma el .xls de
# Excel 97-2003, que no es opcional acá: el sistema que usan hoy la mayoría de
# los colegios venezolanos es de escritorio y con 25 años encima, así que lo que
# exporta es .xls, no .xlsx.
#
# Se descartó `creek` —más liviano en memoria— porque su último release es de
# 2023 y acá una planilla son 360 filas, no 400.000.
gem "roo", "~> 3.0"
gem "roo-xls", "~> 2.0"

# Escribir planillas: la plantilla que el colegio descarga para llenar, y el
# reporte de lo que quedó fuera de una importación. Los dos son criterio de
# aceptación de MOR-126, y además es lo que deja probar el lector contra un
# .xlsx de verdad y no solo contra CSV.
gem "caxlsx", "~> 4.5"
