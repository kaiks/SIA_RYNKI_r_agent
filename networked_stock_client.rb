require 'set'
require 'socket'

class NetworkedStockClient
  def initialize(password=nil, user_id=0)

    @id       = user_id
    @password = password

    setup_socket
    setup_variables

    post_init
  end

  def setup_variables
    @buffer    = ''
    @my_stocks = Hash.new
    @my_orders = Set.new
    @threads   = Set.new
    @sendlock  = Mutex.new
    @debug     = false
    @last_received     = Time.now #dumb congestion prevention
  end



  def setup_socket
    @socket = TCPSocket.new $host, $port
    @socket.setsockopt(Socket::IPPROTO_TCP,Socket::TCP_NODELAY,1)
  end

  def run
    loop {
      check_connection_by_time

      data = @socket.readpartial(4096)
      receive_data data if data.to_s.length>0

      sleep(0.05)
    }
  end


  def check_connection_by_time
    if @last_received < Time.now-30
      raise 'No information in 30 seconds.'
    end
  end

  def post_init
    @threads << Thread.new { run }

    send @id == 0 ?
             RegisterUserReq.new(@password).forge :
             LoginUserReq.new(@id, @password).forge
  end

  def receive_data(data)
    say "received data #{data.length}"
    @buffer += data.to_s

    while @buffer.length > 2 do
      @last_received = Time.now
      packet = StockPacketIn.new(@buffer[0..32768])
      say "packet len #{packet.packetlen}"

      #zabezpieczenie przed fragmentacja
      if packet.packetlen+2 > @buffer.length
        say 'Packet not long enough'
        break
      end

      @buffer = @buffer[(2+packet.packetlen)..@buffer.length].to_s

      case packet.id
        when $packets[:REGISTER_USER_RESP_OK] then
          packet = RegisterUserRespOk.new(packet.get)
          @id = packet.user_id
          say "Registered: #{packet.user_id}"
          send LoginUserReq.new(@id, @password).forge
          on_register_user_resp_ok packet

        when $packets[:REGISTER_USER_RESP_FAIL] then
          packet = RegisterUserRespFail.new(packet.get)
          say "Register FAIL: #{packet.reason}"
          on_register_user_resp_fail packet

        when $packets[:LOGIN_USER_RESP_OK] then
          say 'Login OK'
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
          self.on_best_order packet

        when $packets[:GET_MY_STOCKS_RESP] then
          packet = GetMyStocksResp.new(packet.get)
          @my_stocks.each_value { |stock| stock.amount = 0 }
          @my_stocks.merge!(packet.stockhash)
          @my_stocks.each_value{ |stock| stock.trading = true }
          say "Received my stocks info #{@my_stocks.to_s}"
          on_get_my_stocks_resp(packet)

        when $packets[:GET_MY_ORDERS_RESP] then
          packet = GetMyOrdersResp.new(packet.get)
          @my_orders = packet.orderlist
          say 'Received my orders info'
          on_get_my_orders_resp packet

        when $packets[:GET_STOCK_INFO_RESP] then
          packet = GetStockInfoResp.new(packet.get)
          say 'Received stock info'
          on_get_stock_info_resp packet

        else
          say "Unknown packet: ID=#{packet.id} #{packet.bytearray}"

      end
    end
  end

  def send_data data
    @sendlock.synchronize {
      @socket.write data
    }
  end

  def say something
    if @debug
      puts "#{Time.now} [#{@id.to_s}]: #{something}"
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

end