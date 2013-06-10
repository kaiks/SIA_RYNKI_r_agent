require 'socket'
require 'ostruct'
require './packets.rb'

$host = 'localhost'
$port = 12345

class SimpleAgent
	attr_accessor :password, :id, :max_idle, :sleep_time, :reconnect_trials, :my_stocks, :my_orders, :my_money

    def self.createInstance(id, password, data)
		if data[:sleep_time] == nil
			raise "sleepTime is nil"
		elsif data[:max_idle] == nil
			raise "max_idle is nil"
		elsif id == nil
			raise "id is nil"
		elsif password == nil
			raise "password is nil"
		end
		
		inst = self.new
		inst.sleep_time = data[:sleep_time]
		inst.max_idle = data[:max_idle]
		
		inst.id = id
		inst.password = password
		inst.my_stocks = {}		# id => quantity
		inst.my_orders = {:buy => {}, :sell => {}}
		inst.my_money = 0
		inst.reconnect_trials = 3
		inst
    end

    def processMessages!
		# this is called after newData!, so all incoming data is already in the @buffer
		puts "#{id} processes messages..."
		while processMessage!
		end
    end
	
	def processMessage!	
	end

	def connectionAlive?
		begin
			@socket.recv(0)
			return true
		rescue Exception => e
			puts e
			return false
		end
	end
	
	def act!
		puts "#{id} acts!"
	end
	
	def randomAct!
		puts "#{id} randomly acts!"
	end

	def start!
		@buffer = ''
		if not tryConnect
			puts "#{id} can't connect to host"
			return nil
		end
		if not loginUser
			puts "#{id} can't log in."
			return nil
		end
        iterations = 0
        while true
            if connectionAlive?
                if newData!
                    processMessages
                    act!
                else
                    iterations += 1
                    if iterations >= @max_idle
                        randomAct!
                        iterations = 0
                    end
                end    
            else
				if not tryConnect
					puts "#{id} can't connect to host"
					return nil
				end
				if not loginUser
					puts "#{id} can't log in."
					return nil
				end
                iterations = 0
            end
			puts "#{id} sleeps"
            sleep @sleep_time
        
        end
    end
      
	def loginUser
		puts id.to_s + " tries to login!"
		@socket.print LoginUserReq.new(id, password).forge
		
		sock, = IO.select [@socket], [], [], 3
		if sock[0] == nil
			puts "Timeout!"
			return false
		end
		
		# :-(	
		loginAnswer = tryReadWholePacket 1, 3
		case loginAnswer.id
			when $packets[:LOGIN_USER_RESP_OK] then
				puts "#{id} logged succesfuly"
			when $packets[:LOGIN_USER_RESP_FAIL] then
				packet = LoginUserRespFail.new(loginAnswer.get)
				puts "#{id} login FAIL: #{packet.reason}"
				return false
			else
				puts "Somethings very wrong!"
				return false
		end
		
		return false if not myStocks
		return false if not myOrdersAndMoney
		true
	end
	
	def myStocks
		@socket.print GetMyStocks.new.forge
		
		sock, = IO.select [@socket], [], [], 3
		if sock[0] == nil
			puts "Timeout!"
			return false
		end
		
		# :-(	
		packet = tryReadWholePacket 1, 3
		
		case packet.id
			when $packets[:GET_MY_STOCKS_RESP] then
				my_stocks_packet = GetMyStocksResp.new(packet.get)
				temp_hash = my_stocks_packet.stockhash
				
				my_money = temp_hash[1]		#
				temp_hash.delete(1)			#
				my_stocks = temp_hash
				puts "I have #{my_money} money  and #{my_stocks} stocks"
			else
				puts "Somethings very wrong!"
				return false
		end
		true
	end
	
	def myOrdersAndMoney
		@socket.print GetMyOrders.new.forge
		
		sock, = IO.select [@socket], [], [], 3
		if sock[0] == nil
			puts "Timeout!"
			return false
		end
		
		# :-(	
		packet = tryReadWholePacket 1, 3
		my_orders = {:buy => {}, :sell => {}}
		case packet.id
			when $packets[:GET_MY_ORDERS_RESP] then
				my_orders_packet = GetMyOrdersResp.new(packet.get)
				my_orders_packet.orderlist.each { 
						|type, order_id, stock_id, amount, price|
										val = OpenStruct.new(:order_id => order_id, :amount => amount, :price => price)
										if type == 1
											my_orders[:buy].merge! stock_id => val
										elsif type == 2
											my_orders[:sell].merge! stock_id => val
										else
											puts "UNDEFINED ORDER TYPE"
										end
										}
				puts my_orders
			else
				puts "Somethings very wrong!"
				return false
		end
		true
	end
	
	def tryConnect
		sec_sleep = 0.1
		@reconnect_trials.times do |value|
									begin
										@socket = TCPSocket.new $host, $port
										return true
									rescue Exception => e
										puts e
										sleep (sec_sleep * (1 << value))
									end
								end
		false
	end
	
	def newData!
		begin
			segment = @socket.recv_nonblock 256
		rescue Exception => e
			#puts "#{id}: Nothing to read in the first place."
			return false
		end
		
		@buffer << segment
		
		while true
			begin
				segment = @socket.recv_nonblock 256
			rescue Exception => e
				#puts "#{id} Nothing  left to read"
				break
			end
			@buffer << segment
		end
		true
	end
	
	def readPacketFromBuffer!
		packet = StockPacketIn.new @buffer[0..512]
		raise "msg too short" if @buffer.length < (packet.packetlen + 1)
		@buffer.slice! 0..(packet.packetlen + 1)
		packet
	end
	
	def tryReadWholePacket(time_interval, retry_count)
		begin
			newData!				# Wczyta calosc do bufora
			return readPacketFromBuffer!
		rescue Exception => e
			puts e
			sleep time_interval
			retry_count -= 1
			if retry_count > 0
				retry
			else
				raise e
			end
		end
	end
