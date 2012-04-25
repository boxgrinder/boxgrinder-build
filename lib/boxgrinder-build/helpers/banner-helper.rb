module BoxGrinder
  module Banner
    def self.message(message, delim = "*", wrap = 92, soft_wrap = true)
      str = ("" << $/ << delim * wrap << $/).green
      str << long_line_reduce(message, wrap, soft_wrap)
      str << (delim * wrap << $/).green
    end

    private
    def self.long_line_reduce(message, wrap, soft_wrap)
      return "" if message == nil 

      message.each_line.reduce("") do |acc, line| 
        if line.length > wrap-1 && line[wrap] != $/
          wrap_point = soft_wrap ? s_wrap_index(line, wrap) || wrap : wrap 
          line.insert(wrap_point, $/)
          # Reduce lines that are multiple times the wrap limit.
          line << long_line_reduce(line.slice!(wrap-1 .. -1), wrap, soft_wrap) 
        end
        acc << line 
      end
    end

    def self.s_wrap_index(line, wrap)
      index = line.slice(0, wrap).rindex(" ")
      index.nil? ? nil : index + 1
    end
  end
end
