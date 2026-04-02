class EnseigneOpeningHour < ApplicationRecord
  include OpeningHourValidations

  opening_hour_parent :enseigne
end
