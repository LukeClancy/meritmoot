# frozen_string_literal: true

# name: meritmoot
# about: To transform discourse to meritmoot.com
# version: 0.1
# authors: lukeclancy
# url: https://github.com/lukeclancy

#httparty dependancies - DEPRECIATING
  gem 'mime-types-data', '3.2019.1009', required: true
  gem 'mime-types', '3.3.1', required: true 
  gem 'multi_xml', '0.6.0', required: true
#
gem 'httparty', '0.17.3' , required: true

#persistent_http dependancies
  gem 'gene_pool', '1.5.0', required: true
#
gem 'persistent_http', '2.0.3', required: true
#, 
#json required too - but its allready there
#
#gem 'pycall', '1.3.0' , required: true

register_asset 'stylesheets/common/meritmoot.scss'
#register_asset 'stylesheets/awesomeplete.css'
register_asset 'stylesheets/desktop/meritmoot.scss'
register_asset 'stylesheets/mobile/meritmoot.scss'
register_asset 'awesomplete.js'
#register_asset 'meritmootcommon.js'
#register_asset 'javascripts/awesomplete.js'
#register_asset 'javascripts/discourse/lib/awesomplete.js'

enabled_site_setting :meritmoot_enabled
PLUGIN_NAME ||= 'Meritmoot'

load File.expand_path('lib/meritmoot/engine.rb', __dir__)
#load File.expand_path('jobs/regular/update_bvotes.rb', __dir__)

after_initialize do
  #split up the jobs to prevent timeout.
  class Jobs::MootTesting < ::Jobs::Scheduled
    every 1.day
    include MootLogs
    def execute(args={})
      #MootLogs.logWatch("MootTesting") {
        #::Meritmoot::Tests.test_Bulks()
      #}
    end
  end
  class Jobs::MootUpdateRollCalls < ::Jobs::Scheduled
    every 8.hour
    include MootLogs
    def execute(args={})
      logWatch("MootUpdateRollCalls"){
        contr = Meritmoot::Controller.new({})
        contr.fillRollCalls(pout = false)
      }
      #MootUpdateCommittees.perform_now
      #MootUpdateRollCalls.perform_now
    end
  end
  class Jobs::MootUpdateBills < ::Jobs::Scheduled
    every 8.hour
    include MootLogs
    def execute(args={})
    logWatch("MootUpdateBills") {
        p "please note that ActiveRecord::RecordNotUnique error coming during postcreation from something about featured posts just needs that error added to discourses code at the lower level (follow that backtrace and add it)."
        contr = Meritmoot::Controller.new({})
        contr.fillBills(pout = false)
      }
    end
  end
  class Jobs::MootUpdateCommittees < ::Jobs::Scheduled
    every 10.day
    include MootLogs
    def execute(args = {})
      logWatch("MootUpdateCommittees") {
        contr = Meritmoot::Controller.new({})
        contr.fillCommittees()
      }
    end
  end
  class Jobs::MootUpdateMembers < ::Jobs::Scheduled
    every 1.day
    include MootLogs
    def execute(args = {})
      logWatch("MootUpdateMembers") {
        contr = Meritmoot::Controller.new({})
        contr.fillMembers()
      }
    end
  end
  #Jobs::UpdateBvotes.execute()
  # https://github.com/discourse/discourse/blob/master/lib/plugin/instance.rb
end
