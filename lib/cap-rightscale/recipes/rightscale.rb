namespace :rightscale do
  desc "Dry run"
  task :dry_run do
    nil
  end

  desc "Dry run"
  task :noop do
    dry_run
  end
end
