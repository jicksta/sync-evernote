desc "Uses Docker to build a container that executes the program"
task :build do
  system %{
    docker build -t sync-evernote:latest .
  }
end

desc "Builds, then runs the Ruby app as a Docker container (with --rm)"
task :start => :build do
  puts %'Using Developer Token "#{ENV["EVERNOTE_DEV_TOKEN"][0..10]}..."'
  system %{
    docker run --rm -v #{Dir.pwd}/data:/mnt/sync-evernote/data -e "EVERNOTE_DEV_TOKEN=#{ENV["EVERNOTE_DEV_TOKEN"]}" sync-evernote:latest
  }
end

namespace :data do
  desc "Removes all files from the data/ directory"
  task :clear do
    system "rm -rvf data/* && touch data/.keep"
  end
end
