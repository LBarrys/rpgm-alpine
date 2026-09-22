# msgbox_echo.rb - copy every message box to the console.
#
# An mkxp-z preload script. Put it FIRST, so it is in place before anything can
# fail:
#   "preloadScript": ["/usr/local/lib/rpgm/lib/rgss/msgbox_echo.rb", ...]
#
# RGSS games report errors with `msgbox`, and mkxp-z's `msgbox` only opens a
# window - nothing is written to the console. Games that wrap their script
# loading in `rescue => ex; msgbox ex.message + ex.backtrace...` therefore fail
# completely silently as far as a terminal or a log file is concerned: the game
# quietly skips the broken script and dies somewhere else later, and the log
# just stops mid-boot with no hint of why.
#
# Everything goes to stdout, where the game's own `p` output goes, so a plain
# `rpgm > log` catches it without having to remember to redirect stderr.
#
# Public domain (CC0).

module Kernel
  def msgbox_echo_say(label, lines)
    $stdout.puts "--- #{label} ---"
    Array(lines).each { |l| $stdout.puts l }
    $stdout.puts '-' * (label.length + 8)
    $stdout.flush
  rescue StandardError
    nil
  end
  module_function :msgbox_echo_say

  alias_method :msgbox_without_echo, :msgbox

  def msgbox(*args)
    msgbox_echo_say('msgbox', args.join)
    msgbox_without_echo(*args)
  end
  module_function :msgbox

  if private_method_defined?(:msgbox_p) || method_defined?(:msgbox_p)
    alias_method :msgbox_p_without_echo, :msgbox_p

    def msgbox_p(*args)
      msgbox_echo_say('msgbox_p', args.map(&:inspect))
      msgbox_p_without_echo(*args)
    end
    module_function :msgbox_p
  end
end

# Whatever ends the process, say so and say why. A game that stops with no error
# at all looks exactly like one whose error went to a window nobody captured;
# this tells the two apart.
at_exit do
  ex = $!
  if ex.nil?
    Kernel.msgbox_echo_say('exit', 'ruby finished with no exception pending')
  else
    Kernel.msgbox_echo_say('exit', ["#{ex.class}: #{ex.message}", *Array(ex.backtrace)])
  end
end
