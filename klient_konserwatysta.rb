require 'klient.rb'

class DumbClient < SClient
  def initialize(password=nil, user_id=0)
    super(password,user_id)
    @panic_thread = nil
    @selling_price = -1
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
  end

  def on_buy_transaction packet
    say 'Ka ching! (bought stuff)'
    send_data GetMyStocks.new.forge
  end

  def on_transaction_change packet

  end

  def on_order packet

  end

  def on_best_order packet
    send_data GetStockInfo.new(packet.stock_id)
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
    #@my_orders.each{|order| say order.to_s }
  end

  def on_get_stock_info_resp packet
    while !packet.instance_of? GetStockInfoResp #lol
      sleep(0.1)
    end
    say "Stock info: #{packet.inspect}"
    @stock_info[packet.stock_id] = [packet.buy_price, packet.buy_amount,
                                    packet.sell_price, packet.sell_amount,
                                    packet.transaction_price, packet.transaction_amount]
    sell_stock_all(packet.stock_id, (packet.sell_price*1.1).to_i ) #10% trzeba ugrac!
  end

  def stock_amount stock_id
    if @my_stocks.has_key? stock_id
      @my_stocks[stock_id]
    else
      0
    end
  end

  def sell_stock_all(stock_id, price)
    amount = self.stock_amount stock_id

    if amount > 0
      @selling_price = price
      say "Selling all my stock /#{stock_id}/ FOR #{price}"
      send_data SellStockReq.new(stock_id, amount, price).forge
    else
      say 'Oops! Tried to sell all my stocks, but I have none.'
    end

    if @selling_price < @stock_info[stock_id][0]
      get_more_stock(stock_id)
    end

  end

  def get_more_stock(stock_id)
    if stock_amount(1) >= @stock_info[stock_id][0]
      say "Buying stock /#{stock_id}/, all in!"
      send_data BuyStockReq.new(stock_id, (stock_amount(1)/@stock_info[stock_id][0]).to_i, @stock_info[stock_id][0]).forge
      @my_stocks[1] -= (stock_amount(1)/@stock_info[stock_id][0]).to_i
    else
      say 'Wanted to buy but no dice'
    end
  end
end

EventMachine.run {
  50.times { |i|
    EventMachine.connect '127.0.0.1', 12345, DumbClient, '%06d' %(i+2), i+2
  }
}