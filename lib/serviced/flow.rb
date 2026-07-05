# frozen_string_literal: true

module Serviced
  # Composes several steps into a single callable pipeline.
  #
  # A step is anything that responds to +call(context)+ and returns a
  # {Serviced::Result}: usually a {Serviced::Service} subclass, but a lambda or
  # any callable works too. Steps run in order, each receiving an immutable
  # context hash. The first failing step halts the flow and its failure is
  # returned. When every step succeeds, whatever hash each step returned as its
  # success value is merged into the context, and the final context is returned
  # as the success value.
  #
  #   class RegisterPatient < Serviced::Flow
  #     transactional # wrap every step in one database transaction
  #
  #     step CreatePatient   # returns success(patient: patient)
  #     step CreateChart     # reads :patient from the context
  #     step SendWelcome
  #   end
  #
  #   result = RegisterPatient.call(name: "Ada", age: 36)
  #   result.value # => merged context hash of everything the steps produced
  #
  # A flow can also be built inline:
  #
  #   RegisterPatient = Serviced::Flow.define(transaction: true) do
  #     step CreatePatient
  #     step CreateChart
  #   end
  class Flow
    include ResultHelpers

    @steps = []
    @transactional = false

    class << self
      # @return [Array<#call>] the steps registered on this flow
      def steps
        @steps ||= []
      end

      # Registers a step. Steps run in the order they are declared.
      # @param callable [#call] a Service subclass, lambda, or any callable
      #   that returns a Serviced::Result
      def step(callable)
        steps << callable
      end

      # Marks the flow as transactional: all steps run inside a single
      # transaction that rolls back if any step fails or raises.
      def transactional
        @transactional = true
      end

      # @return [Boolean] whether the flow runs inside a transaction
      def transactional?
        @transactional
      end

      # Builds an anonymous flow subclass from a block.
      # @param transaction [Boolean] whether to wrap the steps in a transaction
      # @return [Class] a new Serviced::Flow subclass
      def define(transaction: false, &block)
        Class.new(self) do
          transactional if transaction
          class_eval(&block) if block
        end
      end

      # Runs the flow.
      # @param context [Hash] initial context
      # @return [Serviced::Result]
      def call(context = {})
        new(context).call
      end

      private

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@steps, steps.dup)
        subclass.instance_variable_set(:@transactional, transactional?)
      end
    end

    # @param context [Hash] initial context passed to the first step
    def initialize(context = {})
      @context = normalize(context).freeze
    end

    # @return [Serviced::Result]
    def call
      self.class.transactional? ? within_transaction { run_steps } : run_steps
    end

    private

    def run_steps
      context = @context
      self.class.steps.each do |step|
        result = invoke(step, context)
        return result if result.failure?

        context = merge(context, result.value)
      end

      success(context)
    end

    def invoke(step, context)
      result = step.call(context)
      return result if result.is_a?(Result)

      raise ResultTypeError,
            "Flow step #{step_name(step)} must return a Serviced::Result, got #{result.class}"
    end

    def within_transaction
      handler = Serviced.configuration.transaction_handler
      if handler.nil?
        raise MissingTransactionHandler,
              "#{self.class} is transactional but no transaction handler is configured. " \
              "Load ActiveRecord or set Serviced.configuration.transaction_handler."
      end

      result = nil
      begin
        handler.call do
          result = yield
          raise Rollback if result.failure?
        end
      rescue Rollback
        # Expected: a step failed, the transaction rolled back, and +result+
        # already holds that failure.
      end
      result
    end

    def merge(context, value)
      return context unless value.is_a?(Hash)

      context.merge(normalize(value)).freeze
    end

    def normalize(hash)
      (hash || {}).to_h.transform_keys(&:to_sym)
    end

    def step_name(step)
      step.respond_to?(:name) ? step.name : step.class.name
    end
  end
end
