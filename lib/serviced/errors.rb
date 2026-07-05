# frozen_string_literal: true

module Serviced
  # Base class for every error raised by Serviced.
  class Error < StandardError; end

  # Raised when a service or flow step returns something other than a
  # Serviced::Result from its #call method.
  class ResultTypeError < Error; end

  # Raised when reading the value of a failure (or otherwise accessing a
  # result in a way its status does not allow).
  class InvalidResultAccess < Error; end

  # Raised when a {Serviced::Query} is called with inputs that fail its
  # validations. Unlike a service (which returns a Failure), a query has no
  # result channel, so invalid input is treated as a programming error.
  class InvalidQuery < Error
    # @return [ActiveModel::Errors] the validation errors
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super("Invalid query input: #{Serviced.error_summary(errors)}")
    end
  end

  # Raised when a transactional flow runs but no transaction handler is
  # configured (for example, ActiveRecord is not loaded and nothing was set
  # through Serviced.configure).
  class MissingTransactionHandler < Error; end

  # Internal signal raised inside a transactional flow to force the underlying
  # transaction to roll back. It never escapes the flow and is not part of the
  # public API.
  class Rollback < Error; end
end
