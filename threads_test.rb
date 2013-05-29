threads = []
puts "start!"
1000.times do |i|
  threads[i] = Thread.new { sleep(5); puts "#{i} done!" }
end

1000.times do |i|
  threads[i].join
end
