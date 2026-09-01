# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# ⚠️ Lo que NO es un controlador de Stimulus va acá.
#
# `lib/sin_acentos` es la mitad JavaScript de una regla que también vive en Ruby
# (`BusquedaSinAcentos`): comparar textos ignorando tildes. Sin este `pin`, el
# `import` desde un controlador falla EN SILENCIO en el navegador —el módulo no
# se resuelve y Stimulus no conecta— y el filtro deja de funcionar sin que
# ningún test del servidor se entere.
pin_all_from "app/javascript/lib", under: "lib"
