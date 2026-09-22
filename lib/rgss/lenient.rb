# lenient.rb - accept what RGSS accepted.
#
# An mkxp-z preload script. It must come LAST, after win32_wrap.rb and
# kgl2_wrap.rb, because it chains onto whatever they installed:
#   "preloadScript": [..., "/usr/local/lib/rpgm/lib/rgss/lenient.rb"]
#
# mkxp-z checks argument types that RPG Maker's own player never did, so code
# that has always worked on Windows raises here. Two cases show up constantly,
# and both kill the entire script they appear in.
#
# 1. Booleans. RGSS took any object as a flag and asked only whether it was
#    truthy; mkxp-z insists on true or false. LonaRPG's copy of Khas Ultra
#    Lighting does `@sprite.visible = @sprite` - a Sprite, not a boolean - and
#    mkxp-z answers "Argument 0: Expected bool", from inside the title screen's
#    spriteset. Here every boolean setter takes the object and keeps only its
#    truth, as RGSS did.
#
# 2. Win32API library names that are not Ruby constants. win32_wrap.rb maps
#    "user32" to Win32API_Impl::User32 by capitalising it and calling
#    const_defined?, which raises NameError on anything containing a dot or a
#    slash - "System/F1AltEnterF12", "Data/PaletteChanger/Foo.dll" - instead of
#    falling through to its own tolerant behaviour. The call cannot work on
#    Linux either way; failing quietly and returning 0 costs a feature, while
#    raising costs the whole script.
#
# Public domain (CC0).

# --- 1. boolean setters ------------------------------------------------------
[
  ['Sprite',   %i[visible mirror]],
  ['Window',   %i[visible active pause openness_visible arrows_visible]],
  ['Plane',    %i[visible]],
  ['Viewport', %i[visible]],
  ['Tilemap',  %i[visible]],
  ['Font',     %i[bold italic outline shadow]],
].each do |class_name, setters|
  next unless Object.const_defined?(class_name)

  klass = Object.const_get(class_name)
  setters.each do |setter|
    writer = :"#{setter}="
    next unless klass.method_defined?(writer)
    next if klass.method_defined?(:"#{setter}_without_coercion=")

    klass.class_eval do
      alias_method :"#{setter}_without_coercion=", writer
      define_method(writer) do |value|
        send(:"#{setter}_without_coercion=", value ? true : false)
      end
    end
  end
end

# --- 2. Win32API library names ------------------------------------------------
if Object.const_defined?(:Win32API) && Win32API.method_defined?(:mkxp_native_call)
  class Win32API
    alias_method :initialize_without_odd_names, :initialize

    def initialize(dll, func, *args)
      initialize_without_odd_names(dll, func, *args)
    rescue NameError
      # Not a usable library name here. Leave the object in the state
      # win32_wrap.rb uses for a function it cannot provide: calls return 0.
      @dll = dll
      @func = func
      @called = false
      @mkxp_wrap_impl = nil
      @kgl2_wrap_impl = nil
      @mkxp_native_available = false
    end
  end
end
