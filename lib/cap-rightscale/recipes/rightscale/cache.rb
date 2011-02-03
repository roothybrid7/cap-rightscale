namespace :rightscale do
  desc "Alias cache:clear"
  task :cc do
    cache.clear
  end

  desc "Clear rightscale's server list cache"
  namespace :cache do
    task :clear do
      logger.info("Clear cache all")
      prefix = ENV['STAGE'] ? ENV['STAGE'] : ""
      pp Dir.glob("#{Dir.tmpdir}/cap-rightscale-#{ENV['USER']}-*/#{prefix}*")
      FileUtils.rm(Dir.glob("#{Dir.tmpdir}/cap-rightscale-#{ENV['USER']}-*/#{prefix}*"), {:force => true})
    end
  end
end
