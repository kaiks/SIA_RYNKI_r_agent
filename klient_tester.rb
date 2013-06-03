require 'klient.rb'

class BossClient < SClient
  def initialize(password=nil, user_id=0)
    super(password,user_id)
  end

  def on_register_user_resp_ok packet
  end

  def on_register_user_resp_fail packet

  end

  def on_login_user_resp_ok packet
    send_data GetStockInfo.new(3).forge
    #send_data GetMyOrders.new.forge
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
    say "My stocks:"
    @my_stocks.each_pair{|k,v| say "#{k} #{v}" }
  end

  def on_get_my_orders_resp packet
    say "My orders:"
    @my_orders.each{|order| say order.to_s }
  end

  def on_get_stock_info_resp packet
    say "Stock info: #{packet.inspect}"
  end
end

EventMachine.run {
  EventMachine.connect '127.0.0.1', 12345, BossClient, 'abcdef', 1
}