module ApplicationHelper
  include Pagy::Frontend

  # Los métodos de rol y autorización están definidos en ApplicationController
  # y expuestos a las vistas vía helper_method
end
