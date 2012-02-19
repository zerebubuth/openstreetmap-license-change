class Changeset
  attr_accessor :user

  def self.[](user, override_accepted = false)
    Changeset.new(user, override_accepted)
  end

  def override_accepted?
    @override_accepted
  end
  
  private
  def initialize(user, override_accepted)
    @user = user
    @override_accepted = override_accepted
  end
end
