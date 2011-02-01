namespace :rightscale do
  desc "Alias cache:clear"
  task :cc do
    cache.clear
  end

  desc "Clear rightscale's server list cache"
  namespace :cache do
    task :clear do
      puts "Clear cache all"
      pp Dir.glob("#{Dir.tmpdir}/cap-rightscale-*/#{stage}*")
      FileUtils.rm(Dir.glob("#{Dir.tmpdir}/cap-rightscale-*/#{stage}*"), {:force => true})
    end
  end
end