# frozen_string_literal: true

require "active_support/concern"
require "active_model"

module Serviced
  # Shared foundation for typed, immutable, validatable inputs. Included by both
  # {Serviced::Service} and {Serviced::Query}, and usable on its own for any
  # plain value object that wants the same contract.
  #
  #   class DateRange
  #     include Serviced::Typed
  #     attribute :from, :date
  #     attribute :to,   :date
  #     validates :from, :to, presence: true
  #   end
  #
  # Attributes are declared with the ActiveModel::Attributes DSL, so they are
  # coerced to the declared type. Their writers are made private, so an instance
  # cannot be rebound once built. Unknown keys are ignored, which lets these
  # objects be fed from a wider hash (for example a {Serviced::Flow} context)
  # without raising.
  #
  # Inputs are isolated by default: at construction each value is captured as an
  # immutable snapshot (see {Serviced.snapshot}). Arrays, hashes, sets and
  # strings are deep-copied and deep-frozen, so neither side can mutate the
  # other. Objects with identity (ActiveRecord records and the like) are shared
  # by reference and left alone, because a deep copy of a record is a different,
  # non-persisted object. Pass +isolate: false+ to share a value by reference,
  # for example a mutable accumulator you deliberately want the caller to see:
  #
  #   attribute :filters             # isolated snapshot (default)
  #   attribute :sink, isolate: false # shared by reference
  module Typed
    extend ActiveSupport::Concern

    include ActiveModel::API
    include ActiveModel::Attributes

    # @param attributes [Hash] input values; unknown keys are ignored
    def initialize(attributes = {})
      super()
      assign_typed_attributes(attributes)
      capture_isolated_snapshots
    end

    private

    def assign_typed_attributes(attributes)
      return if attributes.nil?

      permitted = attributes.to_h.transform_keys(&:to_sym)
      self.class.attribute_names.each do |name|
        key = name.to_sym
        __send__(:"#{name}=", permitted[key]) if permitted.key?(key)
      end
    end

    # Forces each isolated attribute to snapshot its value now, so isolation
    # holds against mutations made between construction and first read.
    def capture_isolated_snapshots
      self.class.isolated_attribute_names.each { |name| __send__(name) }
    end

    class_methods do
      # @return [Array<String>] names of attributes captured as isolated snapshots
      def isolated_attribute_names
        @isolated_attribute_names ||=
          superclass.respond_to?(:isolated_attribute_names) ? superclass.isolated_attribute_names.dup : []
      end

      # Declares a typed, read-only attribute. Same arguments as
      # ActiveModel::Attributes.attribute, plus +isolate:+.
      #
      # @param name [Symbol] attribute name
      # @param type [Symbol, ActiveModel::Type::Value, Class, Module, nil] an
      #   ActiveModel type symbol/instance (the value is coerced), or a
      #   class/module (the value must be an instance of it: records, POROs,
      #   anything), or nil for an untyped pass-through
      # @param isolate [Boolean] capture an immutable snapshot of the value at
      #   construction (default); pass +false+ to share it by reference
      # @param options [Hash] forwarded to ActiveModel (e.g. +default:+)
      def attribute(name, type = nil, isolate: true, **options)
        klass = type if type.is_a?(Module)
        if type.nil? || klass
          super(name, **options)
        else
          super(name, type, **options)
        end
        private(:"#{name}=")
        validate_instance_of(name, klass) if klass
        return unless isolate

        isolated_attribute_names << name.to_s
        define_isolated_reader(name)
      end

      private

      def define_isolated_reader(name)
        define_method(name) do
          ivar = :"@__isolated_#{name}"
          return instance_variable_get(ivar) if instance_variable_defined?(ivar)

          instance_variable_set(ivar, Serviced.snapshot(super()))
        end
      end

      # Adds a validation that the attribute holds an instance of +klass+
      # (subclasses count). nil is allowed; require it with +presence: true+.
      def validate_instance_of(name, klass)
        validate do
          value = public_send(name)
          next if value.nil? || value.is_a?(klass)

          errors.add(name, "must be an instance of #{klass.name || klass.inspect}")
        end
      end
    end
  end
end
