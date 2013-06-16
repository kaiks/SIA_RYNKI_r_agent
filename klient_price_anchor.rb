Thread.abort_on_exception = true

require 'klient.rb'

class DumbClient < StockClient
  def initialize(password=nil, user_id=0)
    @stock = {}
    @gauss = RandomGaussian.new(0.02,0.007)
    $csv.each_key { |k| @stock[k] = StockInfo.new }
    super(password, user_id)
    @expected_gain = @gauss.rand
    @expected_bargain = -@gauss.rand
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
    @stock[packet.stock_id].i_sold_for = @stock[packet.stock_id].transaction_price*(1.0+@expected_gain)
    @stock[packet.stock_id].i_bought_for = @stock[packet.stock_id].transaction_price*(1.0+@expected_bargain)
  end


  def on_get_my_stocks_resp packet
    say "My stocks: #{@my_stocks.to_s}"
    @my_stocks.each_key { |k|
      if k>1
        send GetStockInfo.new(k).forge
        if @stock[k].initialized && (@stock[k].i_sold_for.to_i > 0) && (@stock[k].i_bought_for.to_i > 0)
          say "SI ISF #{@stock[k].i_sold_for}"
          say "SI IBF #{@stock[k].i_bought_for}"
          if cash>@stock[k].i_bought_for
            buy_for(k, @stock[k].i_bought_for, 0.5)
          end
          sell_all_stocks(k,@stock[k].i_sold_for)
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
      say "Change prices: EG #{@expected_gain} EB #{@expected_bargain}"
      say "...#{packet.sell_price}"
      @stock[packet.stock_id].i_sold_for = (packet.sell_price)*(1.0+@expected_gain)
      @stock[packet.stock_id].i_bought_for = (packet.buy_price)*(1.0+@expected_bargain)
    end

  end


  def on_best_order packet
    @stock[packet.stock_id].fromBestOrder packet
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

ARGV[0].to_i.times { |i|
  @klienci << Thread.new {
    sleep(1.0*rand(100)/10.0)
    DumbClient.new('%06d' %(i+900))
  }
}

sleep(1000000)