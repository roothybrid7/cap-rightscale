namespace :rs do
  desc "Alias cache:clear"
  task :cc do
    cache.clear
  end

  desc "Clear rightscale's server list cache"
  namespace :cache do
    task :clear do
      logger.debug("Clear cache all")
      logger.trace(Dir.glob("#{Dir.tmpdir}/cap-rightscale-#{ENV['USER']}-*/*").each {|f| f } || "")
      FileUtils.rm(Dir.glob("#{Dir.tmpdir}/cap-rightscale-#{ENV['USER']}-*/*"), {:force => true})
    end
  end
end
