require 'fileutils'

# Create important directories that are needed at runtime
sub_dirs = %w(log tmp tmp/cache tmp/pids tmp/sessions tmp/sockets)

sub_dirs.each do |subdir|
  FileUtils.mkdir_p("#{Rails.root}/#{subdir}") unless File.exists?(subdir)
end
