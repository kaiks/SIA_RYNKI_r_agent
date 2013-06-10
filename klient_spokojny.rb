require 'klient.rb'

class DumbClient < StockClient
  def initialize(password=nil, user_id=0)
    @stock = {}
    $csv.each_key { |k| @stock[k] = StockInfo.new }
    super(password, user_id)
    @expected_gain = random(0.01 .. 0.25)
    @greedy_gain   = 1.5
    @expected_bargain = -random(0.01 .. 0.25)
    say "Expected gain: #{@expected_gain.to_s} bargain: #{@expected_bargain.to_s}"
    @debug = true
  end


  def on_login_user_resp_ok packet
    @threads << Thread.new {
      loop {
        sleep(random(10)+10)
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
        if @stock[k].initialized && (@stock[k].i_sold_for.to_i > 0) && (@stock[k].i_bought_for.to_i > 0)
          say "SI ISF #{@stock[k].i_sold_for}"
          say "SI IBF #{@stock[k].i_bought_for}"
          timer(60) {
            buy_for(k, @stock[k].i_sold_for, 0.5)
            buy_for(k, @greedy_gain*@stock[k].i_sold_for, 0.5)
            sell_all_stocks(k,@stock[k].i_bought_for)
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
    stock_id = random(2 .. 21)
    unless stock(stock_id).trading?
      send GetStockInfo.new(stock_id).forge
      buy(stock_id,1,cash)
    end

  end


  def on_get_my_orders_resp packet
    say "My orders: #{@my_orders.to_s}"
  end


  def on_get_stock_info_resp packet
    say "Stock info: #{packet.to_s}"

    must_establish_price=false

    unless @stock[packet.stock_id].initialized
      say 'stock uninitialized'
      must_establish_price=true
    end

    @stock[packet.stock_id].fromStockInfo packet

    if (must_establish_price) or (@stock[packet.stock_id].i_sold_for.to_i == 0) or (@stock[packet.stock_id].i_bought_for.to_i == 0)
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



  def buy_for(stock, price, perc=1.00)
    say "Buy for: #{stock} #{price}"
    buy(stock, (perc*cash/price).to_i, price)
  end


  def panic_sell(stock_id)
    @stock[stock_id].i_sold_for *= 0.9

    timer( random(1 .. 5) ) {
      sell_pkc(stock_id, amount(stock_id) )
    }
  end


end

@klienci = []

100.times { |i|
  @klienci << Thread.new {
    sleep(1.0*rand(100)/10.0)
    DumbClient.new('%06d' %(i+900), i+900)
  }
}

sleep(1000000)