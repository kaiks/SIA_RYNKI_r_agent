require 'Agent'

require 'stockInformation.rb'


class IrrationalPanicAgent < SimpleAgent
	attr_accessor :coef_price_decrease, :coef_price_increase, :best_offers, :best_offers_grad,
				  :coef_money_when_buying, :coef_orders_when_selling, :subscribed_count,
				  :rand_for_action, :subscribed
    
	def self.generateRandomCoef(rand_gen = Random.new, coef_dict = {})
		
		dict = super(rand_gen, coef_dict)
		
		#coef_price_decrease 
		cpd_min, cpd_max = coef_dict.fetch(:coef_price_decrease, [-0.15, -0.01])
		#coef_price_increase 
		cpi_min, cpi_max = coef_dict.fetch(:coef_price_increase, [0.01, 0.15])
		#coef_money_when_buying 
		cmwb_min, cmwb_max = coef_dict.fetch(:coef_money_when_buying,[0.05, 1])
		#coef_orders_when_selling
		cows_min, cows_max = coef_dict.fetch(:coef_orders_when_selling, [0.05, 1])
		#subscribed_count 
		sc_min, sc_max = coef_dict.fetch(:subscribed_count, [1, 20])
		
		coefs = {:coef_price_decrease => rand_gen.rand(cpd_min..cpd_max),
				 :coef_price_increase => rand_gen.rand(cpi_min..cpi_max),
				 :coef_money_when_buying => rand_gen.rand(cmwb_min..cmwb_max),
				 :coef_orders_when_selling => rand_gen.rand(cows_min..cows_max),
				 :subscribed_count => rand_gen.rand(sc_min..sc_max)}
		
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
		raise "subscribed_count <= 0" unless inst.subscribed_count > 0
		
		inst.rand_for_action = Random.new	
		inst.subscribed = []
		
		inst.best_offers = {:sell => {}, :buy => {}}
		inst.best_offers_grad = {:sell => {}, :buy => {}}
		inst
	end

	def loginUser
		return false if not super
		#High time to chose subscriptions! 
		if @subscribed.empty?
			@subscribed = $stock_info.keys.sample(@subscribed_count)
			raise "my_stocks.length != 1. Something very wrong! #{@my_stocks}" unless @my_stocks.length == 1 
			my_gift_stock, = @my_stocks.keys	
			@subscribed[-1] = my_gift_stock unless @subscribed.include? my_gift_stock 
		end
		subscribe subscribed
		true
	end	
	
	def buyStock(stockId, price_change_coef)
		#puts "Time to buy some stock #{stockId} #{price_change_coef}"
		computed_money = (@my_money * @coef_money_when_buying).to_i 
		money = @my_money
		money = computed_money unless computed_money <= 0
		
		return false unless money >= 0
		
		# Will buy for a little bit more than the best offer suggests.
		price_per_stock = Random.new.rand 1..(@my_money / 10) 
		if @best_offers[:buy].include? stockId
			price_per_stock = [@best_offers[:sell][stockId].price + (@best_offers[:sell][stockId].price * price_change_coef).to_i, 1].max
		end
		raise "buyStock: money #{money} and price per stock #{price_per_stock}" unless price_per_stock > 0 
		
		stock_amount = [money / price_per_stock, $stock_info[stockId]['l_akcji']].min
		
		return false unless stock_amount > 0
		
		
		@socket.print BuyStockReq.new(stockId, stock_amount, price_per_stock).forge  
		# should probably wait for an id of new  order 
		@my_money -= stock_amount * price_per_stock
		##puts "Ordered to buy #{stock_amount} of id=#{stockId} for #{price_per_stock} per stock" 
		true
	end

	def sellStock(stockId, price_change_coef)
		#puts "Time to sell some stock #{stockId} #{price_change_coef}"
		computed_stock_amount = (@my_stocks[stockId] * @coef_orders_when_selling).to_i
		
		stock_amount = @my_stocks[stockId]
		stock_amount = computed_stock_amosunt unless computed_stock_amount < 0
		
		return false unless stock_amount > 0
		# Will sell for a little bit less than the best offer suggests
		price_per_stock = Random.new.rand 1...100
		if @best_offers[:buy].include? stockId
			price_per_stock = [@best_offers[:buy][stockId].price + (@best_offers[:buy][stockId].price * price_change_coef).to_i, 1].max
		end
		raise "sellStock: stocks[#{stockId}] = #{@my_stocks[stockId]} and price per stock #{price_per_stock}" unless price_per_stock > 0 
		
		@socket.print SellStockReq.new(stockId, stock_amount, price_per_stock).forge
		# should probably wait for an id of new  order
		@my_stocks[stockId] -= stock_amount
		##puts "Ordered to sell #{stock_amount} of id=#{stockId} for #{price_per_stock} per stock" 
		true
	end
	
	def act
		#	If agent has money and there are some orders which are good enough to buy => buy one
		#	If agent has some stocks which are good enough to sell => sell one
		puts "Time to act!"
		updateOrdersAndStocks!
		sell_candidates_higher = best_offers_grad[:buy].select { |stockId, diff_perc| 
									 diff_perc > @coef_price_increase and @my_stocks.include? stockId}
		
		#sell_candidates_panic = best_offers_grad[:buy].select 
		#							{|stockId, diff_perc| 
		#							 diff_perc < @coef_price_decrease and my_stocks.include? stockId}			 
		
		#buy_candidates_higher = best_offers_grad[:sell].select 									
		#							{|stockId, diff_perc| 
		#							 diff_perc > @coef_price_increase and my_stocks.include? stockId}
		
		buy_candidates_panic = best_offers_grad[:sell].select {|stockId, diff_perc| 
									 diff_perc < @coef_price_decrease}

		action_sell = false
		action_buy = false
		sell_candidate_higher.each {|stockId| action_sell ||= sellStock(stockId, @coef_price_increase)}
		#sell_candidate_panic.each { |stockId| sellStock(stockID, @coef_price_decrease)}
		#buy_candidate_higher.each {|stockId| sellStock(stockId, @coef_price_increase)}
		buy_candidate_panic.each { |stockId| action_buy ||= buyStock(stockID, @coef_price_decrease)}
		
		# If false then it means there was no action
		action_sell and action_buy
	end
	
	def randomAct!
		#puts "Time to act randomly!"
		# Create available actions and then choose sample one.
		actions = []
		#puts "Best offers\n:#{@best_offers}\n"
		# cancel order action
		orders_to_cancel = []
		orders_to_cancel += @my_orders[:sell].keys
		orders_to_cancel += @my_orders[:buy].keys
		
		unless orders_to_cancel.empty?
			actions << :cancel_order
		end

		# buy stock action 
		stock_available_to_buy = @best_offers[:sell].select {|stockId, data| data.price < @my_money } .keys
		unless stock_available_to_buy.empty?
			actions << :buy_stocks
		end		
		# sell stock action
		puts @my_stocks.select {|stockId, amount| amount > 0} .keys
		stock_available_to_sell = @my_stocks.select { |k,v| v > 0} .keys
		unless stock_available_to_sell.empty?
			actions << :sell_stocks
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
				puts "Something wrong happend while buying..." if not buyStock(stockId, @coef_price_increase)
			when :sell_stocks
				stockId = stock_available_to_sell.sample 
				puts "Selling stock_id = #{stockId}"
				puts "Something wrong happend while selling..." if not sellStock(stockId, @coef_price_decrease)			
			else
				raise "Unkown random action ? #{value}" 
			end
		true
	end
	
	def updateOrdersAndStocks!
		@socket.print GetMyStocks.new.forge
		@socket.print GetMyOrders.new.forge
		
		sock, = IO.select [@socket], [], [], 3
		if sock[0] == nil
			puts "Timeout!"
			return false
		end
		newData!
		processMessages!
	end
	
	def processMessage!
		begin
			packet = readPacketFromBuffer!
		rescue
			return false
		end
		# When best offer => update best_offers and recompute best_offers_grad
		case packet.id
			when $packets[:BEST_ORDER] then
				best_order = BestOrder.new(packet.get)
				val = OpenStruct.new(:amount => best_order.amount, :price => best_order.price)
				# If only the price is considered is easy to trick agents into massive selling
				# their stocks.
							
				h = {best_order.stockId => best_order.amount * best_order.price}
			
				order_type = TO_ORDER_TYPE[best_order.type]
				@best_offers[order_type].merge! best_order.stock_id => val 
				# Percentage loss\rise
				best_offers_grad[order_type].merge!(h) { |key, old, new| (new - old) / (new.to_f + old.to_f) }
			when $packets[:BUY_TRANSACTION] then
				buy_transaction = BuyTransaction.new(packet.get)
				
				if not @my_orders[:buy].include? buy_transaction.order_id
					puts "Probably have broken data"
				elsif buy_transaction.amount == 0 
					@my_orders[:buy].delete(buy_transaction.order_id)
				else
					@my_orders[:buy][buy_transaction.order_id] = buy_transaction.amount
				end
			when $packets[:SELL_TRANSACTION] then
				sell_transaction = SellTransaction.new(packet.get)

				if not @my_orders[:sell].include? sell_transaction.order_id
					puts "Probably have broken data"
				elsif sell_transaction.amount == 0
					@my_orders[:sell].delete(sell_transaction.order_id)
				else
					@my_orders[:sell][sell_transaction.order_id] = sell_transaction.amount
				end
			when $packets[:GET_MY_STOCKS_RESP] then
				my_stocks_packet = GetMyStocksResp.new(packet.get)
				temp_hash = my_stocks_packet.stockhash
				
				@my_money = temp_hash[1]		#
				temp_hash.delete(1)			#
				@my_stocks = temp_hash
			when $packets[:GET_MY_ORDERS_RESP] then
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
		true	
	end
end


