class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  include DerivesSchoolFrom
  include ValidatesSameSchool
end
