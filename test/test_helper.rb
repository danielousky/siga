ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].each { |archivo| require archivo }

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Constructores de escenarios — ver test/support/.
  include EscenarioAcademico
  include DosColegios

  # ⚠️ `assert_select ".clase", "texto"` — el segundo argumento es el TEXTO
  # ESPERADO, no un mensaje de fallo.
  #
  # Es el error más repetido de esta suite: se escribe pensando en `assert_x,
  # mensaje` y el test pasa a exigir que el elemento diga literalmente esa
  # explicación. Con `count:` delante, además, ni compila —«expected a value in
  # the hash literal»— porque Ruby lee el mensaje como una clave más.
  #
  # La explicación va en un COMENTARIO arriba de la aserción.
  include PlanesDeEvaluacion

  teardown { Current.reset }
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
