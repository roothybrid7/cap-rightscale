desc "Alias cache:clear"
task :rs_cc do
  rs_cache.clear
end

desc "Clear rightscale's server list cache"
namespace :rs_cache do
  task :clear do
    puts "Clear cache all"
    pp Dir.glob("#{Dir.tmpdir}/cap-rightscale-*/*")
    FileUtils.rm(Dir.glob("#{Dir.tmpdir}/cap-rightscale-*/*"), {:force => true})
  end
end
