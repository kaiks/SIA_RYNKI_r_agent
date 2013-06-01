require 'rubygems'
require 'eventmachine'

require 'packets.rb'

require 'csvreader.rb'

class SClient < EventMachine::Connection
  def initialize(password=nil,user_id=0)
    @id = user_id
    @password = password
    @buffer = ''
    @my_stocks = {}
  end

  def post_init
    puts @password
    puts @user_id
    if @id == 0
      send_data RegisterUserReq.new(@password).forge
    else
      send_data LoginUserReq.new(@id,@password).forge
    end
  end

  def cash
    @my_stocks[1]
  end

  def receive_data(data)
    @buffer += data||''
    while !@buffer.nil? do
      if @buffer.length<2
        break
      end
      packet = StockPacketIn.new(@buffer)
      @buffer = @buffer[(2+packet.packetlen)..@buffer.length]
      case packet.id
        when $packets[:REGISTER_USER_RESP_OK] then
          packet = RegisterUserRespOk.new(packet.get)
          @id = packet.user_id
          say "Registered: #{packet.user_id}"
          send_data LoginUserReq.new(@id,@password).forge
          EventMachine.defer proc { on_register_user_resp_ok packet }

        when $packets[:REGISTER_USER_RESP_FAIL] then
          packet = RegisterUserRespFail.new(packet.get)
          say "Register FAIL: #{packet.reason}"
          EventMachine.defer proc { on_register_user_resp_fail packet }

        when $packets[:LOGIN_USER_RESP_OK] then
          say "Login OK"
          EventMachine.defer proc { on_login_user_resp_ok packet }

        when $packets[:LOGIN_USER_RESP_FAIL] then
          packet = LoginUserRespFail.new(packet.get)
          say "Login FAIL: #{packet.reason}"
          EventMachine.defer proc { on_login_user_resp_fail packet }

        when $packets[:SELL_TRANSACTION] then
          packet = SellTransaction.new(packet.get)
          say "Sell transaction: #{packet.stock_id} #{packet.amount}"
          EventMachine.defer proc { on_sell_transaction packet }

        when $packets[:BUY_TRANSACTION] then
          packet = BuyTransaction.new(packet.get)
          say "Buy transaction: #{packet.stock_id} #{packet.amount}"
          EventMachine.defer proc { on_buy_transaction packet }

        when $packets[:TRANSACTION_CHANGE] then
          packet = TransactionChange(packet.get)
          say "Transaction: #{packet.stock_id} #{packet.amount} #{packet.price} #{packet.date}"
          EventMachine.defer proc { on_transaction_change packet }

        when $packets[:ORDER] then
          packet = Order.new(packet.get)
          say "New order: #{packet.type} #{packet.stock_id} #{packet.amount} #{packet.price}"
          EventMachine.defer proc { on_order packet }

        when $packets[:BEST_ORDER] then
          packet = BestOrder.new(packet.get)
          say "New best order: #{packet.type} #{packet.stock_id} #{packet.amount} #{packet.price}"
          EventMachine.defer proc { on_best_order packet }

        when $packets[:STOCK_INFO] then
          packet = StockInfo.new(packet.get)
          @my_stocks[packet.stock_id] = packet.amount
          say "My stock info: #{packet.packetlen} #{packet.stock_id} #{packet.amount}"
          EventMachine.defer proc { on_best_order packet }

        else
          say "Unknown packet: #{packet.id} #{packet.bytearray}"

      end
    end
  end

  def on_register_user_resp_ok packet

  end

  def on_register_user_resp_fail packet

  end

  def on_login_user_ok packet

  end

  def on_login_user_resp_fail packet

  end

  def on_sell_transaction packet

  end

  def on_buy_transaction packet

  end

  def on_transaction_change packet

  end

  def on_order packet

  end

  def on_best_order packet

  end


  def say something
    puts "[#{@id}]: #{something}"
  end
end

=begin
EventMachine.run {
  EventMachine.connect '127.0.0.1', 12345, Client,'abfdef',1
  EventMachine.connect '127.0.0.1', 12345, Client,'qwerty',2
}
=end