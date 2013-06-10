require 'csv'

$csv = {}


CSV.foreach("data.csv", :headers => true, :converters => :all) do |row|
  $csv[row[0]] = row
end


#przyklad uzycia:
#$csv.each_key { |k| puts k.to_s}
#$csv.each{|row| puts row[1]['nazwa']}

