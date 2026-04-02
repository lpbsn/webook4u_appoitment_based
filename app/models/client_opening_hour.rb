class ClientOpeningHour < ApplicationRecord
  include OpeningHourValidations

  opening_hour_parent :client
end
