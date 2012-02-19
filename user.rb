class User
  attr_accessor :adopter

  def self.[](accepted_cts, adopter = nil)
    User.new(accepted_cts, adopter)
  end

  def accepted_cts?
    @accepted_cts
  end

  private
  def initialize(accepted_cts, adopter)
    @accepted_cts = accepted_cts
    @adopter = adopter
  end
end
