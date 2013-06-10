$host = 'localhost'
$port = 12345

require 'rubygems'
require 'probability'


require 'csvreader.rb'
require 'packets.rb'
require 'stock_info.rb'
require 'networked_stock_client.rb'


Thread.abort_on_exception = true



class StockClient < NetworkedStockClient

  def initialize(password=nil, user_id=0)
    @rng = Random.new
    super(password, user_id)
    @threads << Thread.new{ display_stocks_loop } if @debug
  end



  def random(arg)
    @rng.rand(arg)
  end




  def display_stocks_loop
    loop{
      say "[LOOP] #{@my_stocks.to_s}"
      sleep(5)
    }
  end



  def stock(id)
    @my_stocks.fetch(id,NullStock.new)
  end



  def cash
    stock(1).amount
  end



  def send data
    send_data(data)
  end



  def sell(stock_id, amount, price)
    stock(stock_id).trading = true
    say "Let's sell #{amount} of #{stock_id} for #{price}"

    if amount*price == 0
      say "[SELL] Invalid parameters. amount=#{amount} price=#{price}"
      return
    end

    if stock(stock_id).amount < amount
      say "Can't sell #{amount} of #{stock_id}. I've got only #{stock(stock_id).amount}!"
      return
    end

    if price < min_buying_price(stock_id)
      say 'No point in selling stock. I\'m buying for less.'
      return
    end

    stock(1).amount -= amount

    say "Selling: stock=#{stock_id} #{amount} for #{price}"
    send SellStockReq.new(stock_id, amount, price).forge
  end



  def buy(stock_id, amount, price)
    stock(stock_id).trading = true
    say "Let's buy #{amount} of #{stock_id} for #{price}"

    if amount*price == 0
      say "[BUY] Invalid parameters. amount=#{amount} price=#{price}"
      return
    elsif amount*price > cash
      say "Can't buy #{amount} of #{stock_id} for total of #{price*amount}. I've got only #{cash} cash!"
      return
    end

    if price > max_selling_price(stock_id)
      say 'No point in buying stock. I\'m selling for less.'
      return
    end

    @my_stocks[1].amount -= price*amount

    say "Buying: stock=#{stock_id} #{amount} for #{price}"
    send BuyStockReq.new(stock_id, amount, price).forge
  end



  def cancel_order(id)
    say "Cancel order #{id}"
    send CancelOrderReq.new(id).forge
  end



  def timer(sec, &block)
    Thread.new { sleep(sec); say 'Executing thread'; block.call }
  end



  def my_orders_for_stock(stock, type=nil)
    orders = @my_orders.select { |order| order[2]==stock }

    unless type.nil?
      orders.select!{ |order| order[1] == type }
    end

    orders
  end



  def cancel_orders(stock_id, type=nil)
    my_orders_for_stock(stock_id, type).each {
      send CancelOrderReq.new(order[2])
    }
  end



  def max_selling_price(stock_id)
    my_orders_for_stock(stock_id, 2).map{ |order| order[4] }.max || 99999999999
  end


  def min_buying_price(stock_id)
    my_orders_for_stock(stock_id, 1).map{ |order| order[4] }.min || 0
  end


  def sell_all_stocks(stock_id, price)
    say "Sell all: #{stock_id} #{price.to_i}"
    amount = stock(stock_id).amount
    selling_price = [1, price].max

    sell(stock_id, amount, selling_price)
  end



  def sell_pkc(stock_id, amount)
    sell(stock_id, amount, 1)
  end

end