require 'stock.rb'

$packets = {
    :REGISTER_USER_REQ      => 0,
    :REGISTER_USER_RESP_OK  => 1,
    :REGISTER_USER_RESP_FAIL        => 2,
    :LOGIN_USER_REQ => 3,
    :LOGIN_USER_RESP_OK     => 4,
    :LOGIN_USER_RESP_FAIL   => 5,
    :UNRECOGNIZED_USER      => 6,
    :SELL_STOCK_REQ         => 20,
    :BUY_STOCK_REQ  => 21,
    :BUY_TRANSACTION        => 22,
    :SELL_TRANSACTION       => 23,
    :TRANSACTION_CHANGE     => 24,
    :ORDER  => 25,
    :BEST_ORDER     => 26,
    :SUBSCRIBE_STOCK        => 27,
    :UNSUBSCRIBE_STOCK      => 28,
    :GET_MY_STOCKS  => 29,
    :GET_MY_STOCKS_RESP     => 30,
    :GET_MY_ORDERS  => 31,
    :GET_MY_ORDERS_RESP     => 32,
    :GET_STOCK_INFO => 33,
    :GET_STOCK_INFO_RESP    => 34,
    :CANCEL_ORDER_REQ       => 35,
    :COMPANY_STATUS_REQ     => 40,
    :COMPANY_ACTIVE_RESP    => 41,
    :COMPANY_FROZEN_RESP    => 42,
    :SESSION_STARTED        => 43,
    :SESSION_CLOSED => 44,
    :IS_SESSION_ACTIVE      => 45,
    :SESSION_STATUS => 46,
    :UNDEFINED            => 100
}

class StockPacket
  attr_accessor :id
  attr_reader :bytearray

  def get
    @bytearray.pack('c*')
  end

  def readable
    @bytearray.unpack('C*')
  end

end

class StockPacketOut < StockPacket
  def initialize(id)
    @id = id
    @bytearray = [id].pack('c')
  end

  def push(type,val)
    case type
      when 'int' then
        @bytearray += [val].pack('l>')
      when 'short' then
        @bytearray += [val].pack('s>')
      when 'string' then
        @bytearray += val
      when 'byte' then
        @bytearray += [val].pack('c')
      else
        raise 'wut'
    end
  end

  def forge_final
    #puts "Trying to send: #{@bytearray.unpack('c*')}"
    [@bytearray.length].pack('s>') + @bytearray
  end
end

class StockPacketIn < StockPacket
  attr_reader :packetlen
  def initialize(bytestring)
    #puts "#{bytestring.length} #{bytestring}"
    @bytearray  = bytestring.unpack('c*')
    @offset     = 0
    @packetlen  = self.pull('short')
    @bytearray = @bytearray[0..(@packetlen+2)]
    @id         = self.pull('byte')
  end

  def pull(type)
    retval = nil
    @bytearray ||= []
    case type
      when 'int' then
        retval = @bytearray[@offset..(@offset+3)].pack('c*').unpack('l>')[0]
        @offset += 4
      when 'short' then
        retval = @bytearray[@offset..(@offset+1)].pack('c*').unpack('s>')[0]
        @offset += 2
      when 'string' then
        retval = @bytearray[@offset..@bytearray.length].pack('c*')
        @offset = @bytearray.length
      when 'byte' then
        retval = [@bytearray[@offset]].pack('c*').unpack('c')[0]
        @offset += 1
      else
        raise 'Error: unexpected type'
    end
    return retval
  end

  def pull_len(type,len)
    retval = nil
    case type
      when 'string' then
        retval = @bytearray[@offset..(@offset+len-1)].pack('c*')
        @offset += len
      else
        raise 'Error: unexpected type'
    end
    return retval
  end
end

class RegisterUserReq < StockPacketOut
  attr_accessor :password

  def initialize(arg=nil)
    super($packets[:REGISTER_USER_REQ])
    @password = arg
  end

  def forge
    self.push('short',@password.length)
    self.push('string',@password)
    self.forge_final
  end

