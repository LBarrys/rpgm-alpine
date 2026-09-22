# dl_wrap.rb - Ruby 1.9's DL library, enough of it for the RGSS key scripts.
#
# An mkxp-z preload script. Order among the other wrappers does not matter:
#   "preloadScript": [..., "/usr/local/lib/rpgm/lib/rgss/dl_wrap.rb"]
#
# RGSS3 shipped Ruby 1.9.2, which had DL, a thin wrapper over dlopen and raw
# memory. Ruby 2.2 removed it in favour of Fiddle, and mkxp-z bundles Ruby 3.1,
# so any script that touches DL dies with "uninitialized constant DL" - and
# since these calls sit at the top of a script, the whole script goes with it.
#
# The one that matters is Hime's Input rewrite, which nearly every RPG Maker
# game carries to reach keys beyond RGSS's eight buttons. It allocates a
# 256-byte block for GetKeyboardState to fill:
#
#   @state = DL::CPtr.new(DL.malloc(256), 256)
#   GetKeyboardState.call(@state.to_i)
#   ... if @state[key] & DOWN_STATE_MASK == DOWN_STATE_MASK
#
# Without DL the script never loads, Input keeps only its default bindings, and
# every key the game maps by letter - A, S, D, F, Q, space - does nothing. The
# keyboard reading itself works fine: win32_wrap.rb implements GetKeyboardState
# against SDL, so all that is missing is the buffer to write into.
#
# `to_i` returns the buffer rather than an address, because there are no
# addresses to hand out here: the only thing done with it is passing it
# straight back into a Win32API call, and win32_wrap.rb writes into the object
# it is given. A script doing arithmetic on the "pointer" would not work, but
# these scripts only ever pass it along.
#
# Public domain (CC0).

unless defined?(::DL)
  module DL
    # A fixed-size block of bytes, indexed like DL::CPtr was.
    class Buffer
      def initialize(size, bytes = nil)
        @bytes = (bytes || '').to_s.b.ljust(size, "\0")[0, size]
      end

      # Where an address would go. See the note above.
      def to_i
        self
      end

      def [](index, length = nil)
        return @bytes.byteslice(index, length) if length

        @bytes.getbyte(index)
      end

      def []=(index, value)
        if value.is_a?(String)
          value.bytes.each_with_index { |b, i| @bytes.setbyte(index + i, b) }
        else
          @bytes.setbyte(index, value.to_i & 0xFF)
        end
        value
      end

      def getbyte(index)
        @bytes.getbyte(index)
      end

      def setbyte(index, value)
        @bytes.setbyte(index, value.to_i & 0xFF)
      end

      def size
        @bytes.bytesize
      end
      alias length size

      def to_s
        @bytes.dup
      end
      alias to_str to_s

      def free; end
      alias ptr to_i
      alias ref to_i
    end

    class CPtr
      # DL::CPtr.new(DL.malloc(256), 256) - the block is already the pointer.
      def self.new(buffer, size = nil)
        return buffer if buffer.is_a?(Buffer)

        Buffer.new(size || 256, buffer)
      end

      def self.malloc(size)
        Buffer.new(size)
      end
    end

    CPtr::TYPE_VOIDP = 0 unless defined?(CPtr::TYPE_VOIDP)

    def self.malloc(size)
      Buffer.new(size)
    end
  end

  ::DL::CPtr::SIZEOF_VOIDP = 8 unless defined?(::DL::CPtr::SIZEOF_VOIDP)
end
