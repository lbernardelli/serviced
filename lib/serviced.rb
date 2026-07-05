# frozen_string_literal: true

require "set"

require_relative "serviced/version"
require_relative "serviced/errors"
require_relative "serviced/result"
require_relative "serviced/result_helpers"
require_relative "serviced/configuration"
require_relative "serviced/typed"
require_relative "serviced/service"
require_relative "serviced/query"
require_relative "serviced/flow"

# Serviced provides small, explicit service objects: typed and immutable
# inputs, a mandatory Success/Failure return value, and composable flows with
# optional transactions.
#
# See {Serviced::Service} and {Serviced::Flow}.
module Serviced
  class << self
    # @return [Serviced::Configuration] the current configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Yields the configuration for mutation.
    # @yieldparam config [Serviced::Configuration]
    def configure
      yield(configuration)
    end

    # Resets configuration to defaults. Primarily useful in test suites.
    # @return [Serviced::Configuration]
    def reset_configuration!
      @configuration = Configuration.new
    end

    # Renders an ActiveModel::Errors into a short human string. Falls back to
    # the attribute names when full messages cannot be built: an anonymous
    # class has no model_name, which ActiveModel needs to humanize messages.
    # Building an error message must never itself raise.
    # @param errors [ActiveModel::Errors]
    # @return [String]
    def error_summary(errors)
      errors.full_messages.join(", ")
    rescue StandardError
      errors.attribute_names.join(", ")
    end

    # Returns an immutable snapshot of a value-like input. Arrays, hashes, sets
    # and strings are deep-copied and frozen, so the result is isolated from the
    # caller and cannot be mutated. Objects with identity (ActiveRecord records
    # and other non-data objects) are returned by reference, unfrozen: a deep
    # copy of a record is a different, non-persisted object, and freezing one in
    # place would corrupt the caller's copy. Scalars are already immutable.
    # @param value [Object]
    # @return [Object] a frozen snapshot for value-like data, else the value itself
    def snapshot(value)
      case value
      when Array then value.map { |element| snapshot(element) }.freeze
      when Set then Set.new(value.map { |element| snapshot(element) }).freeze
      when Hash then snapshot_hash(value)
      when String then snapshot_string(value)
      else value
      end
    end

    private

    def snapshot_hash(hash)
      hash.each_with_object({}) { |(key, value), copy| copy[snapshot(key)] = snapshot(value) }.freeze
    end

    def snapshot_string(string)
      string.frozen? ? string : string.dup.freeze
    end
  end
end