end




class RegisterUserRespOk < StockPacketIn
  attr_reader :user_id
  def initialize(bytestring)
    super(bytestring)
    @user_id = self.pull('int')
  end
end




class RegisterUserRespFail < StockPacketIn
  attr_reader :reason
  def initialize(bytestring)
    super(bytestring)
    len = self.pull('short')
    @reason = self.pull_len('string',len)
  end
end








##login

class LoginUserReq < StockPacketOut
  attr_accessor :user_id, :password

  def initialize(user_id=nil,password=nil)
    super($packets[:LOGIN_USER_REQ])
    @password = password
    @user_id  = user_id
  end

  def forge
    self.push('int',@user_id)
    self.push('short',@password.length)
    self.push('string',@password)
    self.forge_final
  end

end




class LoginUserRespOk < StockPacketIn
  def initialize(bytestring)
    super(bytestring)
  end
end




class LoginUserRespFail < StockPacketIn
  attr_reader :reason
  def initialize(bytestring)
    super(bytestring)
    len = self.pull('short')
    @reason = self.pull_len('string',len)
  end
end


class SubscribeStock < StockPacketOut
  attr_accessor :stock_id

  def initialize(arg=nil)
    super($packets[:SUBSCRIBE_STOCK])
    @stock_id = arg
  end

  def forge
    self.push('int',@stock_id)
    self.forge_final
  end

end




class UnsubscribeStock < StockPacketOut
  attr_accessor :stock_id

  def initialize(arg=nil)
    super($packets[:UNSUBSCRIBE_STOCK])
    @stock_id = arg
  end

  def forge
    self.push('int',@stock_id)
    self.forge_final
  end
end




class SellStockReq < StockPacketOut
  attr_accessor :stock_id, :amount, :price

  def initialize(stock_id=nil, amount=nil, price=nil)
    super($packets[:SELL_STOCK_REQ])
    @stock_id = stock_id
    @amount = amount
    @price  = price
  end

  def forge
    self.push('int',@stock_id)
    self.push('int',@amount)
    self.push('int',@price)
    self.forge_final
  end
end



class SellTransaction < StockPacketIn
  attr_reader :stock_id, :amount

  def initialize(bytestring)
    super(bytestring)
    @stock_id = self.pull('int')
    @amount = self.pull('int')
  end
end


class BuyStockReq < StockPacketOut
  attr_accessor :stock_id, :amount, :price

  def initialize(stock_id=nil, amount=nil, price=nil)
    super($packets[:BUY_STOCK_REQ])
    @stock_id = stock_id
    @amount = amount
    @price  = price
  end

  def forge
    self.push('int',@stock_id)
    self.push('int',@amount)
    self.push('int',@price)
    self.forge_final
  end
end


class BuyTransaction < StockPacketIn
  attr_reader :stock_id, :amount

  def initialize(bytestring)
    super(bytestring)
    @stock_id = self.pull('int')
    @amount = self.pull('int')
  end
end


class TransactionChange <StockPacketIn
  attr_reader :stock_id, :amount, :price, :date
  def initialize(bytestring)
    super(bytestring)
    @stock_id = self.pull('int')
    @amount   = self.pull('int')
    @price    = self.pull('int')
    @date     = self.pull_len('string',self.pull('short'))
  end
end

class Order <StockPacketIn
  attr_reader :type, :stock_id, :amount, :price
  def initialize(bytestring)
    super(bytestring)
    @type     = self.pull('byte')
    @stock_id = self.pull('int')
    @amount   = self.pull('int')
    @price    = self.pull('int')
  end
end

class BestOrder <StockPacketIn
  attr_reader :type, :stock_id, :amount, :price
  def initialize(bytestring)
    super(bytestring)
    @type     = self.pull('byte')
    @stock_id = self.pull('int')
    @amount   = self.pull('int')
    @price    = self.pull('int')
  end
end

