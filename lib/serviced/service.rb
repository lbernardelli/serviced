# frozen_string_literal: true

module Serviced
  # Base class for service objects.
  #
  # A service declares its inputs as typed attributes (see {Serviced::Typed}),
  # which are coerced on assignment and read-only afterwards. Inputs can be
  # validated with the full ActiveModel validation DSL. Calling a service always
  # returns a {Serviced::Result}.
  #
  #   class CreatePatient < Serviced::Service
  #     attribute :name,   :string
  #     attribute :age,    :integer
  #     attribute :active, :boolean, default: true
  #     attribute :clinic # untyped: accepts any object
  #
  #     validates :name, presence: true
  #     validates :age, numericality: { greater_than: 0 }
  #
  #     def call
  #       patient = Patient.create!(name:, age:, active:)
  #       success(patient)
  #     rescue ActiveRecord::RecordInvalid => e
  #       failure(:not_created, e.message, error: e)
  #     end
  #   end
  #
  #   result = CreatePatient.call(name: "Ada", age: 36)
  #   result.success? # => true
  #   result.value    # => #<Patient ...>
  #
  # Invalid inputs short-circuit to +failure(:invalid)+ without running #call,
  # exposing the ActiveModel::Errors object through +result.error+.
  class Service
    include Typed
    include ResultHelpers

    class << self
      # Builds the service, validates it, and runs #call.
      #
      # Unknown keys are ignored so a service can be dropped into a {Flow}
      # without matching the exact shape of the flow context.
      #
      # @param attributes [Hash] input values
      # @return [Serviced::Result]
      # @raise [Serviced::ResultTypeError] if #call returns a non-Result
      def call(attributes = {})
        service = new(attributes)
        return service.__send__(:invalid_result) if service.invalid?

        result = service.call
        unless result.is_a?(Result)
          raise ResultTypeError, "#{self}#call must return a Serviced::Result, got #{result.class}"
        end

        result
      end
    end

    # The business logic. Subclasses must implement it and return a
    # {Serviced::Result} (use the +success+ / +failure+ helpers).
    # @return [Serviced::Result]
    def call
      raise NotImplementedError, "#{self.class} must implement #call"
    end

    private

    def invalid_result
      failure(:invalid, "Validation failed: #{Serviced.error_summary(errors)}", error: errors)
    end
  end
end
