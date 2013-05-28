require 'rubygems'
require 'eventmachine'

require 'packets.rb'

require 'csvreader.rb'

sleep(10)
class Client < EventMachine::Connection
  def initialize(password=nil, user_id=0)
    @id = user_id
    @password = password
    @buffer = ''
    say "Hello. Im #{user_id} (#{password})"
  end

  def post_init
    puts @password
    puts @user_id
    if @id == 0
      send_data RegisterUserReq.new(@password).forge
    else
      send_data LoginUserReq.new(@id, @password).forge
    end
  end

  def receive_data(data)
    @buffer += data
    puts 'recv'
    while !@buffer.nil? do
      if @buffer.length<2
          break
      end
      #puts "#Received packet: #{@buffer.length } #{@buffer.unpack('c*')}"
      packet = StockPacketIn.new(@buffer)
      #puts "p #{packet.bytearray} #{packet.bytearray.length} #{packet.packetlen}"
      @buffer = @buffer[(2+packet.packetlen)..@buffer.length]
      case packet.id
        when $packets[:REGISTER_USER_RESP_OK] then
          packet = RegisterUserRespOk.new(packet.get)
          @id = packet.user_id
          say "Registered: #{packet.user_id}"

        when $packets[:REGISTER_USER_RESP_FAIL] then
          packet = RegisterUserRespFail.new(packet.get)
          say "Register FAIL: #{packet.reason}"

        when $packets[:LOGIN_USER_RESP_OK] then
          say "Login OK"
          EventMachine.defer proc { self.send_buy_orders }
          EventMachine.defer proc { self.send_sell_orders }

        when $packets[:LOGIN_USER_RESP_FAIL] then
          packet = LoginUserRespFail.new(packet.get)
          say "Login FAIL: #{packet.reason}"

        when $packets[:SELL_TRANSACTION] then
          packet = SellTransaction.new(packet.get)
          say "Sell transaction: #{packet.stock_id} #{packet.amount}"

        when $packets[:BUY_TRANSACTION] then
          packet = BuyTransaction.new(packet.get)
          say "Buy transaction: #{packet.stock_id} #{packet.amount}"

        when $packets[:TRANSACTION_CHANGE] then
          packet = TransactionChange(packet.get)
          say "Transaction: #{packet.stock_id} #{packet.amount} #{packet.price} #{packet.date}"

        when $packets[:ORDER] then
          packet = Order.new(packet.get)
          say "New order: #{packet.type} #{packet.stock_id} #{packet.amount} #{packet.price}"

        when $packets[:BEST_ORDER] then
          packet = BestOrder.new(packet.get)
          say "New best order: #{packet.type} #{packet.stock_id} #{packet.amount} #{packet.price}"

        else
          say "Unknown packet: #{packet.id} #{packet.bytearray}"

      end
    end
  end

  def say something
    puts "[#{@id}]: #{something}"
  end

  def send_buy_orders
    $csv.each_value { |stock|
      order = BuyStockReq.new
      #say "Trying to buy #{stock['id_zasobu']} #{stock}"
      order.stock_id = stock['id_zasobu']
      order.amount = 1000
      order.price = stock['cena']-5
      send_data order.forge
    }
  end

  def send_sell_orders
    $csv.each_value { |stock|
      order = SellStockReq.new
      #say "Trying to sell #{stock['id_zasobu']} #{stock}"
      order.stock_id = stock['id_zasobu']
      order.amount = 1000
      order.price = stock['cena']+5
      #puts "!! #{order.forge.unpack('C*')}"
      send_data order.forge
    }
  end
end

EventMachine.run {
  EventMachine.set_quantum 10
  EventMachine.connect '127.0.0.1', 12345, Client, 'abcdef', 1
}