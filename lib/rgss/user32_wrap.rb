# user32_wrap.rb - the window and mouse calls RGSS scripts make, which mkxp-z's
# win32_wrap.rb does not implement. Replaces the earlier mouse_wrap.rb.
#
# An mkxp-z preload script. It must come AFTER win32_wrap.rb:
#   "preloadScript": ["/usr/local/lib/mkxp-z/scripts/preload/win32_wrap.rb",
#                     "/usr/local/lib/rpgm/lib/rgss/user32_wrap.rb"]
#
# win32_wrap.rb implements the input calls - GetCursorPos, GetKeyState,
# ShowCursor - and turns everything else into a no-op returning 0. For the two
# scripts almost every VX Ace game carries, that 0 is worse than useless,
# because both of them do arithmetic on what the call was supposed to write.
#
# * The Basic Mouse System scripts (sumptuaryspade's, and LonaRPG's copy) call
#   GetWindowRect to find the window on the desktop and subtract its position
#   from the cursor's. Unimplemented, the rect buffer keeps the ASCII zeroes the
#   script filled it with, so the game subtracts 0x30303030 from the cursor
#   position and the pointer pins itself to the corner.
#
# * Fullscreen++ (Zeus81), which LonaRPG uses for its fullscreen option, asks
#   SystemParametersInfo for the desktop work area and divides by its height:
#   0.0/0.0 is NaN, and the next `.to_i` raises FloatDomainError - the game dies
#   the moment you toggle fullscreen in the options menu.
#
# So: report a window at the origin exactly as large as the game, which makes
# every mouse offset 0 and every scale 1:1, and a desktop comfortably larger
# than the game, which keeps the window-fitting arithmetic away from zero.
#
# Fullscreen itself is then wired to mkxp-z's own: Fullscreen++ switches between
# fullscreen and windowed by turning the window's title bar off and on through
# SetWindowLong, which is a clean signal to act on.
#
# Public domain (CC0).

module Win32API_Impl
  module User32
    def self.game_width
      Graphics.width
    rescue StandardError
      640
    end

    def self.game_height
      Graphics.height
    rescue StandardError
      480
    end

    # GetWindowRect(hwnd, lpRect) -> writes left, top, right, bottom.
    class GetWindowRect
      # The mouse scripts measure the whole window and then take the title bar
      # off the height again ("- 24"), so report one that much taller than the
      # game and the height survives the round trip.
      TITLEBAR = 24
      def call(args)
        memcpy_string(args[1],
                      [0, 0, User32.game_width, User32.game_height + TITLEBAR].pack('l4'))
        1
      end
    end

    # GetSystemMetrics(index) -> pixels. 0 and 1 are the screen's width and
    # height; the mouse scripts use them as the coordinate space that
    # GetCursorPos reports in, and win32_wrap.rb answers that in the game's own
    # coordinates, so these have to match the game and not the real monitor.
    # Every other index here is a border or caption thickness, and mkxp-z's
    # window has none of those as far as the game is concerned.
    class GetSystemMetrics
      SM_CXSCREEN = 0
      SM_CYSCREEN = 1
      def call(args)
        case args[0]
        when SM_CXSCREEN then User32.game_width
        when SM_CYSCREEN then User32.game_height
        else 0
        end
      end
    end

    # SystemParametersInfo(action, uiParam, pvParam, fWinIni)
    class SystemParametersInfo
      SPI_GETWORKAREA = 0x30
      # The usable desktop, as left, top, right, bottom. It only has to be
      # larger than any window the game will ask for: Fullscreen++ compares the
      # size it wants against this one and, if it does not fit, strips the
      # window's borders to fit the screen - which here would look like a
      # request to go fullscreen. Four times the game's own size is past every
      # scaling factor those menus offer.
      ROOM = 4
      def call(args)
        return 0 unless args[0] == SPI_GETWORKAREA
        memcpy_string(args[2],
                      [0, 0, User32.game_width * ROOM, User32.game_height * ROOM].pack('l4'))
        1
      end
    end

    # FindWindow(class, title) -> a window handle. win32_wrap.rb answers
    # FindWindowA with 42 and keys its GetClientRect off that, so use the same
    # handle here; a 0 reads as "no window found" and sends scripts down error
    # paths.
    class FindWindow
      def call(args)
        42
      end
    end

    class FindWindowEx
      def call(args)
        42
      end
    end

    # SetWindowLong(hwnd, index, value). Fullscreen++ goes fullscreen by taking
    # the window's title bar away and back with GWL_STYLE, so treat the loss of
    # the caption as the switch it is meant to be, and hand it to mkxp-z.
    class SetWindowLong
      GWL_STYLE = -16
      WS_CAPTION = 0x00C00000
      def call(args)
        return 0 unless args[1] == GWL_STYLE

        Graphics.fullscreen = (args[2].to_i & WS_CAPTION).zero?
        0
      rescue StandardError
        0
      end
    end
  end
end
