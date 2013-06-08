require './klient.rb'

class DumbClient < SClient

  def initialize(password=nil, user_id=0)
    super(password, user_id)
    @rng = Random.new
    @panic_thread = nil
    @stock = {}
    $csv.each_key { |k| @stock[k] = StockInfo.new }
  end



  def on_login_user_resp_ok packet
    @threads << Thread.new {
      Thread.abort_on_exception=true
      loop {
        sleep(@rng.rand(10 .. 20))
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

        if @stock[k].initialized==true
          buy_for(k, @stock[k].sell_price, 0.5)
        else
          send SubscribeStock.new(k).forge
          send GetStockInfo.new(k).forge
          next
        end

      end
    }
  end



  def on_get_my_orders_resp packet
    say "My orders: #{@my_orders.to_s}"
    @my_orders.each do |order|
      #say "Now doing order #{order.to_s}"
      if @stock[order[2]].checkInitialized { send GetStockInfo.new(order[2]).forge } == false
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
      timer( @rng.rand(2.0 .. 20.0) ) {
        cancel_order(order[1])
        panic_sell(order[2])
      }
    }

    timer( @rng.rand(1 .. 5) ) {
      say "Hey, let's get more of #{order[2]}"
      get_more_stock(order[2])
    }
  end



  def buy_order_action(order)
    @stock[order[2]].i_bought_for = order[4]

    timer( @rng.rand(2.0 .. 20.0) ) {
      cancel_order(order[1]) if order[3]>2
      sleep(0.1)

      randval = @rng.rand(4)
      if randval == 0
        buy_for(order[2], @rng.rand(1.1 .. 1.5) * @stock[order[2]].i_bought_for, 0.5)
      else
        get_more_stock(order[2], true)
      end
    }
  end



  def on_get_stock_info_resp packet
    stock = packet.stock_id
    say "Stock info: #{packet.to_s}"

    @stock[stock].fromStockInfo packet

    timer( @rng.rand(1 .. 5) ) {
      sell_stock_all(stock, fix_selling_price(stock, packet.sell_price*1.1)) #10% trzeba ugrac!
    }
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
        @stock[stock_id].i_sold_for = price
      end
    end
  end



  def sell_stock_all(stock_id, price, pkc=false)
    say "Sell all: #{stock_id} #{price.to_i}"
    amount = stock_amount stock_id
    selling_price = [1, price].max
    if pkc
      say 'PKC sell'
      selling_price=1
    else
      @stock[stock_id].i_sold_for = price
    end
    sell(stock_id, amount, selling_price)
  end



  def buy_for(stock, price, perc=1.00)
    say "Buy for: #{stock} #{price}"
    if price.to_i>0
      buy(stock, (perc*cash/price).to_i, price)
    else
      say "Couldn\'t buy #{stock} (price is 0)"
    end
  end



  def get_more_stock(stock_id, pkc=false)
    if @stock[stock_id].initialized
      say "get_more_stock #{stock_id}. SP=#{@stock[stock_id].sell_price}"
      buying_price = @stock[stock_id].sell_price


      if pkc
        say 'buy pkc'
        buying_price = [2*buying_price, [buying_price, @my_stocks[1]].max].min
      end


      if cash >= buying_price
        buy_for(stock_id, buying_price)
      else
        say "Wanted to buy but no dice. #{stock_amount(1)}<#{buying_price}"
      end

    else
      say 'Can\'t get more stock. Uninitialized!'
    end
  end



  def panic_sell(stock_id)
    @stock[stock_id].i_sold_for *= 0.9

    timer( @rng.rand(1 .. 5) ) {
      sell_stock_all(stock_id, @stock[stock_id].i_sold_for, true)
    }
  end


end

@klienci = []
rng = Random.new
300.times { |i|
  @klienci << Thread.new {
    Thread.abort_on_exception=true
    sleep( rng.rand(0.0 .. 100.0) )
    DumbClient.new('%06d' %(i+2), i+2)
  }
  sleep(0.2)
}

sleep(1000000)