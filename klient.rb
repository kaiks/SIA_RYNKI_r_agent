require 'rubygems'


require 'packets.rb'

require 'csvreader.rb'
require 'socket'

$host = 'localhost'
$port = 12345

class SClient

  def initialize(password=nil, user_id=0)
    @id = user_id
    @password = password
    @buffer = ''
    @my_stocks = {}
    @my_orders = []
    @socket = TCPSocket.new 'localhost', 12345
    @threads = []
    post_init
    @threads << Thread.new { run }
  end

  def run
    loop { receive_data @socket.readpartial(4096) }
  end

  def post_init
    puts @password
    puts @user_id
    if @id == 0
      send RegisterUserReq.new(@password).forge
    else
      send LoginUserReq.new(@id, @password).forge
    end
    @threads << Thread.new{ loop{say "/loop/#{Time.now} #{@my_stocks.to_s}";sleep(5) } }
  end

  def cash
    @my_stocks[1]
  end

  def receive_data(data)
    if @buffer.nil?
      @buffer = data.to_s
    else
      @buffer += data.to_s
    end
    while !@buffer.nil? do
      if @buffer.length<2
        break
      end
      #puts "Packet stuff #{@buffer.unpack('C*')}"
      packet = StockPacketIn.new(@buffer[0..32768])

      #zabezpieczenie przed fragmentacja
      if packet.packetlen+2 > @buffer.length
        break
      end

      @buffer = @buffer[(2+packet.packetlen)..@buffer.length]
      case packet.id
        when $packets[:REGISTER_USER_RESP_OK] then
          packet = RegisterUserRespOk.new(packet.get)
          @id = packet.user_id
          say "Registered: #{packet.user_id}"
          send_data LoginUserReq.new(@id, @password).forge
          on_register_user_resp_ok packet

        when $packets[:REGISTER_USER_RESP_FAIL] then
          packet = RegisterUserRespFail.new(packet.get)
          say "Register FAIL: #{packet.reason}"
          on_register_user_resp_fail packet

        when $packets[:LOGIN_USER_RESP_OK] then
          say "Login OK"
          on_login_user_resp_ok packet

        when $packets[:LOGIN_USER_RESP_FAIL] then
          packet = LoginUserRespFail.new(packet.get)
          say "Login FAIL: #{packet.reason}"
          on_login_user_resp_fail packet

        when $packets[:SELL_TRANSACTION] then
          packet = SellTransaction.new(packet.get)
          say "Sell transaction: #{packet.stock_id} #{packet.amount}"
          on_sell_transaction packet

        when $packets[:BUY_TRANSACTION] then
          packet = BuyTransaction.new(packet.get)
          say "Buy transaction: #{packet.stock_id} #{packet.amount}"
          on_buy_transaction packet

        when $packets[:TRANSACTION_CHANGE] then
          packet = TransactionChange.new(packet.get)
          say "Transaction: #{packet.stock_id} #{packet.amount} #{packet.price} #{packet.date}"
          on_transaction_change packet

        when $packets[:ORDER] then
          packet = Order.new(packet.get)
          say "New order: #{packet.type} #{packet.stock_id} #{packet.amount} #{packet.price}"
          on_order packet

        when $packets[:BEST_ORDER] then
          packet = BestOrder.new(packet.get)
          say "New best order: #{packet.type} #{packet.stock_id} #{packet.amount} #{packet.price}"
          #say "It's class is #{packet.class}"
          self.on_best_order packet

        when $packets[:GET_MY_STOCKS_RESP] then
          packet = GetMyStocksResp.new(packet.get)
          @my_stocks = packet.stockhash
          @my_stocks
          say "Received my stocks info #{@my_stocks}"
          on_get_my_stocks_resp(packet)
        #EventMachine.defer proc { on_get_my_stocks_resp packet }

        when $packets[:GET_MY_ORDERS_RESP] then
          packet = GetMyOrdersResp.new(packet.get)
          @my_orders = packet.orderlist
          say "Received my orders info"
          on_get_my_orders_resp packet

        when $packets[:GET_STOCK_INFO_RESP] then
          packet = GetStockInfoResp.new(packet.get)
          say "Received stock info"
          on_get_stock_info_resp packet

        else
          say "#{Time.now} Unknown packet: #{packet.id} #{packet.bytearray}"

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

  def on_get_my_stocks_resp packet

  end

  def on_get_my_orders_resp packet

  end

  def on_get_stock_info_resp packet

  end

  def send_data data
    @socket.write data
  end

  def send data
    #if self.error?
    #  say 'Hey, something\'s gone very wrong.'
    #  socket.close
    #else
    if @socket.closed?
      say 'socked closed!!'
    end
    send_data(data)
    #end
  end


  def say something
    puts "#{Time.now} [#{@id}]: #{something}"
  end

  def stock_amount stock_id
    if @my_stocks.has_key? stock_id
      @my_stocks[stock_id]
    else
      0
    end
  end

  def sell(stock_id, amount, price)
    say "Let's sell #{amount} of #{stock_id} for #{price}"
    if amount == 0 || price == 0
      say 'I\'m not going to sell 0 stocks.'
      return
    end
    if stock_amount(stock_id) < amount
      say "Can't sell #{amount} of #{stock_id}. I've got only #{@my_stocks[stock_id]}!"
      return
    end
    if @my_stocks.has_key? stock_id
      @my_stocks[stock_id] -= amount
    end

    say "Selling: stock=#{stock_id} #{amount} for #{price}"
    send SellStockReq.new(stock_id, amount, price).forge
  end

  def buy(stock_id, amount, price)
    say "Let's buy #{amount} of #{stock_id} for #{price}"
    if amount == 0 || price == 0
      say 'I\'m not going to buy 0 stocks.'
      return
    end
    if @my_stocks[1] < price*amount
      say "Can't buy #{amount} of #{stock_id} for total of #{price*amount}. I've got only #{@my_stocks[1]} cash!"
      return
    end
    @my_stocks[1] -= price*amount
    say "Buying: stock=#{stock_id} #{amount} for #{price}"
    send BuyStockReq.new(stock_id, amount, price).forge
  end

  def cancel_order(id)
    say "Cancel order #{id}"
    send CancelOrderReq.new(id).forge
  end

  def timer(sec, &block)
    say "Thread creation"
    Thread.new { sleep(sec); say 'Executing thread'; block.call }
  end
end

=begin
EventMachine.run {
  EventMachine.connect '127.0.0.1', 12345, Client,'abfdef',1
  EventMachine.connect '127.0.0.1', 12345, Client,'qwerty',2
}
=end