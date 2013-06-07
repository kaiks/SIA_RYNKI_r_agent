require './klient.rb'

class DumbClient < SClient
  def initialize(password=nil, user_id=0)
    super(password, user_id)
    @panic_thread = nil
    @stock_info = {}
    $csv.each_key { |k| @stock_info[k] = StockInfo.new }
  end


  def on_login_user_resp_ok packet
    @threads << Thread.new {
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
    @stock_info[packet.stock_id].fromTransactionChange packet
  end


  def on_get_my_stocks_resp packet
    say "My stocks: #{@my_stocks.to_s}"
    @my_stocks.each_key { |k|
      if k>1
        send GetStockInfo.new(k).forge
        send SubscribeStock.new(k).forge
        if @stock_info[k].initialized
          buy_for(k, @stock_info[k].sell_price, 0.5)
        end
      end
    }
  end

  def on_get_my_orders_resp packet
    say "My orders: #{@my_orders.to_s}"
    @my_orders.each do |order|
      #say "Now doing order #{order.to_s}"
      if order[0].to_i==2
        @stock_info[order[2]].i_sold_for = order[4]
        timer(2+1.0*rand(200)/20) {
          cancel_order(order[1])
          panic_sell(order[2])
        }

        timer(rand(5)+1) {
          say "Hey, let's get more of #{order[2]}"; get_more_stock(order[2])
        }

      elsif order[0].to_i==1
        @stock_info[order[2]].i_bought_for = order[4]
        if order[3]>2
          timer(2+1.0*rand(200)/20) {
            cancel_order(order[1])
            get_more_stock(order[2], true)
          }
        end
      end
    end

  end

  def on_get_stock_info_resp packet
    say "Stock info: #{packet.to_s}"

    @stock_info[packet.stock_id].fromStockInfo packet

    timer(rand(5)+1) {
      sell_stock_all(packet.stock_id, fix_selling_price(packet.stock_id, packet.sell_price*1.1)) #10% trzeba ugrac!
    }
  end


  def on_best_order packet
    @stock_info[packet.stock_id].fromBestOrder packet
  end


  def fix_selling_price(stock_id, price)
    if @stock_info[stock_id].i_sold_for.to_i > 0
      @stock_info[stock_id].i_sold_for
    else
      if @stock_info[stock_id].sell_price.to_i > 0 #ja sprzedam po tyle po ile ktos inny sprzeda
        @stock_info[stock_id].i_sold_for = @stock_info[stock_id].sell_price
      else
        @stock_info[stock_id].i_sold_for = $csv[stock_id][1]['cena']*1.05
      end
    end
  end


  def sell_stock_all(stock_id, price, pkc=false)
    amount = self.stock_amount stock_id
    selling_price = [1, price].max

    if pkc
      say 'PKC sell'
      selling_price=1
    else
      @stock_info[i_sold_for] = price
    end

    sell(stock_id, amount, selling_price)
  end

  def buy_for(stock, price, perc=1.00)
    say "Buy for: #{stock} #{price}"
    buy(stock, (perc*cash/price).to_i, price)
  end

  def get_more_stock(stock_id, pkc=false)
    if @stock_info[stock_id].initialized
      say "get_more_stock #{stock_id}. SP=#{@stock_info[stock_id].sell_price}"
      buying_price = @stock_info[stock_id].sell_price
      if pkc
        say 'buy pkc'
        buying_price = [2*buying_price, [buying_price, @my_stocks[1]].max].min
      end
      if cash >= buying_price
        buy_for(stock_id, buying_price)
      else
        say "Wanted to buy but no dice. #{stock_amount(1)}<#{buying_price}"
      end
    end
  end

  def panic_sell(stock_id)
    send GetMyStocks.new.forge
    @stock_info[stock_id].i_sold_for *= 0.9

    timer(rand(5)+1) {
      sell_stock_all(stock_id, @stock_info[stock_id].i_sold_for, true)
    }
  end


end

@klienci = []

1.times { |i|
  @klienci << Thread.new {
    #sleep(1.0*rand(1000)/10.0)
    DumbClient.new('%06d' %(i+2), i+2)
    #EventMachine.connect '127.0.0.1', 12345, DumbClient, '%06d' %(i+2), i+2
  }
}

sleep(1000000)