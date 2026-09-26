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

if Object.const_defined?(:Win32API) && Win32API.method_defined?(:mkxp_native_call)
  class Win32API
    alias_method :initialize_without_odd_names, :initialize

    def initialize(dll, func, *args)
      initialize_without_odd_names(dll, func, *args)
    rescue NameError
      @dll = dll
      @func = func
      @called = false
      @mkxp_wrap_impl = nil
      @kgl2_wrap_impl = nil
      @mkxp_native_available = false
    end
  end
end
