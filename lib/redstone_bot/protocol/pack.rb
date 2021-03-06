require_relative 'nbt'
require_relative 'item_encoding'

module RedstoneBot
  module DataReader
    include NBT::Reader
    include ItemReader
    extend self
  
    def read_bool
      read_byte != 0
    end
  
    def read_byte
      read(1).ord
    end
    
    def read_signed_byte
      read(1).unpack('c')[0]
    end

    def read_byte_array
      len = read_short      
      if len < 0
        nil
      else
        read(len)
      end
    end
    
    def read_short
      read(2).unpack('s>')[0]
    end

    def read_unsigned_short
      read(2).unpack('S>')[0]
    end
    
    def read_int
      read(4).unpack('l>')[0]
    end

    def read_unsigned_int
      read(4).unpack('L>')[0]
    end
    
    def read_long
      read(8).unpack('q>')[0]
    end

    def read_float
      read(4).unpack('g')[0]
    end

    def read_double
      read(8).unpack('G')[0]
    end

    def read_string_raw
      read(read_short * 2).force_encoding("UCS-2BE")
    end

    def read_string
      read_string_raw.encode("UTF-8")
    end
    
    def read_string_utf8
      read(read_short).force_encoding("UTF-8")
    end

    def read_metadata
      buf = {}
      while (b = read(1).ord) != 0x7F
        buf[b & 0x1F] = case b >> 5
          when 0 then read_byte
          when 1 then read_short
          when 2 then read_int
          when 3 then read_float
          when 4 then read_string
          when 5 then read_item
          when 6 then [read_int, read_int, read_int]
          end
      end
      buf.freeze
    end

  end
  
  module DataEncoder
    include NBT::Encoder
    include ItemEncoder
    extend self
  
    def signed_byte(b)
      [b].pack('c')
    end

    def byte(b)
      [b].pack('C')
    end
    
    def byte_array(b)
      unsigned_short(b.size) + b
    end

    def short(s)
       [s].pack('s>')
    end
    
    def unsigned_short(s)
      [s].pack('S>')
    end

    def bool(b)
      # we frequently switch back and forth between bytes and bools, and this will help us catch bugs
      raise "Expected true or false but got #{b.inspect}" if b != true && b != false
      byte(b ? 1 : 0)
    end

    def int(i)
      [i].pack('l>')
    end
    
    def unsigned_int(i)
      [i].pack('L>')
    end

    def long(l)
      [l].pack('q>')
    end

    def float(f)
      [f].pack('g')
    end

    def double(d)
      [d].pack('G')
    end

    def string(s)
      short(s.length) + s.encode('UCS-2BE').force_encoding('BINARY')
    end
    
    def string_utf8(s)
      s = s.encode("UTF-8")  # usually a no-op
      short(s.bytesize) + s.force_encoding('BINARY')
    end
        
  end
  
  # To make sure that the enchant data is encoded correctly as nbt, we have to
  # make this little hack.  NBT encoded using NbtEncoderForEnchantData.nbt will
  # not be allowed to use the Byte type and will instead use Short.
  module NbtEncoderForEnchantData
    include DataEncoder
    extend self
    
    def nbt_possible_tag_ids(value)
      super(value) - [1]
    end    
  end
  
end