require 'klient.rb'

class DumbClient < SClient
  def initialize(password=nil, user_id=0)
    @debug = true
    Thread.abort_on_exception=true
    say "rzyg"
    @panic_thread = nil
    @stock = {}
    $csv.each_key { |k| @stock[k] = StockInfo.new }
    @expected_gain = 0.05+1.0*rand(25)/100
    @expected_bargain = -(0.05+1.0*rand(25)/100)
    say "Expected gain: #{@expected_gain} bargain: #{@expected_bargain}"
    @debug = true
    super(password, user_id)
    @debug = true
  end


  def on_login_user_resp_ok packet
    @threads << Thread.new {
      Thread.abort_on_exception=true
      loop {
        sleep(rand(10)+10)
        send GetMyStocks.new.forge
        send GetMyOrders.new.forge
      }
    }
  end


  def on_sell_transaction packet
    say 'Ka ching! (sold stuff)'
    send GetMyStocks.new.forge
    send GetMyOrders.new.forge
  end

  def on_buy_transaction packet
    say 'Ka ching! (bought stuff)'
    send GetMyStocks.new.forge
    send GetMyOrders.new.forge
  end

  def on_transaction_change packet
    @stock[packet.stock_id].fromTransactionChange packet
  end


  def on_get_my_stocks_resp packet
    say "My stocks: #{@my_stocks.to_s}"
    @my_stocks.each_key { |k|
      if k>1
        send GetStockInfo.new(k).forge
        if @stock[k].initialized and @stock[k].i_sold_for.to_i > 0 and @stock[k].i_bought_for.to_i > 0
          say "SI ISF #{@stock[k].i_sold_for}"
          say "SI IBF #{@stock[k].i_bought_for}"
          timer(60) {
            buy_for(k, @stock[k].i_sold_for, 0.5)
            buy_for(k, 1.5*@stock[k].i_sold_for, 0.5)
            sell_stock_all(k,@stock[k].i_bought_for)
          }
        else
          send SubscribeStock.new(k).forge
        end
      end
    }

    if @my_stocks.length < 2
      buy_random_stock
    end
  end


  def buy_random_stock
    say 'Buying random stock'

    stock_id = rand(2..21)
    send GetStockInfo.new(stock_id).forge
    buy(stock_id,1,cash)
  end


  def on_get_my_orders_resp packet
    say "My orders: #{@my_orders.to_s}"
  end


  def on_get_stock_info_resp packet
    say "Stock info: #{packet.to_s}"

    establish_price=false

    if @stock[packet.stock_id].initialized==false
      say 'stock uninitialized'
      establish_price=true
    end

    @stock[packet.stock_id].fromStockInfo packet

    if establish_price==true or @stock[packet.stock_id].i_sold_for.to_i == 0 or @stock[packet.stock_id].i_bought_for.to_i == 0
      say 'change prices'
      @stock[packet.stock_id].i_sold_for = (packet.sell_price)*(1.0+@expected_bargain)
      @stock[packet.stock_id].i_bought_for = (packet.buy_price)*(1.0+@expected_gain)
    end

  end


  def on_best_order packet
    @stock[packet.stock_id].fromBestOrder packet
  end


  def fix_selling_price(stock_id, price)
    if @stock[stock_id].i_sold_for.to_i > 0
      @stock[stock_id].i_sold_for
    else
      if @stock[stock_id].sell_price.to_i > 0 #ja sprzedam po tyle po ile ktos inny sprzeda
        @stock[stock_id].i_sold_for = @stock[stock_id].sell_price
      else
        @stock[stock_id].i_sold_for = $csv[stock_id]['cena']*1.05
      end
    end
  end


  def sell_stock_all(stock_id, price, pkc=false)
    say "Sell all: #{stock_id} #{price.to_i}"
    amount = self.stock_amount stock_id
    selling_price = [1, price].max
    if pkc
      say 'PKC sell'
      selling_price=1
    end
    sell(stock_id, amount, selling_price)
  end

  def buy_for(stock, price, perc=1.00)
    say "Buy for: #{stock} #{price}"
    buy(stock, (perc*cash/price).to_i, price)
  end

  def panic_sell(stock_id)
    @stock[stock_id].i_sold_for *= 0.9

    timer(rand(5)+1) {
      sell_stock_all(stock_id, @stock[stock_id].i_sold_for, true)
    }
  end


end

@klienci = []

88.times { |i|
  @klienci << Thread.new {
    Thread.abort_on_exception=true
    sleep(1.0*rand(100)/10.0)
    DumbClient.new('%06d' %(i+402), i+402)
    #EventMachine.connect '127.0.0.1', 12345, DumbClient, '%06d' %(i+2), i+2
  }
}

sleep(1000000)