frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

require "active_record"

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
