# all.rb - load every shim rpgm ships for mkxp-z, in the order they need.
#
# This is the only line a game's mkxp.json needs:
#
#   "preloadScript": ["/usr/local/lib/rpgm/lib/rgss/all.rb"]
#
# It pulls in mkxp-z's own win32_wrap.rb and kgl2_wrap.rb first, because most
# of the rest build on them, and then rpgm's, in an order that matters:
# msgbox_echo.rb goes first so that anything failing after it is visible, and
# lenient.rb goes last because it chains onto the Win32API the other two
# installed. Listing them by hand got that wrong more than once.
#
# mkxp-z's copies are wherever it was built to; `rpgm` passes the folder in
# RPGM_MKXPZ_PRELOAD, and failing that the usual places are tried. Set
# RPGM_RGSS_SKIP to a space-separated list of names ("user32_wrap textmode") to
# leave individual shims out.
#
# Public domain (CC0).

module RpgmShims
  # Where mkxp-z keeps win32_wrap.rb and friends.
  def self.mkxpz_preload
    candidates = [ENV['RPGM_MKXPZ_PRELOAD']]
    %w[/usr/local /usr].each { |p| candidates << "#{p}/lib/mkxp-z/scripts/preload" }
    candidates << "#{ENV['HOME']}/.local/lib/mkxp-z/scripts/preload" if ENV['HOME']
    candidates << 'scripts/preload' # a copy next to the game, as upstream suggests
    candidates.compact.find { |dir| File.file?("#{dir}/win32_wrap.rb") }
  end

  # Where rpgm's own shims are. __FILE__ is what mkxp.json named, which is
  # normally enough; RPGM_SHIM_DIR covers a copy moved somewhere else.
  def self.shim_dir
    [ENV['RPGM_SHIM_DIR'],
     File.dirname(File.expand_path(__FILE__)),
     '/usr/local/lib/rpgm/lib/rgss',
     ENV['HOME'] ? "#{ENV['HOME']}/.local/lib/rpgm/lib/rgss" : nil]
      .compact.find { |dir| File.file?("#{dir}/lenient.rb") }
  end

  def self.skipped
    @skipped ||= ENV['RPGM_RGSS_SKIP'].to_s.split(/[\s,]+/).reject(&:empty?)
  end

  def self.load_one(dir, name)
    return false if dir.nil?
    return false if skipped.include?(name)

    path = "#{dir}/#{name}.rb"
    return false unless File.file?(path)

    load path
    true
  rescue Exception => e
    # Never let one shim take the rest down with it; say so and carry on.
    warning = "rpgm: #{name}.rb did not load: #{e.class}: #{e.message}"
    begin
      $stdout.puts warning
      $stdout.flush
    rescue StandardError
      nil
    end
    false
  end
end

mkxpz = RpgmShims.mkxpz_preload
here = RpgmShims.shim_dir

# msgbox_echo first: from here on, a failure in any other shim is printed
# rather than shown in a window nobody is watching.
RpgmShims.load_one(here, 'msgbox_echo')

# mkxp-z's own, which the rest extend.
RpgmShims.load_one(mkxpz, 'win32_wrap')
RpgmShims.load_one(mkxpz, 'kgl2_wrap')

RpgmShims.load_one(here, 'dl_wrap')
RpgmShims.load_one(here, 'textmode')
RpgmShims.load_one(here, 'user32_wrap')
RpgmShims.load_one(here, 'ini_wrap')
RpgmShims.load_one(here, 'input_poll')

# Last: it wraps whatever Win32API#initialize the two above ended up with.
RpgmShims.load_one(here, 'lenient')

if mkxpz.nil?
  begin
    $stdout.puts 'rpgm: mkxp-z\'s win32_wrap.rb was not found; Win32API calls will raise.'
    $stdout.puts 'rpgm: set RPGM_MKXPZ_PRELOAD to the folder holding it.'
    $stdout.flush
  rescue StandardError
    nil
  end
end
