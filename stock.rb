class Stock < Struct.new(:id, :amount, :trading)

  def initialize(id, amount)
    @id       = id
    @amount   = amount
    @trading  = false
  end

  def amount
    @amount
  end

  def trading?
    @trading
  end

  def to_s
    "ID=#{@id.to_s} AMOUNT=#{@amount.to_s} TRADING=#{@trading.to_s}"
  end
end

class NullStock
  def amount
    0
  end

  def trading?
    false
  end

  def to_s
    'NullStock'
  end
end