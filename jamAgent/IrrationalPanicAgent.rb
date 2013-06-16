require 'Agent'

require 'stockInformation.rb'


class IrrationalPanicAgent < SimpleAgent
	attr_accessor :coef_price_decrease, :coef_price_increase, :best_offers, :best_offers_grad,
				  :coef_money_when_buying, :coef_orders_when_selling, :subscribed_count,
				  :rand_for_action, :subscribed, :max_orders_treshold, :max_buy_candidates, :max_sell_candidates
    
	def self.generateRandomCoef(rand_gen = Random.new, coef_dict = {})
		
		dict = super(rand_gen, coef_dict)
		
		#coef_price_decrease 
		cpd_min, cpd_max = coef_dict.fetch(:coef_price_decrease, [$coef_price_decrease_min, $coef_price_decrease_max])
		#coef_price_increase 
		cpi_min, cpi_max = coef_dict.fetch(:coef_price_increase, [$coef_price_increase_min, $coef_price_increase_max])
		#coef_money_when_buying 
		cmwb_min, cmwb_max = coef_dict.fetch(:coef_money_when_buying,[$coef_money_when_buying_min, $coef_money_when_buying_max])
		#coef_orders_when_selling
		cows_min, cows_max = coef_dict.fetch(:coef_orders_when_selling, [$coef_orders_when_selling_min, $coef_orders_when_selling_max])
		#subscribed_count 
		sc_min, sc_max = coef_dict.fetch(:subscribed_count, [$subscribed_count_min, $subscribed_count_max])
		# max_orders_treshold
		mot_min, mot_max = coef_dict.fetch(:max_orders_treshold, [$max_orders_treshold_min, $max_orders_treshold_max]) 
		# max_buy_candidates
		mbc_min, mbc_max = coef_dict.fetch(:max_buy_candidates, [$max_buy_candidates_min, $max_buy_candidates_max]) 
		# max_sell_candidates
		msc_min, msc_max = coef_dict.fetch(:max_sell_candidates, [$max_sell_candidates_min, $max_sell_candidates_max]) 
		
		coefs = {:coef_price_decrease => rand_gen.rand(cpd_min..cpd_max),
				 :coef_price_increase => rand_gen.rand(cpi_min..cpi_max),
				 :coef_money_when_buying => rand_gen.rand(cmwb_min..cmwb_max),
				 :coef_orders_when_selling => rand_gen.rand(cows_min..cows_max),
				 :subscribed_count => rand_gen.rand(sc_min..sc_max),
				 :max_orders_treshold => rand_gen.rand(mot_min..mot_max),
				 :max_buy_candidates => rand_gen.rand(mbc_min..mbc_max),
				 :max_sell_candidates => rand_gen.rand(msc_min..msc_max)
				 }
		
		dict.update(coefs)
	end

	def self.createInstance(id, password, data)
		inst = super(id, password, data)
		
		inst.coef_price_decrease = data.fetch(:coef_price_decrease)
		raise "coef_price_decrease >= 0 " unless inst.coef_price_decrease < 0.0 
		inst.coef_price_increase = data.fetch(:coef_price_increase)
		raise "coef_price_increase <= 0" unless inst.coef_price_increase > 0.0
		inst.coef_money_when_buying = data.fetch(:coef_money_when_buying)
		raise "coef_money_when_buying <= 0" unless inst.coef_money_when_buying > 0.0
		inst.coef_orders_when_selling = data.fetch(:coef_orders_when_selling)
		raise "coef_orders_when_selling <= 0" unless inst.coef_orders_when_selling > 0.0
		inst.subscribed_count = data.fetch(:subscribed_count)
		raise "subscribed_count < 1" unless inst.subscribed_count >= 1
		inst.max_orders_treshold = data.fetch(:max_orders_treshold)
		raise "max_orders_trashold < 1" unless inst.max_orders_treshold >= 1
		inst.max_buy_candidates = data.fetch(:max_buy_candidates)
		raise "max_buy_candidates < 1" unless inst.subscribed_count >= 1
		inst.max_sell_candidates = data.fetch(:max_sell_candidates)
		raise "max_sell_candidats < 1" unless inst.max_orders_treshold >= 1
		
		inst.rand_for_action = Random.new	
		inst.subscribed = []
		
		inst.best_offers = {:sell => {}, :buy => {}}
		inst.best_offers_grad = {:sell => {}, :buy => {}}
		inst
	end

	def loginUser
		return false if not super
		#High time to choose subscriptions! 
		if @subscribed.empty?
			@subscribed = $stock_info.keys.sample(@subscribed_count)
			raise "my_stocks.length != 1. Something very wrong! #{@my_stocks}" unless @my_stocks.length == 1 
			my_gift_stock, = @my_stocks.keys	
			@subscribed[-1] = my_gift_stock unless @subscribed.include? my_gift_stock 
		end
		subscribe subscribed
		# After login grad should be 0.0 as we have no data to make other claims
		subscribed.each {|stockId| @best_offers_grad[:sell][stockId] = [0.0,0.0] 
								   @best_offers_grad[:buy][stockId] = [0.0, 0.0]}
		
		true
	end	
	
	def buyStock(stockId, price_change_coef)
		#puts "Time to buy some stock #{stockId} #{price_change_coef}"
		computed_money = (@my_money * @coef_money_when_buying).to_i 
		money = @my_money
		money = computed_money unless computed_money <= 0
		
		return false unless money >= 1
		
		# Will buy for a little bit more than the best offer suggests.
		price_per_stock = Random.new.rand 1..[(money * @coef_money_when_buying).to_i, 1].max
		if @best_offers[:sell].include? stockId
			price_per_stock = [@best_offers[:sell][stockId].price + (@best_offers[:sell][stockId].price * price_change_coef).to_i, 1].max
		end
		raise "buyStock: money #{money} and price per stock #{price_per_stock}" unless price_per_stock > 0 
		max_stock_money_can_buy = $stock_info.fetch(stockId, {}).fetch('l_akcji', 1 << 30)
		stock_amount = [money / price_per_stock, max_stock_money_can_buy].min
		return false unless stock_amount > 0
		
		#puts "| #{stockId} | #{stock_amount} | #{price_per_stock} |"
		@socket.print BuyStockReq.new(stockId, stock_amount, price_per_stock).forge  
		# should probably wait for an id of new  order 
		@my_money -= stock_amount * price_per_stock 
		puts "Ordered to buy #{stock_amount} of id=#{stockId} for #{price_per_stock} per stock and my money: #{@my_money}"
		true
	end

	def sellStock(stockId, price_change_coef)
		#puts "Time to sell some stock #{stockId} #{price_change_coef}"
		#puts "ORDERS:\n"
		#@my_orders.each {|k,v| puts "id= #{k} =>  #{v}\n"}
		computed_stock_amount = (@my_stocks[stockId] * @coef_orders_when_selling).to_i
		stock_amount = @my_stocks[stockId]
		stock_amount = computed_stock_amount unless computed_stock_amount < 0
		return false unless stock_amount > 0
		# Will sell for a little bit less than the best offer suggests
		price_per_stock = Random.new.rand $random_price_per_stock_when_selling_min...$random_price_per_stock_when_selling_max
		if @best_offers[:buy].include? stockId
			price_per_stock = [@best_offers[:buy][stockId].price + (@best_offers[:buy][stockId].price * price_change_coef).to_i, 1].max
		end
		raise "sellStock: stocks[#{stockId}] = #{@my_stocks[stockId]} and price per stock #{price_per_stock}" unless price_per_stock > 0 
		@socket.print SellStockReq.new(stockId, stock_amount, price_per_stock).forge
		# should probably wait for an id of new  order
		@my_stocks[stockId] -= stock_amount
		
		puts "Ordered to sell #{stock_amount} of id=#{stockId} for #{price_per_stock} per stock" 
		true
	end
	
	def act!
		#	If agent has money and there are some orders which are good enough to buy => buy one
		#	If agent has some stocks which are good enough to sell => sell one
		#puts "Time to act!"
		updateOrdersAndStocks!
		# If agent has too much orders, then only cancel them.
		if @max_orders_treshold <= (@my_orders[:sell].length + @my_orders[:buy].length)
				orders_to_cancel = []
				orders_to_cancel += @my_orders[:sell].keys
				orders_to_cancel += @my_orders[:buy].keys
				orderId = orders_to_cancel.sample 
				puts "Canceling order order_id = #{orderId}"
				@socket.print CancelOrderReq.new(orderId).forge
		end
		sell_candidates_higher = @best_offers_grad[:buy].select { |stockId, diff_perc| 
									 diff_perc[1] > @coef_price_increase and @my_stocks.include? stockId and 
									 @best_offers[:buy].include? stockId}

		#sell_candidates_panic = best_offers_grad[:buy].select 
		#							{|stockId, diff_perc| 
		#							 diff_perc < @coef_price_decrease and my_stocks.include? stockId}			 
		
		#buy_candidates_higher = best_offers_grad[:sell].select 									
		#							{|stockId, diff_perc| 
		#							 diff_perc > @coef_price_increase and my_stocks.include? stockId}

		buy_candidates_panic = @best_offers_grad[:sell].select {|stockId, diff_perc| 
									 diff_perc[1] < @coef_price_decrease and @best_offers[:sell].include? stockId and 
									 @my_money >= @best_offers[:sell][stockId].price}

		action_sell = false
		action_buy = false
		sell_candidates_higher.keys.sample(@max_sell_candidates).each {|stockId| action_sell ||= sellStock(stockId, @coef_price_decrease)}
		#sell_candidate_panic.each { |stockId| sellStock(stockID, @coef_price_decrease)}
		#buy_candidate_higher.each {|stockId| sellStock(stockId, @coef_price_increase)}
		buy_candidates_panic.keys.sample(@max_buy_candidates).each { |stockId| action_buy ||= buyStock(stockId, @coef_price_increase)}
		# If false then it means there was no action
		#puts "ACTED?"
		action_sell and action_buy
	end
	
	def randomAct!
		#puts "Time to act randomly!"
		# Create available actions and then choose sample one.
		actions = []
		#puts "Best offers\n:#{@best_offers}\n"

		# buy stock action
		stock_available_to_buy = @subscribed #@best_offers[:sell].select {|stockId, data| data.price < @my_money } .keys
		unless stock_available_to_buy.empty? and @money >= 1
			actions << :buy_stocks
		end		
		# sell stock action
		stock_available_to_sell = @my_stocks.select { |k,v| v > 0} .keys
		unless stock_available_to_sell.empty?
			actions << :sell_stocks
		end

		# cancel order action
		orders_to_cancel = []
		orders_to_cancel += @my_orders[:sell].keys
		orders_to_cancel += @my_orders[:buy].keys
		
		
		unless orders_to_cancel.empty?
			actions << :cancel_order
		end

		
		
		# Means that agent is broke.
		return false if actions.empty? 

		case actions.sample  
			when :cancel_order
				orderId = orders_to_cancel.sample 
				puts "Canceling order order_id = #{orderId}"
				@socket.print CancelOrderReq.new(orderId).forge
			when :buy_stocks
				stockId = stock_available_to_buy.sample 
				puts "Buying new stockid = #{stockId}"
				#puts "Something wrong happend while buying..." if not buyStock(stockId, @coef_price_increase)
			when :sell_stocks
				stockId = stock_available_to_sell.sample 
				puts "Selling stock_id = #{stockId}"
				#puts "Something wrong happend while selling..." if not sellStock(stockId, @coef_price_decrease)			
			else
				raise "Unknown random action ? #{value}" 
			end
		true
	end
	
	
	def processMessage!
		begin
			packet = readPacketFromBuffer!
		rescue
			return false
		end
		# When best offer => update best_offers and recompute best_offers_grad
		begin
		case packet.id
			when $packets[:BEST_ORDER] then
				#puts "BEST OFFER!"
				best_order = BestOrder.new(packet.get)
				val = OpenStruct.new(:amount => best_order.amount, :price => best_order.price)
				# If only the price is considered is easy to trick agents into massive selling
				# their stocks.
				stockId = best_order.stock_id
				changed = best_order.amount * best_order.price
			
				order_type = TO_ORDER_TYPE[best_order.type]
				
				old_ppsd, old_best_offer = @best_offers[order_type].fetch(stockId, [0.0, OpenStruct.new(:amount => 0, :price => 0)])
				new_best_offer = val
				@best_offers[order_type].merge! stockId => new_best_offer 
				#puts @best_offers[order_type][stockId]
				# Percentage loss\rise
				# no best offers, all gone!
				if new_best_offer.price == 0
				
				else
					ppsd = (old_best_offer.price.to_f * old_best_offer.amount.to_f + new_best_offer.price.to_f * new_best_offer.amount.to_f) / (new_best_offer.amount.to_f * old_best_offer.amount.to_f) 	
					if old_ppsd == 0.0:
						@best_offers_grad[order_type].update({stockId => [ppsd, 0.0]})
					else
						grad = (ppsd - old_ppsd) / (old_ppsd)
						@best_offers_grad[order_type].update({stockId => [ppsd, grad]})
				end
				#puts @best_offers
				#puts "\n", @best_offers_grad, "\n"
			when $packets[:BUY_TRANSACTION] then
				puts "BUY TRANSACTION"
				buy_transaction = BuyTransaction.new(packet.get)
				
				if not @my_orders[:buy].include? buy_transaction.order_id
					#puts "Probably have broken data"
				elsif buy_transaction.amount == 0 
					@my_orders[:buy].delete(buy_transaction.order_id)
				else
					@my_orders[:buy][buy_transaction.order_id] = buy_transaction.amount
				end
			when $packets[:SELL_TRANSACTION] then
				puts "SELL TRANSACTION"
				sell_transaction = SellTransaction.new(packet.get)

				if not @my_orders[:sell].include? sell_transaction.order_id
					#puts "Probably have broken data"
				elsif sell_transaction.amount == 0
					@my_orders[:sell].delete(sell_transaction.order_id)
				else
					@my_orders[:sell][sell_transaction.order_id] = sell_transaction.amount
				end
			when $packets[:GET_MY_STOCKS_RESP] then
				#puts "GET STOCKS"
				my_stocks_packet = GetMyStocksResp.new(packet.get)
				temp_hash = my_stocks_packet.stockhash
				
				@my_money = temp_hash[1]		#
				temp_hash.delete(1)			#
				@my_stocks = temp_hash
			when $packets[:GET_MY_ORDERS_RESP] then
				#puts "GET ORDERS"
				@my_orders = {:sell => {}, :buy => {}}
				my_orders_packet = GetMyOrdersResp.new(packet.get)
				my_orders_packet.orderlist.each { 
						|type, order_id, stock_id, amount, price|
										val = OpenStruct.new(:stock_id => order_id, :amount => amount, :price => price)
										@my_orders[TO_ORDER_TYPE.fetch(type)].merge! order_id => val
										}
				
				#puts "\nmy orders:\n#{@my_orders.to_s}\n"
			#else
				#puts "Unknown message. #{packet.id}"
			end
			rescue Exception => e
				puts "Probably malformed packet from server (shouldn't happen) #{e}"
			end
		true	
	end
end


