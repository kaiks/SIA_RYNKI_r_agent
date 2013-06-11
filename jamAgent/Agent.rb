require 'GLOBALS'
require 'socket'
require 'ostruct'
require 'packets.rb'

TO_ORDER_TYPE = {2 => :sell, 1 => :buy} 

class SimpleAgent
	attr_accessor :password, :id, :max_idle, :sleep_time, :reconnect_trials, :my_stocks, :my_orders,
				  :my_money
	
	
	def self.generateRandomCoef(rand_gen = Random.new, coef_dist = {})
		
		sleep_time_min, sleep_time_max = coef_dist.fetch(:sleep_time, [$sleep_time_min, $sleep_time_max])
		max_idle_min, max_idle_max = coef_dist.fetch(:max_idle, [$max_idle_min,$max_idle_max])
		
		{:sleep_time => rand_gen.rand(sleep_time_min..sleep_time_max),
		
		 :max_idle => rand_gen.rand(max_idle_min..max_idle_max)}

	end
    def self.createInstance(id, password, data)
		if id == nil
			raise "id is nil"
		elsif password == nil
			raise "password is nil"
		end
		
		inst = self.new
		inst.sleep_time = data.fetch(:sleep_time)
		inst.max_idle = data.fetch(:max_idle)
		
		inst.id = id
		inst.password = password
		inst.my_stocks = {}		# id => quantity
		inst.my_orders = {:buy => {}, :sell => {}}
		inst.my_money = 0
		inst.reconnect_trials = data.fetch(:reconnect_trials, 3)
		inst
    end
	
	def act!
		#puts "#{id} acts!"
	end
	
	def randomAct!
		true
	end

	def updateOrdersAndStocks!
		@socket.print GetMyStocks.new.forge
		@socket.print GetMyOrders.new.forge
		
		sock, = IO.select [@socket], [], [], $timeout_for_select
		if sock == nil
			puts "#{@id}updateOrdersAndStocks timeouted!"
			return false
		end
		newData!
		processMessages!
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
			# He's broke.
			if @my_money == 0 and @my_orders[:sell].empty? and @my_orders[:buy].empty?
				puts "Agent #{@id} is broke and goes away from the market."
				return nil
			end
            begin
				updateOrdersAndStocks!
                if act!
					ierations = 0
                else
                    iterations += 1
                    if iterations >= @max_idle
                        return nil unless randomAct!
                        iterations = 0
                    end
                end    
            rescue Exception => e
				puts e
				puts "Disconnected..."
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
			#p"#{id} sleeps"
            sleep @sleep_time
        
        end
    end
    
	def loginUser
		#puts id.to_s + " tries to login!"
		@socket.print LoginUserReq.new(id, password).forge
		
		sock, = IO.select [@socket], [], [], $timeout_for_select
		if sock == nil
			puts "Timeout!"
			return false
		end
		
		# :-(	
		loginAnswer = tryReadWholePacket 1, $reading_packet_trials
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
		
		return false if not myStocksAndMoney
		return false if not myOrders
		true
	end
	
	def myStocksAndMoney
		@socket.print GetMyStocks.new.forge
		
		sock, = IO.select [@socket], [], [], $timeout_for_select
		if sock == nil
			puts "#{@id}myStocksAndMoney timeout!"
			return false
		end
		
		# :-(	
		packet = tryReadWholePacket 1, 5
		
		case packet.id
			when $packets[:GET_MY_STOCKS_RESP] then
				my_stocks_packet = GetMyStocksResp.new(packet.get)
				temp_hash = my_stocks_packet.stockhash
				
				@my_money = temp_hash[1]		#
				temp_hash.delete(1)			#
				@my_stocks = temp_hash
				#puts "I have #{@my_money} money  and #{@my_stocks} stocks"
			else
				puts "Somethings very wrong!"
				return false
		end
		true
	end
	
	def myOrders
		@socket.print GetMyOrders.new.forge
		
		sock, = IO.select [@socket], [], [], $timeout_for_select
		if sock == nil
			puts "#{@id} myOrders timeouted!"
			return false
		end
		
		# :-(	
		packet = tryReadWholePacket 1, $reading_packet_trials
		my_orders = {:buy => {}, :sell => {}}
		case packet.id
			when $packets[:GET_MY_ORDERS_RESP] then
				my_orders_packet = GetMyOrdersResp.new(packet.get)
				my_orders_packet.orderlist.each { 
						|type, order_id, stock_id, amount, price|
										val1 = OpenStruct.new(:stock_id => stock_id, :amount => amount, :price => price)	
										my_orders[TO_ORDER_TYPE.fetch(type)].merge! order_id => val
										}
				#puts my_orders
			else
				puts "Somethings very wrong!"
				return false
		end
		true
	end
	
	def subscribe(stockId_list)
		stockId_list.each { |stockId| @socket.print SubscribeStock.new(stockId).forge}
	end
	
	def unsubscribe(stockIds_list)
		stockId_list.each { |stockId| @socket.print UnsubscribeStock.new(stockId).forge}
	end
 
	def processMessages!
		# this is called after newData!, so all incoming data is already in the @buffer
		#puts "#{id} processes messages..."
		while processMessage!
		end
    end
	
	def processMessage!	
	end
	
	def tryConnect
		sec_sleep = 0.5
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
		rescue IO::WaitReadable
			return false
		end
		
		@buffer += segment
		
		while true
			begin
				segment = @socket.recv_nonblock 256
			rescue Exception => e
				#puts "#{id} Nothing  left to read"
				break
			end
			@buffer += segment
		end
		true
	end
	
	def readPacketFromBuffer!
		packet = StockPacketIn.new @buffer[0...16384]
		raise "msg too short" if @buffer.length < (packet.packetlen + 2)
		@buffer.slice! 0..(packet.packetlen+1)
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

