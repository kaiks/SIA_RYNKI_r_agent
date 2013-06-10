require 'csv'

$stock_info = {}

csv_data = CSV.foreach($PARENT_DIR + "data.csv", :headers => true, :converters => :all)

# {id_zasobu => {...}}
CSV.foreach($PARENT_DIR + "data.csv", :headers => true, :converters => :all) { 
										|row| 
											hashed = row.to_hash
											hashed.delete "id_zasobu"
											$stock_info.update row[0] => hashed}
