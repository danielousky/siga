class ApplicationJob < ActiveJob::Base
  # Todo job trabaja para un colegio, salvo que diga explícitamente lo contrario.
  # Ver `CarriesSchool` — y MOR-88.
  include CarriesSchool

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
