# frozen_string_literal: true

module Serviced
  # Outcome of a service or flow. Abstract: instances are always either a
  # {Serviced::Success} or a {Serviced::Failure}. Results are frozen and
  # therefore immutable.
  #
  # Consume a result through predicates, callbacks, railway chaining, or
  # pattern matching:
  #
  #   result = CreatePatient.call(name: "Ada", age: 36)
  #
  #   result.success?                 # => true / false
  #   result.value                    # success payload (nil on failure)
  #
  #   result
  #     .on_success { |patient| render json: patient }
  #     .on_failure { |failure| render json: { error: failure.message } }
  #
  #   case result
  #   in Serviced::Success(value:)      then value
  #   in Serviced::Failure(reason:)     then reason
  #   end
  class Result
    # @return [Boolean] whether the operation succeeded.
    def success?
      raise NotImplementedError, "#{self.class} must implement #success?"
    end

    # @return [Boolean] whether the operation failed.
    def failure?
      !success?
    end

    # The success payload. Always nil for a failure.
    # @return [Object, nil]
    def value
      nil
    end

    # Runs the block with the success value when successful. Returns self so
    # calls can be chained with {#on_failure}.
    # @yieldparam value [Object] the success payload
    # @return [Serviced::Result] self
    def on_success
      yield(value) if success? && block_given?
      self
    end

    # Runs the block with the failure when failed. Returns self so calls can be
    # chained with {#on_success}.
    # @yieldparam failure [Serviced::Failure] the failure itself
    # @return [Serviced::Result] self
    def on_failure
      yield(self) if failure? && block_given?
      self
    end

    # Railway-oriented chaining: runs the block only on success and returns the
    # Result it produces; short-circuits (returns self) on failure. The block
    # must return a Serviced::Result.
    # @yieldparam value [Object] the success payload
    # @return [Serviced::Result]
    def and_then
      return self unless success?

      result = yield(value)
      unless result.is_a?(Result)
        raise ResultTypeError, "#and_then block must return a Serviced::Result, got #{result.class}"
      end

      result
    end

    # Transforms a success value into a new Success; leaves a failure untouched.
    # @yieldparam value [Object] the success payload
    # @return [Serviced::Result]
    def map
      return self unless success?

      Success.new(yield(value))
    end
  end

  # A successful outcome carrying a payload.
  class Success < Result
    # @return [Object, nil] the success payload
    attr_reader :value

    # @param value [Object, nil] the payload the caller cares about
    def initialize(value = nil)
      super()
      @value = value
      freeze
    end

    def success?
      true
    end

    # @return [Object, nil] the payload (never raises for a success)
    def value!
      value
    end

    def deconstruct
      [value]
    end

    def deconstruct_keys(_keys)
      { value: value }
    end
  end

  # A failed outcome. Carries a machine-readable +reason+ for branching, an
  # optional human-readable +message+, and an optional +error+ payload (for
  # example an exception or an ActiveModel::Errors object).
  class Failure < Result
    # @return [Symbol] machine-readable reason, suitable for case/when branching
    attr_reader :reason

    # @return [String, nil] human-readable description
    attr_reader :message

    # @return [Object, nil] structured error payload (exception, error object, details)
    attr_reader :error

    # @param reason [Symbol] machine-readable reason (defaults to :error)
    # @param message [String, nil] human-readable description
    # @param error [Object, nil] structured error payload
    def initialize(reason = :error, message = nil, error: nil)
      super()
      @reason = reason
      @message = message
      @error = error
      freeze
    end

    def success?
      false
    end

    # Always raises: a failure has no value to unwrap.
    # @raise [Serviced::InvalidResultAccess]
    def value!
      raise InvalidResultAccess,
            "Called #value! on a Failure (reason: #{reason.inspect}, message: #{message.inspect})"
    end

    def deconstruct
      [reason, message]
    end

    def deconstruct_keys(_keys)
      { reason: reason, message: message, error: error }
    end
  end
end
