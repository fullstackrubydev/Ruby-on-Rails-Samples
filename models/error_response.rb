class ErrorResponse < ActiveModelSerializers::Model

  attr_accessor  :code, :message, :errors, :isLastAttempt, :isBlocked, :diplayNameSuggestions, :data, :isValid, :isDeleted

end
