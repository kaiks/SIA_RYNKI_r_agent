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
    send_data GetMyStocks.new.forge
    send_data GetMyOrders.new.forge
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
      say "Now doing order #{order.to_s}"
      if order[0]==2 || order[0]=='2'
        send_data GetStockInfo.new(order[2]).forge
        fix_selling_price(order[2],(1.1*order[4]).to_i)
        say "Hey, let's get more of #{order[2]}"
        EventMachine.add_timer(30) { panic_sell(order) }
        EventMachine.add_timer(rand(5)+1) { get_more_stock(order[2]) }
      end
    end
    #@my_orders.each{|order| say order.to_s }
  end

  def on_get_stock_info_resp packet
    say "Stock info: #{packet.inspect}"
    @stock_info[packet.stock_id] = [packet.buy_price, packet.buy_amount,
                                    packet.sell_price, packet.sell_amount,
                                    packet.transaction_price, packet.transaction_amount]

    fix_selling_price(packet.stock_id, @stock_info[packet.stock_id][0] )

    EventMachine.add_timer(rand(5)+1) {
      sell_stock_all(packet.stock_id, fix_selling_price(packet.stock_id,packet.sell_price*1.1) ) #10% trzeba ugrac!
    }
  end


  def fix_selling_price(stock_id,price)
    if @selling_price.has_key? stock_id
      return @selling_price[stock_id]
    else
      @selling_price[stock_id] = price.to_i
    end
  end

  def sell_stock_all(stock_id, price, pkc=false)
    amount = self.stock_amount stock_id
    selling_for = fix_selling_price(stock_id,price)

    if pkc==true
      selling_for=1
    end

    sell(stock_id,amount, selling_for )

    get_more_stock(stock_id)

  end

  def get_more_stock(stock_id)
    say "Trying to get more of #{stock_id}"
    if stock_amount(1) >= @selling_price[stock_id]
      buy(stock_id,(stock_amount(1)/@selling_price[stock_id]*0.95).to_i,(@selling_price[stock_id]*0.95).to_i)
    else
      say 'Wanted to buy but no dice'
    end
  end

  def panic_sell(order)
    send_data CancelOrderReq.new(order[1]).forge
    send_data GetMyStocks.new.forge
    @selling_price[order[2]] *= 0.9
    EventMachine.add_timer(rand(5)+1) {
      sell_stock_all(order[2],@selling_price[order[2]],true)
    }
  end
end

EventMachine.run {
  20.times { |i|
    EventMachine.connect '127.0.0.1', 12345, DumbClient, '%06d' %(i+2), i+2
  }
}