end

class IrrationalPanicAgent <SimpleAgent
	attr_accessor :percentage_price_decrease, :percentage_price_increase, :best_offers, :best_offers_grad,
				  :percent_money_when_buying, :rand_for_action, :subscribed, :subscribed_count,
				  :when_to_sell_increasing, :when_to_sell_decreasing, :when_to_buy_increasing,
				  :when_to_buy_decreasing
    def self.createInstance(id, password, data)
		inst = super.createInstance(id, password, data)
		
		if data[:percentage_price_decrease] == nil
			raise "percentage_price_decrease is nil"
		elsif data[:percentage_price_increase] == nil
			raise "percentage_price_increase is nil"
		elsif data[:percent_money_when_buying] == nil
			raise "percent_money_when_buying is nil"
		elsif data[:percentage_price_increase] == nil
			raise "percentage_price_increase is nil"
		elsif data[:subscribed_count] == nil
			raise "subscribed_count is nil"
		elsif data[:when_to_sell_increasing] == nil
			raise "when_to_sell_increasing is nil"
		elsif data[:when_to_sell_decreasing] == nil
			raise "when_to_sell_decreasing is nil"
		elsif data[:when_to_buy_increasing] == nil
			raise ":when_to_buy_increasing is nil"
		elsif data[:when_to_buy_decreasing] == nil
			raise "when_to_buy_decreasing is nil"
		end
		
		percentage_price_decrease = data[:percentage_price_decrease]
		percentage_price_increase = data[:percentage_price_increase]
		percent_money_when_buying = data[:percent_money_when_buying]
		percentage_price_increase = data[:percentage_price_increase]
		when_to_sell_increasing] = data[:when_to_sell_increasing]
		when_to_sell_decreasing = data[:when_to_sell_decreasing]
		when_to_buy_increasing = data[:when_to_buy_increasing]
		when_to_buy_decreasing = data[:when_to_buy_decreasing]
		subscribed_count = data[:subscribed_count]
		
		rand_for_action = Random.new	
		subscribed = {}
		
		best_offers = {:sell => {}, :buy => {}}
		best_offers_grad = {:sell => {}, :buy => {}}
		
	end
	def loginUser
		super.loginUser
		# Get stock Ids from offers
		# an select at random (subscribed_count - #(stock ids from my offers)) stockIds
		# to which you'll subscribe
	end
	
	def act!
	end
	
	def randomAct!
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
				h = {best_order.stockId => best_order.price}
				
				if best_order.type == 1
					best_offers[:buy].merge! best_order.stockId => val
					best_offers_grad[:buy].merge!(h) { |key, old, new| new - old }
				elsif best_order.type == 2
					best_offers[:sell].update! best_order.stockId => val
					best_offers_grad[:sell].merge!(h) { |key, old, new| new - old }
				else
					puts "UNDEFINED ORDER TYPE"
				end
			else
				puts "Something's very wrong!"
				return false
			end
		true	
	end
end


