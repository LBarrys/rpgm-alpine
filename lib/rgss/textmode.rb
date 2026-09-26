module RpgmTextMode
  def self.read_text?(mode)
    case mode
    when nil then true
    when String then mode.split(':', 2).first == 'r'
    else false
    end
  end

  def self.decorate(name, mode, opts)
    return opts if name.is_a?(String) && name.start_with?('|')
    return opts if opts.key?(:universal_newline) || opts.key?(:newline)
    return opts if opts[:binmode] || opts[:textmode]
    return opts unless read_text?(opts.key?(:mode) ? opts[:mode] : mode)

    opts.merge(universal_newline: true)
  end

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
