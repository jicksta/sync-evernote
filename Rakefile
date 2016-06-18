task :build do
  system %{
    docker build -t sync-evernote:latest .
  }
end

task :start => :build do
  puts %'Using Developer Token "#{ENV["EVERNOTE_DEV_TOKEN"][0..10]}..."'
  system %{
    docker run --rm -e "EVERNOTE_DEV_TOKEN=#{ENV["EVERNOTE_DEV_TOKEN"]}" sync-evernote:latest
  }
end
