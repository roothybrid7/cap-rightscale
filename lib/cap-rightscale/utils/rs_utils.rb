class RSUtils
  def self.mk_rs_cache_dir(prefix=nil)
    tmpdir = Dir.tmpdir
    _prefix = prefix || "cap-rightscale"
    begin
      path = "#{tmpdir}/#{_prefix}-#{ENV['USER']}-#{rand(0x100000000).to_s(36)}"
      Dir.mkdir(path, 0700)
    rescue Errno::EEXIST
      logger.warn(e)
      exit(1)
    end
  end
end
