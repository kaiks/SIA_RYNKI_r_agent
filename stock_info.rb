class StockInfo
  attr_accessor :buy_price, :buy_amount, :sell_price, :sell_amount,
                :transaction_price, :transaction_amount,
                :i_bought_for, :i_sold_for, :initialized, :asked_for
  def initialize
    @initialized = false
    @asked_for = false
  end

  def fromStockInfo packet
    @buy_price  = packet.buy_price
    @buy_amount = packet.buy_amount
    @sell_price = packet.sell_price
    @sell_amount = packet.sell_amount
    @transaction_price = packet.transaction_price
    @transaction_amount = packet.transaction_amount
    @i_bought_for ||= (@sell_price).to_i
    @i_sold_for  ||= (@i_bought_for*1.1).to_i
    @initialized = true
  end

  def fromBestOrder packet
    if packet.type.to_i==1
      @buy_price = packet.price
      @buy_amount = packet.amount
    else
      @sell_price = packet.price
      @buy_amount = packet.amount
    end
  end

  def fromTransactionChange packet
    @transaction_price = packet.price
    @transaction_amount = packet.amount
  end

  def askFor(&block)
    block
    @asked_for=true
  end

  def checkInitialized(&block)
    unless @asked_for==true
      askFor { block }
    end
    @initialized
  end

end