require "distributed_make/base"

module DistributedMake
  # Represents the basis of a Makefile rule or dependency.
  class RuleStub
    # @return [String] name of this rule
    attr_reader :name

    # @param [String] target the target name for this rule.
    def initialize(target)
      @name = target

      @done = false
      @processing = false
    end

    # Returns a value indicating if this rule is complete.
    #
    # @return [Bool] <tt>true</tt> if this rule is complete, <tt>false</tt> otherwise.
    def done?
      @done
    end

    # Sets a value indicating if this rule is complete.
    #
    # @param [Bool] value <tt>true</tt> if this rule is complete, <tt>false</tt> otherwise.
    def done=(value)
      @done = value
    end

    # Returns a value indicating if this rule is being processed.
    #
    # @return [Bool] <tt>true</tt> if this rule is being processed, <tt>false</tt> otherwise.
    def processing?
      @processing
    end

    # Sets a value indicating if this rule is being processed.
    #
    # @param [Bool] value <tt>true</tt> if this rule is being processed, <tt>false</tt> otherwise.
    def processing=(value)
      @processing = value
    end

    # Converts this rule stub into a hash for inspection.
    #
    # @return [Hash] A hash representing the object with the following attributes:
    #   * [String] <tt>:name</tt> the target name for this rule.
    def to_h
      {
        :name => @name
      }
    end

    # Return a value indicating if this rule is a stub
    #
    # @return [Bool] <tt>true</tt> if this rule is a stub, <tt>false</tt> otherwise.
    def is_stub?
      true
    end

    # Returns a string representing this rule stub.
    #
    # @return [String] String representing the rule.
    def to_s
      "(stub) #{@name}"
    end
  end
end