class SubscribeStock <StockPacketOut
    attr_accessor :stock_id

    def initialize(stock_id=nil, amount=nil, price=nil)
      super($packets[:SUBSCRIBE_STOCK])
      @stock_id = stock_id
    end

    def forge
      self.push('int',@stock_id)
      self.forge_final
    end
end

class UnsubscribeStock <StockPacketOut
  attr_accessor :stock_id

  def initialize(stock_id=nil)
    super($packets[:UNSUBSCRIBE_STOCK])
    @stock_id = stock_id
  end

  def forge
    self.push('int',@stock_id)
    self.forge_final
  end
end

class CompanyStatus <StockPacketOut
  attr_accessor :stock_id

  def initialize(stock_id=nil)
    super($packets[:COMPANY_STATUS_REQ])
    @stock_id = stock_id
  end

  def forge
    self.push('int',@stock_id)
    self.forge_final
  end
end



class CompanyActive <StockPacketIn
  attr_reader :stock_id
  def initialize(bytestring)
    super(bytestring)
    @stock_id = self.pull('int')
  end
end



class CompanyFrozen <StockPacketIn
  attr_reader :stock_id
  def initialize(bytestring)
    super(bytestring)
    @stock_id = self.pull('int')
  end
end



class GetStocks <StockPacketOut

  def initialize
    super($packets[:GET_STOCKS])
  end

  def forge
    self.forge_final
  end
end


class GetMyOrders <StockPacketOut

  def initialize
    super($packets[:GET_MY_ORDERS])
  end

  def forge
    self.forge_final
  end
end

class GetMyStocks <StockPacketOut
  def initialize
    super($packets[:GET_MY_STOCKS])
  end

  def forge
    self.forge_final
  end
end

class GetMyStocksResp <StockPacketIn
  attr_reader :stockhash
  def initialize(bytestring)
    super(bytestring)
    @stock_count = self.pull('int')
    @stockhash = {}
    @stock_count.times do |i|
      stock_id = self.pull('int')
      amount   = self.pull('int')
      @stockhash[stock_id] = Stock.new(stock_id, amount)
    end
  end
end

class GetMyOrdersResp <StockPacketIn
  attr_reader :orderlist
  def initialize(bytestring)
    super(bytestring)
    @order_count = self.pull('int')
    @orderlist = []
    @order_count.times do |i|
      order = []
      @orderlist += [[self.pull('byte'),self.pull('int'),self.pull('int'),self.pull('int'),self.pull('int')]]
    end
  end
end


class GetStockInfo <StockPacketOut
  attr_reader :stock_id
  def initialize(stock_id)
    super($packets[:GET_STOCK_INFO])
    @stock_id = stock_id
  end
  def forge
    self.push('int',@stock_id)
    self.forge_final
  end
end

class GetStockInfoResp <StockPacketIn
  attr_reader :stock_id, :buy_price,  :buy_amount,
                         :sell_price, :sell_amount,
                         :transaction_price, :transaction_amount, :transaction_date

  def initialize(bytestring)
    super(bytestring)
    @stock_id = self.pull('int')
    @buy_amount = self.pull('int')
    @buy_price = self.pull('int')
    @sell_amount = self.pull('int')
    @sell_price = self.pull('int')
    @transaction_amount = self.pull('int')
    @transaction_price  = self.pull('int')
    len = self.pull('short')
    @transaction_date   = self.pull_len('string',len)
  end

  def to_s
    "#Stock info: ID=#{@stock_id} | buy order: p=#{@buy_price}, a=#{@buy_amount} | sell order: p=#{@sell_price}, a=#{@sell_amount} transaction: p=#{@transaction_price}, a=#{@transaction_amount}"
  end
end

class CancelOrderReq <StockPacketOut
  attr_accessor :order_id
  def initialize(order_id)
    super($packets[:CANCEL_ORDER_REQ])
    @order_id = order_id
  end

  def forge
    self.push('int',@order_id)
    self.forge_final
  end
end