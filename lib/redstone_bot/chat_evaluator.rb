
module RedstoneBot
  # Vulnerabilities:
  #   Thread.new { while true; end }
  #   "eval " + string
  #   EvaluatesRuby.instance_method(:handle_chat).bind(self).call(message)
  class ChatEvaluator
    attr_accessor :permission_denied_message
    attr_accessor :safe_level
  
    def initialize(client, context)
      @context = context
      @client = client
      @permission_denied_message = "I'm sorry %s, but I cannot do that."
      @safe_level = 4
    
      client.listen do |p|
        next unless p.is_a?(Packet::ChatMessage)

        next unless p.chat =~ /^eval (.+)/
        str = $1
        
        do_eval str
      end
    end
  
    def do_eval(string)
      result = nil
      exception = nil
      thread = Thread.new do
        $SAFE = @safe_level
        result = begin
          (@context || self).instance_eval string
        rescue Exception => e
          exception = e
          e.message
        end
      end
      if !thread.join(0.5)
        thread.kill
        result = ":("
      end

      if exception
        $stderr.puts exception.message, exception.backtrace
      end
      
      begin
        case result
          when String then chat result
          when nil then
          else chat result.inspect
          end
      rescue SecurityError => e
        chat e.message
      end

      GC.enable
    end
    
    protected
    def chat(message)
      @client.chat(message)
    end
  end
  
end