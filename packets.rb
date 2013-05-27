$packets = {
    :REGISTER_USER_REQ      => 0,
    :REGISTER_USER_RESP_OK  => 1,
    :REGISTER_USER_RESP_FAIL=> 2,
    :LOGIN_USER_REQ         => 3,
    :LOGIN_USER_RESP_OK     => 4,
    :LOGIN_USER_RESP_FAIL   => 5,
    :SUBSCRIBE_STOCK        => 6,
    :UNSUBSCRIBE_STOCK      => 7,
    :SELL_STOCK_REQ         => 8,
    :SELL_STOCK_RESP        => 9,
    :BUY_STOCK_REQ          => 10,
    :BUY_STOCK_RESP         => 11,
    :GET_STOCKS             => 12,
    :LIST_OF_STOCKS         => 13,
    :CHANGE_PRICE           => 14,
    :COMPANY_STATUS_REQ     => 15,
    :COMPANY_ACTIVE_RESP    => 16,
    :COMPANY_FROZEN_RESP    => 17,
    :BUY_TRANSACTION        => 18,
    :SELL_TRANSACTION       => 19,
    :SESSION_STARTED        => 20,
    :SESSION_CLOSED         => 21,
    :IS_SESSION_ACTIVE      => 22,
    :SESSION_STATUS         => 23,
    :UNDEFINED              => 24,
    :UNRECOGNIZED_USER      => 25,
}

class StockPacket
  attr_accessor :id
  attr_reader :bytearray

  def get
    @bytearray.pack('c*')
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
        @bytearray += [val].pack('i>')
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
    [@bytearray.length].pack('s') + @bytearray
  end
end

class StockPacketIn < StockPacket
  def initialize(bytestring)
    #puts "#{bytestring.length} #{bytestring}"
    @bytearray  = bytestring.unpack('c*')
    @offset     = 0
    @packetlen  = self.pull('short')
    @id         = self.pull('byte')
  end

  def pull(type)
    retval = nil
    case type
      when 'int' then
        retval = @bytearray[@offset..(@offset+3)].pack('c*').unpack('i>')[0]
        @offset += 4
      when 'short' then
        retval = @bytearray[@offset..(@offset+1)].pack('c*').unpack('s>')[0]
        @offset += 2
      when 'string' then
        retval = @bytearray[@offset..@bytearray.length].pack('c*')
        @offset = @bytearray.length
      when 'byte' then
        retval = @bytearray[@offset]
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
  attr_reader :user_id
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