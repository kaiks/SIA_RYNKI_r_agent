class Stock < Struct.new(:id, :amount, :trading)

  def initialize(id, amount)
    super(id, amount, false)
  end

  def trading?
    self.trading
  end

  def to_s
    "ID=#{self.id.to_s} AMOUNT=#{self.amount.to_s} TRADING=#{self.trading.to_s}"
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

  def trading=(arg)

  end

  def amount=(arg)

  end

  def id=(arg)

  end
end