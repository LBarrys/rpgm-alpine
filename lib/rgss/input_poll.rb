# input_poll.rb - keep mkxp-z's keyboard polling alive when a game replaces
# Input.update.
#
# An mkxp-z preload script. It must come AFTER win32_wrap.rb:
#   "preloadScript": [..., "/usr/local/lib/rpgm/lib/rgss/input_poll.rb"]
#
# Hime's Input rewrite - and others like it - replace the whole Input module,
# reading the keyboard through GetKeyboardState instead. On Windows that is
# self-contained: the call goes to the OS. Here it goes to win32_wrap.rb, which
# answers from Input.raw_key_states, and mkxp-z only refreshes those states
# inside its own Input.update - the one the game just replaced. Nothing polls
# SDL any more, every key reads as up, and the game stops responding to
# anything at all.
#
# So: keep a handle on the real Input.update, and once a frame, from
# Graphics.update, call it if nothing else has. A game that left Input.update
# alone polls as it always did and this does nothing - checked per frame rather
# than assumed, because polling twice a frame would break trigger? for those
# games instead.
#
# Public domain (CC0).

if Object.const_defined?(:Input) && Input.respond_to?(:update) &&
   Object.const_defined?(:Graphics) && Graphics.respond_to?(:update) &&
   !Input.respond_to?(:mkxp_native_update)

  module Input
    class << self
      # The real one, kept reachable whatever the game does to Input.update.
      alias_method :mkxp_native_update, :update
      alias_method :update_without_poll_mark, :update

      # Games that call Input.update normally - or that alias whatever they
      # find here and call it - mark the frame as already polled.
      def update(*args)
        $rpgm_input_polled = true
        update_without_poll_mark(*args)
      end
    end
  end

  module Graphics
    class << self
      alias_method :update_without_input_poll, :update

      def update(*args)
        result = update_without_input_poll(*args)
        # After the frame, so the states polled are this frame's. win32_wrap.rb
        # drops its cache in its own Graphics.update hook, just above, so the
        # next key read picks these up.
        Input.mkxp_native_update unless $rpgm_input_polled
        $rpgm_input_polled = false
        result
      end
    end
  end
end
