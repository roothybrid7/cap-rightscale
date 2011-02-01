desc "Clear rightscale's server list cache"
namespace :rs_cache do
  task :clear do
    puts "Clear cache all"
    pp Dir.glob("#{Dir.tmpdir}/cap-rightscale-*/*")
    FileUtils.rm(Dir.glob("#{Dir.tmpdir}/cap-rightscale-*/*"), {:force => true})
  end

  desc "Alias cache:clear"
  task :cc do
    clear
  end
end
