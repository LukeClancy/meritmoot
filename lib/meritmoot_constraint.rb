class MeritmootConstraint
  def matches?(request)
    SiteSetting.meritmoot_enabled
  end
end
