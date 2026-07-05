# frozen_string_literal: true

module Serviced
  # Private helpers shared by services and flows for building results, so the
  # construction of Success/Failure lives in one place.
  module ResultHelpers
    private

    # Builds a success result. Pass a hash to contribute keys to a flow context,
    # for example +success(patient: patient)+.
    # @param value [Object, nil] the payload
    # @return [Serviced::Success]
    def success(value = nil)
      Success.new(value)
    end

    # Builds a failure result.
    # @param reason [Symbol] machine-readable reason for branching
    # @param message [String, nil] human-readable description
    # @param error [Object, nil] structured error payload
    # @return [Serviced::Failure]
    def failure(reason = :error, message = nil, error: nil)
      Failure.new(reason, message, error: error)
    end
  end
end
