# textmode.rb - read text files the way Windows does.
#
# An mkxp-z preload script. Add it to the game's mkxp.json:
#   "preloadScript": ["/usr/local/lib/rpgm/lib/rgss/textmode.rb"]
#
# Windows opens files in text mode unless told otherwise, so "\r\n" turns into
# "\n" while the file is read. Linux has no text mode, so every carriage return
# reaches the game. Most code does not care. Hand-written parsers do, and RGSS
# games are full of them: the JSON decoder many of them ship (game_guy's, the
# one behind "JSON.decode") treats only ' ', "\n" and "\t" as whitespace, so the
# first "\r" ends the parse. It then returns nil instead of the Array or Hash
# the caller wanted, and the game fails somewhere else entirely - LonaRPG says
# "Bitmap Changer ERROR: not an array or hash!" and "undefined method '[]' for
# nil:NilClass", neither of which mentions JSON or line endings.
#
# This restores the Windows behaviour for reads, and only for reads: a handle
# opened for writing, appending or updating, in binary mode, or with the caller's
# own newline setting is passed through untouched, as is a command pipe. Games
# that read their .rvdata2, .png and .ogg files in binary mode - all of them -
# are unaffected.
#
# Public domain (CC0).

module RpgmTextMode
  # True for the modes that only read: nil (Ruby's default "r"), "r", and "r"
  # with an encoding, such as "r:UTF-8" or "r:BOM|UTF-8:UTF-8". Anything else,
  # including "rb", "r+", "w" and integer modes such as File::RDONLY, is left
  # alone.
  def self.read_text?(mode)
    case mode
    when nil then true
    when String then mode.split(':', 2).first == 'r'
    else false
    end
  end

  # Ruby's own universal-newline decorator does the conversion, so it applies to
  # every read method on the handle - read, gets, each_line, readlines - not just
  # the one that was called.
  def self.decorate(name, mode, opts)
    return opts if name.is_a?(String) && name.start_with?('|') # command, not a file
    return opts if opts.key?(:universal_newline) || opts.key?(:newline)
    return opts if opts[:binmode] || opts[:textmode]
    return opts unless read_text?(opts.key?(:mode) ? opts[:mode] : mode)

    opts.merge(universal_newline: true)
  end

  # File.open / IO.open take the mode as their second argument; File.read,
  # File.readlines and File.foreach take a length or a separator there, and can
  # only be given a mode through the options hash.
  module ClassMethods
    def open(name, mode = nil, *rest, **opts, &block)
      super(name, *[mode, *rest].compact, **RpgmTextMode.decorate(name, mode, opts), &block)
    end

    def read(name, *rest, **opts)
      super(name, *rest, **RpgmTextMode.decorate(name, nil, opts))
    end

    def readlines(name, *rest, **opts)
      super(name, *rest, **RpgmTextMode.decorate(name, nil, opts))
    end

    def foreach(name, *rest, **opts, &block)
      super(name, *rest, **RpgmTextMode.decorate(name, nil, opts), &block)
    end
  end

  # Kernel#open, as in open("Data/settings.json").read.
  module KernelMethods
    def open(name, mode = nil, *rest, **opts, &block)
      return super if name.respond_to?(:to_open) || (name.is_a?(String) && name.start_with?('|'))

      super(name, *[mode, *rest].compact, **RpgmTextMode.decorate(name, mode, opts), &block)
    end
    private :open
  end
end

File.singleton_class.prepend(RpgmTextMode::ClassMethods)
Object.prepend(RpgmTextMode::KernelMethods)
