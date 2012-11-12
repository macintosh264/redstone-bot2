require 'redstone_bot/bots/bot'

require 'redstone_bot/chat/chat_filter'
require 'redstone_bot/chat/chat_evaluator'
require 'redstone_bot/chat/chat_mover'

require 'redstone_bot/abilities/pathfinder'
require 'redstone_bot/abilities/body_movers'

require 'redstone_bot/profiler'
require 'redstone_bot/packet_printer'

module RedstoneBot
  class DavidBot < RedstoneBot::Bot
    include BodyMovers
    include Profiler
    
    Aliases = {
      "meq" => "m -2570 -2069",
      "mpl" => "m 100.5 226.5",
      "mkn" => "m -211 785",
      "mwm" => "m -111.5 116.5",
      "mcs" => "m -155 842",
      }
    
    PrintPacketClasses = [
      Packet::ChatMessage,
      Packet::OpenWindow, Packet::CloseWindow, Packet::SetWindowItems, Packet::SetSlot, Packet::UpdateWindowProperty, Packet::ConfirmTransaction
    ]
    
    def setup
      standard_setup

      @packet_printer = PacketPrinter.new(@client, PrintPacketClasses)  # should be before chat_filter
      
      @chat_filter = ChatFilter.new(@client)
      @chat_filter.only_player_chats
      @chat_filter.reject_from_self      
      @chat_filter.aliases Aliases
      @chat_filter.only_from_user(MASTER) if defined?(MASTER)
      
      @ce = ChatEvaluator.new(@chat_filter, self)
      @ce.safe_level = 1
      @ce.timeout = 2
      @cm = ChatMover.new(@chat_filter, self, @entity_tracker)
      
      @body.on_position_update do
        default_position_update unless @current_brain
      end
      
      @client.listen do |p|
        case p
        when Packet::Disconnect
          puts "Position = #{@body.position}"
          exit 2
        end
      end 
      
      @chat_filter.listen do |p|
        next unless p.is_a?(Packet::ChatMessage) && p.player_chat?
        
        case p.chat
        when /drop[ ]*(.*)/
          name = $1
          @inventory.drop 
        when /\Adump all\Z/
          @inventory.dump_all
        when /\Adump all[ ]*(.*)\Z/
          name = $1
          type = ItemType.from(name)
          if type
            @inventory.dump_all(type)
          else
            chat "da understood #{name}"
          end  
        when /\Adump[ ]*(.*)\Z/
          name = $1
          type = ItemType.from(name)
          if type
            @inventory.dump(type)
          else
            chat "da understood #{name}"
          end
        when /\Ahold (.+)\Z/  
          name = $1
          type = ItemType.from(name)
          if type
            @inventory.hold(type)
          else
            chat "da understood #{name}"
          end
        when /\Acraft\Z/
          #@client.send_packet Packet::PlayerBlockPlacement.new([-100,67,804],0,@inventory.slots[36])
          #@client.send_packet Packet::ClickWindow.new(1,
          #def initialize(window_id, slot_id, right_click, action_number, shift, clicked_item)
        when "i"
          puts @inventory
        when "ground report"
          coords = @body.position.dup
          coords.y = find_nearby_ground-1
          columns = [[coords.x+0.3,coords.y,coords.z+0.3],
                     [coords.x-0.3,coords.y,coords.z+0.3],
                     [coords.x+0.3,coords.y,coords.z-0.3],                     
                     [coords.x-0.3,coords.y,coords.z-0.3]]
          chat "The grnd is #{columns.collect { |col| @chunk_tracker.block_type(col)}}"
        when /\Ahow much (.+)\Z/
          # TODO: perhaps cache these results using a SimpleCache
          name = $1
          item_type = ItemType.from name
          if item_type.nil? && name != "nil" && name != "unloaded"
            chat "dunno what #{name} is"
            next
          end          
          
          chat "counting #{item_type && item_type.inspect || 'unloaded blocks'}..."
          result = @chunk_tracker.loaded_chunks.inject(0) do |sum, chunk|
            sum + chunk.count_block_type(item_type)
          end
          chat "there are #{result}"
        end
      end
      
    end
    
    def default_position_update
      if !brain.alive?
        fall_update
        look_at @entity_tracker.closest_entity
      end
    end
        
    def standing_on
      coord_array = (@body.position - Coords::Y*0.5).to_a.collect &:floor
      "#{block_type coord_array} #{@body.position.y}->#{coord_array[1]}"
    end

  end
end