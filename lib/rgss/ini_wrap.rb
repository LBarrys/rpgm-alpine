# ini_wrap.rb - make kernel32's .ini functions work.
#
# An mkxp-z preload script. It must come AFTER mkxp-z's own win32_wrap.rb, and
# both need full paths, because mkxp-z resolves them from the game's folder:
#   "preloadScript": ["/usr/local/lib/mkxp-z/scripts/preload/win32_wrap.rb",
#                     "/usr/local/lib/rpgm/lib/rgss/ini_wrap.rb"]
# `rpgm --info` prints this list with the paths this machine actually has.
#
# win32_wrap.rb turns every unimplemented Win32API call into a no-op returning 0.
# For kernel32's .ini ("private profile") functions that is actively wrong: a game
# asking Game.ini for its saved BGM volume gets 0 back and plays silently, instead
# of the default it passed in. This implements those four calls against the real file.
#
# Public domain (CC0).

module Win32API_Impl
  module Kernel32
    # Windows .ini files are ANSI/Shift-JIS; read as binary and only touch ASCII.
    def self.read(path)
      File.open(path, 'rb') { |f| f.read } rescue nil
    end

    # Value of [section] key, or nil. Section and key match case-insensitively,
    # as the Windows API does.
    def self.lookup(path, section, key)
      data = read(path.to_s)
      return nil unless data
      want_section = section.to_s.strip.downcase
      want_key = key.to_s.strip.downcase
      current = nil
      data.each_line do |line|
        line = line.strip
        next if line.empty? || line.start_with?(';', '#')
        if line =~ /\A\[(.*)\]\z/
          current = $1.strip.downcase
        elsif current == want_section && line.include?('=')
          k, v = line.split('=', 2)
          return v.to_s.strip if k.to_s.strip.downcase == want_key
        end
      end
      nil
    end

    # Rewrite [section] key = value, creating either if needed. Returns true on success.
    def self.store(path, section, key, value)
      path = path.to_s
      data = read(path) || ''
      want_section = section.to_s.strip.downcase
      want_key = key.to_s.strip.downcase
      lines = data.split(/\r?\n/, -1)
      out = []
      current = nil
      done = false
      section_end = nil
      lines.each do |line|
        stripped = line.strip
        if stripped =~ /\A\[(.*)\]\z/
          section_end = out.size if current == want_section && !done
          current = $1.strip.downcase
        elsif !done && current == want_section && stripped.include?('=')
          k, = stripped.split('=', 2)
          if k.to_s.strip.downcase == want_key
            out << "#{key}=#{value}"
            done = true
            next
          end
        end
        out << line
      end
      unless done
        if section_end                      # section exists: append inside it
          out.insert(section_end, "#{key}=#{value}")
        elsif current == want_section       # section is the last one in the file
          out << "#{key}=#{value}"
        else                                # no such section yet
          out << '' unless out.empty? || out.last.to_s.strip.empty?
          out << "[#{section}]"
          out << "#{key}=#{value}"
        end
      end
      File.open(path, 'wb') { |f| f.write(out.join("\r\n")) }
      true
    rescue StandardError
      false
    end

    # GetPrivateProfileInt(section, key, default, file) -> Integer
    class GetPrivateProfileInt
      def call(args)
        section, key, default, file = args
        value = Kernel32.lookup(file, section, key)
        return default.to_i if value.nil?
        (value[/\A[+-]?\d+/] || default).to_i
      end
    end

    # GetPrivateProfileString(section, key, default, buffer, size, file) -> length
    class GetPrivateProfileStringA
      def call(args)
        section, key, default, buffer, size, file = args
        value = Kernel32.lookup(file, section, key) || default.to_s
        size = size.to_i
        value = value[0, size - 1] if size > 0 && value.length >= size
        if buffer.is_a?(String)
          padded = value + "\0" * [buffer.bytesize - value.bytesize, 1].max
          buffer[0, buffer.bytesize] = padded[0, buffer.bytesize]
        end
        value.length
      end
    end

    # WritePrivateProfileString(section, key, value, file) -> 1 on success, 0 on failure
    class WritePrivateProfileStringA
      def call(args)
        section, key, value, file = args
        Kernel32.store(file, section, key, value.to_s.split("\0").first.to_s) ? 1 : 0
      end
    end

    # Games call these with or without the trailing "A".
    GetPrivateProfileString = GetPrivateProfileStringA
    WritePrivateProfileString = WritePrivateProfileStringA
  end
end
