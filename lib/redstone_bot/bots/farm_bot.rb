require_relative 'bot'
require_relative '../simple_cache'

# TODO: see if we can run an IRB thing in the console instead of using ChatEvaluator

module RedstoneBot
  class FarmBot < Bot 
    ExpectedWheatCount = 9759
    FarmBounds = [(-300..-150), (63..63), (670..800)]
    Storage = Coords[-210, 68, 798] - Coords::Z*2
    StorageWaypoint = Coords[-210, 63, 784]  # with a better pathinder we wouldn't need this
  
    PrintPacketClasses = [
      Packet::Thunderbolt,
    ]
  
    def setup
      super

      @packet_printer = PacketPrinter.new(client, PrintPacketClasses)
      
      @wheat_count = SimpleCache.new(@chunk_tracker) do |chunk_id|
        count_wheat_in_chunk(chunk_id)
      end
      
      # Caches the coordinates of each fully-grown wheat by chunk.
      @fully_grown_wheats = SimpleCache.new(@chunk_tracker) do |chunk_id|
        # TODO: reject wheats that are not within FarmBounds
        Coords.each_in_bounds([chunk_id[0]..(chunk_id[0]+15), FarmBounds[1], chunk_id[1]..(chunk_id[1]+15)]).select do |coords|
          block_type(coords) == ItemType::WheatBlock && block_metadata(coords) == ItemType::WheatBlock.fully_grown
        end
      end
      
      @chat_filter.listen do |p|
        case p.chat
        when "farm"
          farm
        end
      end
    end
    
    def farm
      return unless require_brain { farm }
      
      while true
        if wheat_count < ExpectedWheatCount - 50
          $stderr.puts "uh oh, wheat_count=#{wheat_count}"
          delay 5
          
          if wheat_count < ExpectedWheatCount - 50
            chat "what have I done??"
            abort "what have I done?? wheat count got too low (#{wheat_count}), aborting because it might be a fire"
          end
        end
        
        if inventory.spots.quantity(ItemType::Seeds) == 0
          chat "got seeds?"
          return
        end
        
        if inventory_too_full?
          timeout(180) do
            go_from_farm_to_storage
            store_items
            go_from_storage_to_farm
          end
        end
        
        wheats_dug = dig_and_replant_within_reach
        if wheats_dug > 0
          time(2..10) do
            collect_nearby_items
            delay 0.05  # avoid blocking if there are no items
          end
        elsif coords = closest_fully_grown_wheat
          timeout(60) do
            move_to coords + Coords[0.5, 0.0, 0.5]
          end
        else
          # The farm is exhausted!  Save some CPU time by delaying for longer.
          delay 0.75
        end
        
        delay 0.05
      end
      
      chat "done farming"
    end
    
    def dig_and_replant_within_reach
      wheats_dug = 0
      body.coords.change_y(FarmBounds[1].min).spiral.first(100).each do |coords|
        if !wield(ItemType::Seeds)
          break
        end
        
        ground = coords - Coords::Y
                
        next unless distance_to(ground) < 5
        
        if block_type(coords) == ItemType::WheatBlock && block_metadata(coords) == ItemType::WheatBlock.fully_grown
          puts "#{time_string} digging #{coords}"
          wheats_dug += 1
          dig coords
        end
        
        if block_type(ground) == ItemType::Farmland && block_type(coords) == ItemType::Air
          puts "#{time_string} replanting #{coords}"
          place_block_above ground, ItemType::WheatBlock
          #delay(0.1)  # tmphax to slow down the farming
        end
      end
      return wheats_dug
    end
    
    def go_from_farm_to_storage
      return unless require_brain { go_from_farm_to_storage }
      
      move_to StorageWaypoint if defined?(StorageWaypoint)
      path_to Storage
    end
    
    def go_from_storage_to_farm
      return unless require_brain { go_from_storage_to_farm }
      
      path_to StorageWaypoint if defined?(StorageWaypoint)
    end
    
    def store_items
      return unless require_brain { store_items }
    
      chat "hmmmm, how 2 store items in chests... I'll just dump it"
      
      # Dump everything, except guarantee that we at least have half a stack of seeds left
      # TODO: express this more elegantly
      inventory.normal_spots.each do |spot|
        next if ItemType::Seeds === spot && inventory.spots.quantity(ItemType::Seeds) < 96
        dump spot
      end
      
      delay(2)
    end
       
    def collect_nearby_items
      while true
        # Get the closest Wheat or Seed item that is at the right level.
        # We just ignore items that fell into the water.
        item = closest desirable_items
        
        if item && distance_to(item) < 30
          puts "#{time_string} moving to #{item}"
          move_to item.coords.change_y(FarmBounds[1].min)
        else
          return
        end
      end
    end
    
    def desirable_items
      entity_tracker.select do |entity|
        (ItemType::WheatItem === entity or ItemType::Seeds === entity) and FarmBounds[1].include?(entity.coords.y.floor)
      end
    end
    
    def save_wheats
      filename = "wheats.dat"
      if File.exist?(filename)
        chat "file already exist man"
        return
      end
      File.open(filename, "w") do |f|
        wheats.collect(&:to_a).sort.each do |coords|
          f.puts coords.join("\t")
        end
      end
    end
    
    def closest_fully_grown_wheat
      fully_grown_wheats.min_by { |coords| @body.distance_to(coords) }
    end
    
    def wheat_count
      farm_chunks.inject(0) { |sum, chunk_id| sum + (@wheat_count[chunk_id] || 0) }
    end
    
    def fully_grown_wheats
      farm_chunks.flat_map { |chunk_id| @fully_grown_wheats[chunk_id] }
    end
    
    # Uncached!
    def average_growth
      growths = wheats.collect { |c| block_metadata(c) }
      growths.inject(:+).to_f / growths.count
    end
    
    # Uncached!
    def wheats
      farm_blocks.select { |c| block_type(c) == ItemType::WheatBlock }
    end
    
    # Uncached!
    def count_unloaded
      farm_blocks.count { |c| block_type(c) == nil }
    end
    
    def farm_blocks
      Coords.each_in_bounds(FarmBounds)
    end
    
    def farm_chunks
      Coords.each_chunk_id_in_bounds(FarmBounds)
    end
    
    # This function has intimate knowledge of Chunk and ChunkTracker.
    # chunk_id is an [x,z] array with x and z are multiples of 16.
    def count_wheat_in_chunk(chunk_id)
      yrange = FarmBounds[1]
      chunk = @chunk_tracker.chunks[chunk_id]
      return nil if !chunk
      yrange.inject(0) do |sum, y|
        sum + chunk.block_type_raw_yslice(y).bytes.count(ItemType::WheatBlock.id)
      end
    end
    
    def inventory_too_full?
      # At least one slot for seeds, one slot for wheat.
      inventory.general_spots.empty_spots.size < 2
    end
    
    TestChestCoords = Coords[-248, 69, 661];
    
    def openy(chest_coords=TestChestCoords)
      chest_open_start chest_coords
    end

    def wheat_swap
      chest_open(TestChestCoords) do
        move_wheat
      end
    end    

    def move_wheat
      unless window_tracker.chest_spots
        chat "chest not open"
        return
      end
        
      spots = if window_tracker.inventory.spots.quantity(ItemType::WheatItem) > 0
        window_tracker.inventory.spots
      else
        window_tracker.chest_spots
      end
      
      spots.grep(ItemType::WheatItem).each do |spot|
        window_tracker.shift_click spot
      end
      nil
    end
    
    def conflict(spot, item)
      if spot.item == item
        chat "hmm, that wouldn't cause a conflict, that spot already has that item in it"
        return
      end
      
      spot.item = item
    end
    
    def left_conflict(index=0)
      spot = window_tracker.inventory.hotbar_spots[index]
      item = ItemType::DiamondAxe * 1

      conflict spot, item
      
      window_tracker.left_click spot
    end
    
    def shift_conflict
      spot = window_tracker.inventory.hotbar_spots[0]
      item = ItemType::WheatItem * 64

      conflict spot, item
      window_tracker.shift_click spot  
    end
    
    def swap_in_chest
      window_tracker.swap *window_tracker.chest_spots[0..1]
    end

  end
end