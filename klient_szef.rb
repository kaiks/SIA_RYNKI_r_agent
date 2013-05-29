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
    send_buy_orders
    send_sell_orders
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

  def send_buy_orders
    $csv.each_value { |stock|
      order = BuyStockReq.new
      #say "Trying to buy #{stock['id_zasobu']} #{stock}"
      order.stock_id = stock['id_zasobu']
      order.amount = 1000
      order.price = stock['cena']-5
      send_data order.forge
    }
  end

  def send_sell_orders
    $csv.each_value { |stock|
      order = SellStockReq.new
      #say "Trying to sell #{stock['id_zasobu']} #{stock}"
      order.stock_id = stock['id_zasobu']
      order.amount = 1000
      order.price = stock['cena']+5
      #puts "!! #{order.forge.unpack('C*')}"
      send_data order.forge
    }
  end
end

EventMachine.run {
  EventMachine.connect '127.0.0.1', 12345, BossClient, 'abcdef', 1
}