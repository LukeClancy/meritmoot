module Meritmoot
  class MmfollowsController < ::ApplicationController
    before_action :ensure_logged_in
    include MootLogs
    def get
      MootLogs.logWatch("Mmfollows-get") { |log|
        log.puts "the current user is: #{current_user}"
        log.puts "UID: #{current_user.id}"
        #get from the model db, the diffrent reps they follow.
        allSubscribed = Mmfollow.select(:mmmember_id).where({user_id: current_user.id}).to_a()
        log.puts allSubscribed
        ids = allSubscribed.map{|a| a[:mmmember_id]}
        returningMembers = Mmmember.select(:mm_reference_str, :mm_primary).where({mm_primary: ids}).to_a()
        log.puts returningMembers
        returningMembers.map!{ |member_ob|
          #convert to hash with correct output
          next {
            id: member_ob.mm_primary,
            mm_reference_str: member_ob.mm_reference_str
          }
        }
        render json: returningMembers
      }
    end
    def put
      MootLogs.logWatch("Mmfollows-put") { |log|
        log.puts "the current user is: #{current_user}"
        log.puts "rep_id: #{params["rep_id"]}"
        p "MootLogs Extension Working"
        #add to the model based on the current user.
        dat = {
          user_id: current_user.id,
          mmmember_id: params["rep_id"]
        }
        #check the member exists
        mem = Mmmember.find_by(mm_primary: dat[:mmmember_id])
        log.puts "#{mem}"
        if mem == nil
          log.puts "404"
          head 404
          return
        end
        log.puts "#{mem.mm_primary}"
        log.puts "dat: #{dat}"
        #subscribe user to member
        begin
          Mmfollow.create!(dat)
        rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation => e
          #allready subscribed, return conflict.
          log.puts "409"
          head 409
          return
        end
        #cool, done.
        log.puts "200"
        head 200
      }
    end
    def delete
      MootLogs.logWatch("Mmfollows-delete") { |log|
        log.puts "the current user is: #{current_user}"
        #delete the rep for the user, will only be one since unique
        p 'logs work'
        log.puts "UID: #{current_user.id}"
        log.puts "REPID: #{params["rep_id"]}"
        #delete, destroy, destroy_all wont work as they rely on primary key - of which mmfollows has none.
        Mmfollow.where("user_id = ? AND mmmember_id = ?", current_user.id, params["rep_id"]).delete_all
        head 200
      }
    end
  end
end