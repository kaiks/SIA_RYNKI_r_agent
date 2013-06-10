require './klient.rb'

class DumbClient < StockClient

  def initialize(password=nil, user_id=0, gain = 0.1)
    @stock = {}
    $csv.each_key { |k| @stock[k] = StockInfo.new }
    @expected_gain = gain

    super(password, user_id)
  end



  def on_login_user_resp_ok packet
    @threads << Thread.new {
      loop {
        sleep(random(10 .. 20))
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
    @my_stocks.each_key { |stock_id|
      if stock_id > 1

        if @stock[stock_id].initialized
          buy_for(stock_id, @stock[stock_id].sell_price, 0.5)
        else
          send SubscribeStock.new(stock_id).forge
          send GetStockInfo.new(stock_id).forge
          next
        end

      end
    }
  end



  def on_get_my_orders_resp packet
    say "My orders: #{@my_orders.to_s}"
    @my_orders.each do |order|
      #say "Now doing order #{order.to_s}"
      unless @stock[order[2]].checkInitialized { send GetStockInfo.new(order[2]).forge }
        next
      end

      if order[0].to_i==2
        sell_order_action(order)
      elsif order[0].to_i==1
        buy_order_action(order)
      else
        raise 'Wrong order type'
      end
    end
  end



  def sell_order_action(order)
    @stock[order[2]].i_sold_for = order[4]

    #20% Szansy na panike
    1.in(4) {
      timer( random(2.0 .. 20.0) ) {
        cancel_order(order[1])
        panic_sell(order[2])
      }
    }

    timer( random(1 .. 5) ) {
      say "Hey, let's get more of #{order[2]}"
      get_more_stock(order[2])
    }
  end



  def buy_order_action(order)
    @stock[order[2]].i_bought_for = order[4]

    timer( random(2.0 .. 20.0) ) {
      cancel_order(order[1]) if order[3]>2
      sleep(0.1)

      randval = random(4)

      if randval == 0
        price = random(1.1 .. 1.5) * @stock[order[2]].i_bought_for
        buy_for(order[2], price, 0.5)
      else
        get_more_stock(order[2], true)
      end

    }
  end



  def on_get_stock_info_resp packet
    stock = packet.stock_id
    say "Stock info: #{packet.to_s}"

    @stock[stock].fromStockInfo packet

    timer( random(1 .. 5) ) {
      price = (1.0 - @expected_gain) * packet.sell_price
      price = fix_selling_price(stock, price)
      sell_all_stocks(stock, price)
    }
  end



  def on_best_order packet
    @stock[packet.stock_id].fromBestOrder packet
  end



  def fix_selling_price(stock_id, price)
    if @stock[stock_id].i_sold_for.to_i > 0
      @stock[stock_id].i_sold_for
    else
      if (price == 0) && (@stock[stock_id].sell_price.to_i > 0) #ja sprzedam po tyle po ile ktos inny sprzeda
        @stock[stock_id].i_sold_for = @stock[stock_id].sell_price
      else
        @stock[stock_id].i_sold_for = price
      end
    end
  end



  def panic_sell(stock_id)
    @stock[stock_id].i_sold_for *= 0.9

    timer( random(1 .. 5) ) {
      sell_pkc(stock_id, amount(stock_id) )
    }
  end


  def buy_for(stock, price, perc=1.00)
    say "Buy for: #{stock} #{price}"
    if price.to_i<=0
      say "Couldn\'t buy #{stock} (price is 0)"
      return
    end


    @stock[stock].i_bought_for = price
    buy(stock, (perc*cash/price).to_i, price)
  end



  def get_more_stock(stock_id, pkc=false)
    if @stock[stock_id].initialized
      say "get_more_stock #{stock_id}. SP=#{@stock[stock_id].sell_price}"
      buying_price = @stock[stock_id].sell_price


      if pkc
        say 'buy pkc'
        buying_price = [2*buying_price, [buying_price, cash].max].min
      end


      if cash >= buying_price
        buy_for(stock_id, buying_price)
      else
        say "Wanted to buy but no dice. #{cash}<#{buying_price}"
      end

    else
      say 'Can\'t get more stock. Uninitialized!'
    end
  end



end

@klienci = []
rng = Random.new
ARGV[1].to_i.times { |i|
  @klienci << Thread.new {
    sleep( rng.rand(0.0 .. 100.0) )
    DumbClient.new('%06d' %(i+2+ARGV[0].to_i), i+2+ARGV[0].to_i)
  }
  sleep(0.2)
}

sleep(1000000)