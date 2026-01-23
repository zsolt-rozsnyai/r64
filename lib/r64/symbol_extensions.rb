# Symbol extensions for R64 assembler label arithmetic
#
# frozen_string_literal: true

# Extensions to Ruby's Symbol class to support arithmetic operations on assembly labels.
#
# This module extends the Symbol class to automatically resolve assembly labels
# and perform arithmetic operations on their addresses. This allows for natural
# syntax when working with labels in assembly code.
#
# @example Basic usage
#   # In assembly code:
#   label :buffer_start
#   lda :buffer_start + 1  # Resolves to buffer address + 1
#
# @see R64::Assembler For the assembler context that provides label resolution

# Error raised when a symbol cannot be resolved as an assembly label
class LabelResolutionError < StandardError; end

class Symbol
  # Addition operation with automatic label resolution
  #
  # @param other [Integer] The value to add to the resolved label address
  # @return [Integer] The result of the addition
  # @raise [LabelResolutionError] If no assembler context is available or label doesn't exist
  def +(other)
    begin
      resolve_label_arithmetic(:+, other)
    rescue LabelResolutionError
      # This symbol is not an assembly label, raise appropriate error
      raise NoMethodError, "undefined method `+' for :#{self}:Symbol"
    end
  end

  # Subtraction operation with automatic label resolution
  #
  # @param other [Integer] The value to subtract from the resolved label address
  # @return [Integer] The result of the subtraction
  # @raise [LabelResolutionError] If no assembler context is available or label doesn't exist
  def -(other)
    begin
      resolve_label_arithmetic(:-, other)
    rescue LabelResolutionError
      # This symbol is not an assembly label, raise appropriate error
      raise NoMethodError, "undefined method `-' for :#{self}:Symbol"
    end
  end

  # Multiplication operation with automatic label resolution
  #
  # @param other [Integer] The value to multiply with the resolved label address
  # @return [Integer] The result of the multiplication
  # @raise [LabelResolutionError] If no assembler context is available or label doesn't exist
  def *(other)
    begin
      resolve_label_arithmetic(:*, other)
    rescue LabelResolutionError
      # This symbol is not an assembly label, raise appropriate error
      raise NoMethodError, "undefined method `*' for :#{self}:Symbol"
    end
  end

  # Division operation with automatic label resolution
  #
  # @param other [Integer] The value to divide the resolved label address by
  # @return [Integer] The result of the division
  # @raise [LabelResolutionError] If no assembler context is available or label doesn't exist
  def /(other)
    begin
      resolve_label_arithmetic(:/, other)
    rescue LabelResolutionError
      # This symbol is not an assembly label, raise appropriate error
      raise NoMethodError, "undefined method `/' for :#{self}:Symbol"
    end
  end

  # Modulo operation with automatic label resolution
  #
  # @param other [Integer] The value to get modulo with the resolved label address
  # @return [Integer] The result of the modulo operation
  # @raise [LabelResolutionError] If no assembler context is available or label doesn't exist
  def %(other)
    begin
      resolve_label_arithmetic(:%, other)
    rescue LabelResolutionError
      # This symbol is not an assembly label, raise appropriate error
      raise NoMethodError, "undefined method `%' for :#{self}:Symbol"
    end
  end

  private

  # Resolves the symbol as a label and performs the arithmetic operation
  #
  # This method attempts to find the current assembler context and resolve
  # the symbol to its memory address, then performs the requested arithmetic
  # operation on that address.
  #
  # @param operation [Symbol] The arithmetic operation to perform (:+, :-, :*, :/, :%)
  # @param operand [Integer] The operand for the arithmetic operation
  # @return [Integer] The result of the operation
  # @raise [LabelResolutionError] If no assembler context is available or label doesn't exist
  def resolve_label_arithmetic(operation, operand)
    # Try to get the current assembler context from thread-local storage
    assembler_context = Thread.current[:r64_assembler_context]
    
    # If no context in thread-local, try to find it from the memory caller
    if assembler_context.nil?
      memory_caller = Thread.current[:memory_caller]
      if memory_caller.respond_to?(:get_label)
        assembler_context = memory_caller
      elsif memory_caller.respond_to?(:assembler)
        assembler_context = memory_caller.assembler
      end
    end
    
    # If still no context, raise an error
    if assembler_context.nil? || !assembler_context.respond_to?(:get_label)
      raise LabelResolutionError, "No assembler context available for label resolution of :#{self}. " \
                                  "Symbol arithmetic can only be used within R64 assembler methods."
    end
    
    # Try to resolve the label in the current context first
    label_address = nil
    current_context = assembler_context
    
    # Walk up the object hierarchy to find the label
    while current_context && label_address.nil?
      begin
        # Check if this context has the label
        if current_context.instance_variable_get(:@labels)&.key?(self)
          label_address = current_context.get_label(self)
          break
        end
      rescue => e
        # Label not found in this context, try parent
      end
      
      # Move to parent context if available
      if current_context.respond_to?(:parent) && current_context.parent
        current_context = current_context.parent
      elsif current_context.instance_variable_get(:@parent)
        current_context = current_context.instance_variable_get(:@parent)
      else
        break
      end
    end
    
    # If we still haven't found the label, raise a specific error that can be caught
    if label_address.nil?
      raise LabelResolutionError, "Failed to resolve label :#{self} in any context"
    else
      # Perform the arithmetic operation on the resolved label address
      label_address.send(operation, operand)
    end
  end
end
