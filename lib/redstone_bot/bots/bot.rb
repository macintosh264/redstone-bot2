require_relative '../uninspectable'
require_relative '../body'
require_relative '../trackers/entity_tracker'
require_relative '../trackers/chunk_tracker'
require_relative '../trackers/inventory'
#require_relative '../trackers/window_tracker'
require_relative '../brain'
require_relative '../abilities/block_manipulation'

require 'forwardable'

# This class is not too useful on its own.  It is meant to be subclassed by
# people making bots.
module RedstoneBot
  class Bot
    include Synchronizer
    include Uninspectable
    include BlockManipulation
    extend Forwardable
    
    attr_reader :client, :body, :brain, :chunk_tracker, :entity_tracker, :inventory    
  
    def initialize(client)
      @client = client
      @client.synchronizer = self
      @mutex = Mutex.new
    end
    
    def start_bot
      setup
      @client.start
    end
    
    # Sets up the logical connections of the different components
    # in this bot.
    def setup
      raise "setup instance method is not defined in #{self.class}"
    end
    
    # Can be called by subclasses
    def standard_setup
      @body = Body.new(@client, self)
      @brain = Brain.new(self)
      @entity_tracker = EntityTracker.new(@client, @body)
      @chunk_tracker = ChunkTracker.new(@client)
      @inventory = Inventory.new(@client)
      #@window_tracker = WindowTracker.new(@client)
    end
    
    def_delegator :@brain, :require, :require_brain
    def_delegators :@body, :position, :look_at, :distance_to, :closest, :wait_for_next_position_update
    def_delegators :@chunk_tracker, :block_type, :block_metadata
    def_delegators :@client, :chat, :time_string
    def_delegators :@inventory, :hold
    def_delegators :@entity_tracker, :entities_of_type
  end
end