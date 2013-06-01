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
    send_data GetStocks.new.forge
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

  def on_stock_info packet

  end
end

EventMachine.run {
  EventMachine.connect '127.0.0.1', 12345, BossClient, 'abcdef', 1
}