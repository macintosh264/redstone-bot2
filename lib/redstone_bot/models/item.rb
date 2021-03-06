require_relative '../protocol/item_types'
require_relative '../protocol/enchantments'

module RedstoneBot
  # This class represents an item, for example in the inventory, on the ground, or
  # being held by an entity.
  # Item objects are immutable (frozen) after they are created.
  class Item < Struct.new(:item_type, :count, :damage, :enchantments)
    def initialize(item_type, count=1, damage=0, enchantments = nil)
      self.item_type = item_type
      self.count = count
      self.damage = damage
      self.enchantments = enchantments

      immutable!
    end

    def immutable!
      enchantments.freeze
      freeze
    end

    # Returns a new item with the specified quantity removed.
    def -(num)
      self + (-num)
    end

    def +(num)
      return self if num.zero?
      self.class.new(item_type, count + num, damage, enchantments) if (count + num) > 0
    end

    def free_space
      item_type.max_stack - count
    end

    def stacks_with?(other)
      other && item_type == other.item_type && damage == other.damage && item_type.stackable?
    end

    # Tries to stack this item with another item.
    # Returns [stack, leftovers].
    def try_stack(other)
      if stacks_with?(other)
        transfer_quantity = [self.free_space, other.count].min
        [self + transfer_quantity, other - transfer_quantity]
      else
        [self, other]
      end
    end

    def ===(other)
      self == other or other.respond_to?(:item) && self == other.item
    end

    def to_s
      s = item_type.to_s
      s += "*#{count}" if count != 1

      details = []
      details << "damage=#{damage}" if damage != 0
      details += enchantments.collect { |e,l| "#{e}=#{l}" } if enchantments
      s += "(" + details.join(" ") + ")" if !details.empty?

      s
    end

  end
end