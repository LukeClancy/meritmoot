module Meritmoot
  # The api controller is used for complex actions not necessarily related to a particular controller and that are not
  # protected by a user account being logged in (or not) (do not put secure shit here).
  
  BillVote = Struct.new(:bill_id, :vote_position)

  class ApiController < ::ActionController::API
    include MootLogs
    #requires_plugin Meritmoot
    def memSearch
      MootLogs.logWatch("MootMemSearch"){ |log|
        #format input for query
        substr = params["substr"]
        if substr == ""
          return []
        end
        log.puts "subby #{substr}"
        substr = substr.split(" ")
        quer = ""
        annnd = false
        num = 0
        while num < substr.length
          annnd ? quer << " AND " : annnd = true #skip first AND, then, subsequently add at beginning.
          quer << "mm_reference_str_lower LIKE ?"
          substr[num] = "%#{substr[num].downcase}%"
          num += 1
        end
        log.puts "quer: #{quer}, substr: #{substr}"
        #get at most 10 from Mmmember where for each word provided, that word is in the member's mm_reference_str (yet to be constructed)
        mems = Mmmember.limit(10).where(quer, *substr)
        mems = mems.to_a
        #make sure we only take what we actually want
        retMems = []
        for mem in mems
          retMem = {
            mm_reference_str: mem.mm_reference_str,
            id: mem.id
          }
          retMems << retMem
        end
        log.puts "retMems: #{retMems}"
        render json: retMems
      }
    end

    def self.passingAround(r, file)
      if r.code == "301" or r.code=="302"
        Net::HTTP.get_response(URI.parse(r.header['location'])) do |r|
          MootLogs.p "passed around"
          passingAround(r, file)
        end
      else
        r.read_body(file)
      end
    end

    $LASTCHECK = 0 #in seconds since epoc
    def getpdf
    # source info page: https://github.com/usgpo/link-service

    #Query: bill number, bill type, congress, bill version OR most recent
    #Parameters:
    #collection: Required - Value is bills.
    #billtype: Required - Values are hr, s, hjres, sjres, hconres, sconres, hres, sres.
    #billversion: Optional - If bill version is not provided, the most recent version of a bill is returned. Values are as, cps, fph, lth, ppv, rds, rhv,
    # rhuc, ash, eah, fps, lts, pap, rev, rih, sc, eas, hdh, nat, pwah, reah, ris, ath, eh, hds, oph, rah, res, rsv, ats, eph, ihv, ops, ras, renr, rth,
    # cdh, enr, iph, pav, rch, rfh, rts, cds, esv, ips, pch, rcs, rfs, s_p, cph, fah, isv, pcs, rdh, rft, sas, mostrecent. <-----
    #billnum: Required - This is the numerical bill number. Sample value is 1027.
    #congress: Required - This is the numerical Congress number. Sample value is 112.
    #link-type: Optional - This is the format of the returned document. Default is pdf. Other values are xml, html, mods, premis, contentdetail.

    #Examples:
      #https://api.fdsys.gov/link?collection=bills&billtype=hr&billversion=ih&billnum=1&congress=112
      #https://api.fdsys.gov/link?collection=bills&billtype=hconres&billnum=17&congress=112&link-type=xml

    # the above api accepts mostrecent as an argument, which is why I will be using it (that way I dont have to infer version through status, which would
    # be overhead).

    # replace tempfile location by a location in a folder under meritmoot. After returning the file to the user
    # check the last checked time. If its been a bit (like 2 hours), go through and delete all files that havent been
    # accessed in, like, a day.

    # I have noticed that some pdfs dont load on meritmoot.com. I am gueeesssssssing this is due to timeout. This is probably extendable in javascript.
    # extend it to 15 seconds.

    #capture crap
      logWatch("GetBillPdf") { |log|
        require 'net/http'
        require 'time'
        billType = params['billtype']
        billNum = params['billnum']
        billCongress = params['congress']
        billVersion = 'mostrecent'
        billVersion = params['billversion'] if not params['billversion'].nil?

        theFile = nil
        prefix = "moot-pdf"
        theFileName = "#{prefix}-#{billCongress}-#{billType}-#{billNum}-#{billVersion}.pdf"

        #figure out if we allready have it
        files = Dir.entries("/tmp")
        files.select!{ |name| name == theFileName }
        p "files: #{files}"
        if files.length == 1
          theFile = "/tmp/" + theFileName
          theFile = File.open(theFile)
          createTime = theFile.ctime
          billUpdateTime = Mmbill.find_by(bill_id: "#{billType}#{billNum}-#{billCongress}".downcase)
          if billUpdateTime == nil
            logWatch("pdfs_related_Mmbill_not_found"){ 
              p("#{billType}#{billNum}-#{billCongress} - #{theFileName}")
            }
            billUpdateTime = Time.new(1990) #something a long time ago
          else 
            billUpdateTime = Time.parse(billUpdateTime.bulk['history']['active_at'])
          end

          #outdated?
          if createTime > billUpdateTime
            #No just pass it back
            send_file(theFile, filename: theFileName, type: 'application/pdf', disposition: 'inline')
          else
            #Yes it is outdated. delete it
            theFile.close
            File.delete("/tmp/" + theFileName)
            theFile = nil
          end
        end
        if theFile == nil
          theFile = File.open("/tmp/" + theFileName, "w", :encoding => 'ascii-8bit')
          #https://api.fdsys.gov/link?collection=bills&billtype=sres&billversion=mostrecent&billnum=14&congress=116
          Net::HTTP.get_response(URI.parse("https://api.fdsys.gov/link?collection=bills&billtype=#{billType}&billversion=#{billVersion}&billnum=#{billNum}&congress=#{billCongress}")) do |r|
            p "code: #{r.code}"
            ApiController.passingAround(r, theFile)
          end
          send_file(theFile, filename: theFileName, type: 'application/pdf', disposition: 'inline')
          theFile.close()
        end
        #bit of cleanup.
        #delete old ones
        files = Dir.entries("/tmp")
        #select ones we handle, and that are three days since last accesssed
        files.select!{|name| name[prefix] != nil and File.atime("/tmp/" + name) < Time.now - ( 3 * 24 * 60 * 60 ) }
        for rejectFile in files
          #rejectFile.close
          File.delete("/tmp/#{rejectFile}")
        end
      }
    end

    def votes()
      MootLogs.logWatch("MootApi-getVotes") {
        p "params #{params.inspect()}"
        topicList = params["topicList"]
        member_id = params["rep_id"]
        rollcalls = []
        bills = []
        rollcalls = Mmrollcall.where(topic_id: topicList).to_a
        bills = Mmbill.where(topic_id: topicList).to_a
        ## - - - - - - Create the diffrent parts of the queries
        #still need to connect bills to rollcalls properly to understand who voted for what bill,
        #but also note that this is probably the last thing needed to be done before launch,
        #there are many roll calls for each bill, and some times the roll call isnt properly connected anyway, 
        #due to staggered updates, for which there needs to be contingency

        ## - - - - - - combine and connect queries, then call the queries, then transform to array
        rcids = rollcalls.map{ |r| r.id }
        blids = bills.map{|b| b.bill_id}
        #p "rcids: #{rcids}"
        #p "blids: #{blids}"
        #p "memid: #{member_id}"
        rcVs = Mmrollcallvote.where( mmrollcall_id: rcids, mmmember_id: member_id ).to_a
        #bill affects are for sponsorships, cosposnorships, etc.
        blAfs = Mmbillaffect.where( mmmember_id: member_id, bill_id: blids ).to_a
        
        #bill votes on passage are contained within its rollcalls with the question 'On Passage'
        #so, bill roll call votes => blrcvs
        blrcs = Mmrollcall.where(bill_id: blids, question: 'On Passage').to_a
        blrcids = blrcs.map{|rc| rc.mm_primary }
        #these are the votes, but we need to connect to bill_id
        blrcvs = Mmrollcallvote.where(mmrollcall_id: blrcids, mmmember_id: member_id).to_a

        #manipulate
        rcblidHash = blrcs.map{|rc| [rc.mm_primary, rc.bill_id] }.to_h
        blVs = [] #aka bill votes
        for blrcv in blrcvs
          blVs << BillVote.new( rcblidHash[blrcv.mmrollcall_id], blrcv.vote_position )
        end

        if rcVs.length == 0 and blAfs.length == 0 and blVs.length == 0
          render json: {status: "EMPTY", topics: {}}
          return
        end
        member = Mmmember.find_by(mm_primary: member_id)

        topics = {}
        
        #so now we have
        #   a list of roll calls, a list of bills
        #   a list of bill affects, a list of bill votes, a list of roll call votes
        
        #finalList - what we want:
        #topics: {
        # tid: ["tag1", "tag2"],
        # ...
        #}
        #topics : finalList

        #step 1, group diffrent objects by roll call id, bill id
        #step 2, for each grouping, utilizing class id, determine topic #, member, and position for blAfs, blVs, rcVs
        #step 3, put that into a tag
        #step 4, format

        #1
        grouped_rc = (rcVs + rollcalls).group_by{ |item|
          if item.class == Mmrollcallvote
            next item.mmrollcall_id
          else #Mmrollcall
            next item.id
          end
        }
        #2
        for group in grouped_rc.values
          topic = "Shit a brick nick"
          tags = []
          for item in group
            #3
            if item.class == Mmrollcallvote
              tags << { "name" => "#{member.mm_tag_str}: #{item.vote_position}" }
            else
              topic = item.topic_id
            end
          end
          raise StandardError.new("topic was not set ? ") if topic == "Shit a brick nick"
          #4
          topics[topic] = tags if tags != []
        end
        #1
        grouped_bl = (blAfs + blVs + bills).group_by{ |item|
          if item.class == Mmbillaffect or item.class == BillVote
            next item.bill_id
          else #bill
            next item.id
          end
        }
        #2
        for group in grouped_bl.values
          topic = "Shit a brick nick"
          tags = []
          for item in group
            #3
            if item.class == Mmbillaffect
              tags << { "name" => "#{member.mm_tag_str}: #{item.affect}" }
            elsif item.class == BillVote
              tags << { "name" => "#{member.mm_tag_str}: #{item.vote_position}"}
            else
              topic = item.topic_id
            end
          end
          raise StandardError.new("topic was not set ? ") if topic == "Shit a brick nick"
          #4
          topics[topic] = tags if tags != []
        end
        render json: {status: "OK", topics: topics}
      }
    end
  end
end