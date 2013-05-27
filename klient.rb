require 'rubygems'
require 'eventmachine'

require 'packets.rb'

class Client < EventMachine::Connection
  def initialize(password=nil,user_id=0)
    @id = user_id
    @password = password
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

  def receive_data(data)
    packet = StockPacketIn.new(data)

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

      when $packets[:LOGIN_USER_RESP_FAIL] then
        packet = LoginUserRespFail.new(packet.get)
        say "Login FAIL: #{packet.reason}"

      when $packets[:SELL_TRANSACTION] then
        packet = SellTransaction.new(packet.get)
        say "Sell transaction: #{packet.stock_id} #{packet.amount}"

      when $packets[:BUY_TRANSACTION] then
        packet = BuyTransaction.new(packet.get)
        say "Buy transaction: #{packet.stock_id} #{packet.amount}"

      else
        say "Unknown packet: #{packet.id} [#{packet.bytearray}]"

    end
  end

  def say something
    puts "[#{@id}]: #{something}"
  end
end

EventMachine.run {
  EventMachine.connect '127.0.0.1', 12345, Client,'abfdef',1
  EventMachine.connect '127.0.0.1', 12345, Client,'qwerty',2
}