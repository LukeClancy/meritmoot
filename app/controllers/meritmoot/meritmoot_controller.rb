module Meritmoot
  class MeritmootController < ::ApplicationController
    requires_plugin Meritmoot

    before_action :ensure_logged_in

    def index
    end
  end
end
