def files_to_load(paths)
  paths = ['.'] if paths.empty?
  result = []
  paths.each do |path|
    if File.directory?(path)
      # puts 'pattern: ' + dir_pattern(path)
      result += Dir[File.expand_path(dir_pattern(path))]
    elsif File.file?(path)
      result << path
    else
      raise "File or directory not found: #{path}"
    end
  end
  result.sort
end

def dir_pattern(path)
  path = path.dup
  path.gsub!(/\/integration\/?$/, '')
  File.join(path, '**', 'integration', '**', '*_test.rb')
end

paths = ARGV.clone
paths = files_to_load(paths)

unless paths.empty?
  root_path = File.dirname(__FILE__).gsub(/vendor.*/, '')
  puts 'Running integration tests ...'
  # paths.each{|path| puts path.gsub(root_path, '') }
  paths.each{|path| require path }
end
