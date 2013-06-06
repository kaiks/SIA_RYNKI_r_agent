require 'klient.rb'

class DumbClient < SClient
  def initialize(password=nil, user_id=0)
    super(password,user_id)
    @panic_thread = nil
    @selling_price = {}
    @stock_info = {}
  end

  def on_register_user_resp_ok packet
  end

  def on_register_user_resp_fail packet

  end

  def on_login_user_resp_ok packet
    EM.add_periodic_timer(rand(10)+10) {
      send_data GetMyStocks.new.forge
      send_data GetMyOrders.new.forge
    }
    #send_data GetMyOrders.new.forge
  end

  def on_login_user_resp_fail packet

  end

  def on_sell_transaction packet
    say 'Ka ching! (sold stuff)'
    send_data GetMyStocks.new.forge
    send_data GetMyOrders.new.forge
  end

  def on_buy_transaction packet
    say 'Ka ching! (bought stuff)'
    send_data GetMyStocks.new.forge
    send_data GetMyOrders.new.forge
  end

  def on_transaction_change packet

  end

  def on_order packet
     #GetMyStocks.new.forge
  end

  def on_best_order packet
    send_data GetStockInfo.new(packet.stock_id).forge
  end

  def on_get_my_stocks_resp packet
    say "My stocks: #{@my_stocks.to_s}"
    @my_stocks.each_key{ |k|
      if k > 1
        send_data GetStockInfo.new(k).forge
        send_data SubscribeStock.new(k).forge
      end
    }
  end

  def on_get_my_orders_resp packet
    say "My orders: #{@my_orders.to_s}"
    @my_orders.each do |order|
      #say "Now doing order #{order.to_s}"
      send_data GetStockInfo.new(order[2]).forge
      if order[0]==2 || order[0]=='2'
        @selling_price[order[2]] = order[4]
        timer(2+1.0*rand(200)/20) {
          cancel_order(order[1])
          sleep(1)
          panic_sell(order[2])
        }

        timer(rand(5)+1) {
          say "Hey, let's get more of #{order[2]}"; get_more_stock(order[2])
        }
      end

      if order[0]==1 || order[0]=='1'
        @selling_price[order[2]] = order[4]*1.1
        timer(2+1.0*rand(200)/20) {
          cancel_order(order[1])
          sleep(1)
          get_more_stock(order[2],true)
        }
        timer(rand(5)+1) {
          say "Hey, let's get more of #{order[2]}"; get_more_stock(order[2])
        }
      end
    end
    #@my_orders.each{|order| say order.to_s }
  end

  def on_get_stock_info_resp packet
    say "Stock info: #{packet.to_s}"
    @stock_info[packet.stock_id] = [packet.buy_price, packet.buy_amount,
                                    packet.sell_price, packet.sell_amount,
                                    packet.transaction_price, packet.transaction_amount]

    fix_selling_price(packet.stock_id, @stock_info[packet.stock_id][0] )

    timer(rand(5)+1) {
      sell_stock_all(packet.stock_id, fix_selling_price(packet.stock_id,packet.sell_price*1.1) ) #10% trzeba ugrac!
    }
  end


  def fix_selling_price(stock_id,price)
    if @selling_price.has_key? stock_id
      @selling_price[stock_id]
    else
      if price.to_i==0
        price = rand(10000)+1
      end
      puts "pt:#{price}"
      @selling_price[stock_id] = price.to_i
    end
  end

  def sell_stock_all(stock_id, price, pkc=false)
    amount = self.stock_amount stock_id
    selling_price= fix_selling_price(stock_id,price)

    if pkc
      say 'PKC sell'
      selling_price=1
    end

    sell(stock_id,amount, selling_price)

    get_more_stock(stock_id)

  end

  def get_more_stock(stock_id,pkc=false)
    say "Trying to get more of #{stock_id}. SP=#{@selling_price[stock_id]}"
    buying_price = @selling_price[stock_id]*0.95
    if pkc
      say 'PKC buy'
      buying_price = [2*buying_price,[buying_price, @my_stocks[1]].max].min
    end
    if stock_amount(1) >= buying_price
      buy(stock_id,(stock_amount(1)/buying_price).to_i,(buying_price).to_i)
    else
      say "Wanted to buy but no dice. #{stock_amount(1)}<#{buying_price}"
    end
  end

  def panic_sell(stock_id)
    send_data GetMyStocks.new.forge
    @selling_price[stock_id] *= 0.9
    timer(rand(5)+1) {
      sell_stock_all(stock_id,@selling_price[stock_id],true)
    }
  end


end

EventMachine.run {
  80.times { |i|
    EM.add_timer (1.0*rand(100)/10.0) {
      EventMachine.connect '127.0.0.1', 12345, DumbClient, '%06d' %(i+2), i+2
    }
  }
}