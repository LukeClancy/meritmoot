require "httparty"
require "thread"
require "set"
require "json"
require "persistent_http" 
require "net/http"
require "uri"
require 'zip'
require 'time'

module MootLogs
  class MootLogging
    #
    # Class provides logging objects that are thread safe, can be retrieved (based off the current process)
    # and can be nested inside of eachother. This is useful for debugging in many occasion
    #
    # could add support for finding parent processes logs, but its probably better to force threads to have own
    # logs
    $openLogs = {}
    $processLogs = {}
    $base = "plugins/meritmoot/logs/"
    def self.debug
      return "openLogs: #{$openLogs}, processLogs: #{$processLogs}, base: #{$base}"
    end
    def self.ident
      return Thread.current.object_id
    end
    def self.getMine()
      if $processLogs[MootLogging.ident] == nil or $processLogs[MootLogging.ident].length == 0
        raise StandardError.new("Process has no stored logs in MootLogging")
      else
        return $openLogs[$processLogs[MootLogging.ident][-1]]
      end
    end
    def self.register(name, overwrite=false)
      if $openLogs[name] == nil
        ml = MootLogging.new(name, reg=true, overwrite=overwrite)
        #https://stackoverflow.com/questions/13589140/can-thread-current-object-id-change-inside-the-thread-itself
        return ml
      else
        $openLogs[name].watching(change=1)
        return $openLogs[name]
      end
    end
    def watching(change=nil)
      if change != nil
        @watching += change
      end
      return @watching
    end
    def initialize(name, reg=false, overwrite=false)
      if not reg
        raise StandardError.new("register it dont just init")
      end
      @base = $base
      if overwrite == true
        #open with 'w' was not overwriting for some reason so i just delete
        #File.delete(@base + name) if File.exist?(@base + name)
        @file = File.open(@base + name, mode: 'w+')
      else
        @file = File.open(@base + name, mode: 'a')
      end
      @watching = 1
      @name = name #AAAAAAAAAAAAAAAAAAA
      $openLogs[@name] = self
      if $processLogs[MootLogging.ident] == nil
        $processLogs[MootLogging.ident] = []
      end
      $processLogs[MootLogging.ident] << @name
    end
    def deregister
        @watching -= 1
      if @watching == 0
        $processLogs[MootLogging.ident].delete(@name)
        @file.close()
        if $processLogs[MootLogging.ident].length == 0
          $processLogs.delete(MootLogging.ident)
        end
        $openLogs.delete(@name)
      end
    end
    def self.watch(name, data = {})
      logging = MootLogging.register(name, data[:overwrite])
      logStat = File.open($base + "MootLogsInfo", mode: 'a' )
      logStat << "pid: #{Process.pid} \n"
      logStat << "th-cr: #{Thread.current.to_s} \n"
      logStat << "th-cr-oid: #{Thread.current.object_id} \n"
      logStat << self.debug
      logStat << "\n"  
      logStat.close()
      begin
        if data != {}
          ret = yield(logging, data)
        else
          ret = yield(logging)
        end
      rescue Exception => e
        logging.puts "_______________ERROR______________"
        logging.puts "#{e.class}"
        logging.puts "#{e.message}"
        for a in e.backtrace
          logging.puts a
        end
        raise e
      ensure
        logging.deregister
      end
      return ret
    end
    def puts(str)
      @file << str
      @file << "\n"
      @file.fsync
    end
    def print(str)
      @file << str
      @file.fsync
    end
  end
  #helper methods, instance calls class methods for ease of use. They are one line because they should generally be
  #ignored, since they do not handle any logic themselves.
  def logWatch(name, data={}, &blk); return MootLogs.logWatch(name, data, &blk); end
  def self.logWatch(name, data={}, &blk)
    return MootLogging.watch(name, data, &blk)
  end
  def p(text)
    MootLogging.getMine.puts text.to_s
  end
  def self.p (text)
    MootLogging.getMine.puts text.to_s
  end
  def pr(text)
    MootLogging.getMine.print text.to_s
  end
  def self.pr (text)
    MootLogging.getMine.print text.to_s
  end
  def pp(obj)
    txt = JSON.pretty_generate(obj)
    MootLogging.getMine.print txt
  end
  def self.pp (obj)
    txt = JSON.pretty_generate(obj)
    MootLogging.getMine.print txt
  end
  def cal()
    return MootLogging.getMine
  end
  def self.cal #standing for Current Active Log
    return MootLogging.getMine
  end #quickly access the current log (shortcut)
end

TIMEAT ={
  apiTime: 0,
  dbTime: 0
}

module Meritmoot
  extend MootLogs
  #note that lscpu can help one find thread max
  #note that threads are disabled 1
  def self.deployThreads(inf, opt={} , &fromTo)
    # Extremely useful for efficiently moving large amounts of data quickly.
    # FromTo is a block that functions as so - 
    # { |type, inf, n|
    #  if type == "from" -> get the api information and store it for information #n and utilizing additional data in inf.
    #       next that data, or if error return -1 to stop getting information.
    # elsif type == "to" -> database upsert query. Reference my database upsert query. returns whatever
    #}

    #optional arguments in ruby may aswell not exist as it doesnt care what optional variable you are assigning
    #to. For example if above was (inf, threadNum=20, flushAt=100) and you put in (*inf, flushAt=3000) it would assign
    #threadNum to 3000, and flushAt would be 100. So allways use an option hash you merge with the defaults.
    opt = {threadNum: 20, flushAt: 100}.merge(opt)
    threadNum = opt[:threadNum]
    flushAt = opt[:flushAt]
    p "threaded api, persistent connections - #{threadNum} threads, flushes to db every #{flushAt}."

    muttLock = Mutex.new #prevents same time writes
    lst = []
    thrds = []
    n = 0
    x = 1
    stillGood = true
    while stillGood
      apiStart = Time.now()
      while stillGood and n < (flushAt * x)
        #sleep(1)
        if thrds.length >= threadNum
          sleep(0.1)
          for th in thrds
            if not th.alive?
              th.join
              thrds.delete(th)
            end
          end
        else
          n = n + 1
          n % 50 == 0 ? pr("t") : nil
          theNum = thrds.length
          thrds << Thread.new(n) do |n, theNum|
            tryAgain = true
            trys = 1
            while tryAgain
              begin
                out = fromTo.call('from', inf, n)
                if out == -1
                  stillGood = false #out of nums, invalid req
                else
                  #prevents same time write
                  muttLock.synchronize {
                    #updates that list
                    lst.append(out)
                  }
                end
                tryAgain = false
              rescue Net::OpenTimeout, Meritmoot::TooManyApiRequests, Timeout::Error => e
                logWatch("Thread-err", {e: e, thrdNum: theNum}) { |l, inf|
                  p "#{e.class} error, reducing thread count 3 and sleeping 30 before next attempt"
                  tryAgain = true
                  raise e if trys == 10
                  trys += 1
                  #my simple slowdown mechanism for when my threads spit hot internet fire that lights the system causing the
                  #   man to see that his. time. is. out. timeout. 443 or timeout error biiitch
                  if threadNum > 0
                    muttLock.synchronize { threadNum -= 3 }
                    sleep(30)
                    muttLock.synchronize { threadNum += 3 }
                  else
                    p "in long sleep"
                    sleep(180)
                  end
                  p "try: #{trys}"
                  p "retrying thrdNum: #{inf[:thrdNum].to_s}, try #{trys}"
                }
              end
            end
          end
        end
      end
      for th in thrds
        th.join
        #puts("#{th} #{th['val']}")
        #lst = lst + th['val']   
      end
      pr "list length: #{lst.length}"
      thrds = []
      p("- #{x}:#{n}")
      TIMEAT[:apiTime] += Time.now() - apiStart
      dbStart = Time.now()
      fromTo.call('to', lst, -1)
      TIMEAT[:dbTime] += Time.now() - dbStart
      p "APITIME: #{TIMEAT[:apiTime]} DBTIME: #{TIMEAT[:dbTime]} - #{TIMEAT[:dbTime] / (TIMEAT[:apiTime] + TIMEAT[:dbTime])}% spent on DBTIME"
      lst = []
      x = x + 1
    end
  end

  STATES = {
      "AK" => 'Alaska',
      "AL" => 'Alabama',
      "AR" => 'Arkansas',
      "AS" => 'American Samoa',
      "AZ" => 'Arizona',
      "CA" => 'California',
      "CO" => 'Colorado',
      "CT" => 'Connecticut',
      "DC" => 'Washington D.C.',
      "DE" => 'Delaware',
      "FL" => 'Florida',
      "GA" => 'Georgia',
      "GU" => 'Guam',
      "HI" => 'Hawaii',
      "IA" => 'Iowa',
      "ID" => 'Idaho',
      "IL" => 'Illinois',
      "IN" => 'Indiana',
      "KS" => 'Kansas',
      "KY" => 'Kentucky',
      "LA" => 'Louisiana',
      "MA" => 'Massachusetts',
      "MD" => 'Maryland',
      "ME" => 'Maine',
      "MI" => 'Michigan',
      "MN" => 'Minnesota',
      "MO" => 'Missouri',
      "MP" => 'Northern Mariana Islands',
      "MS" => 'Mississippi',
      "MT" => 'Montana',
      "NC" => 'North Carolina',
      "ND" => 'North Dakota',
      "NE" => 'Nebraska',
      "NH" => 'New Hampshire',
      "NJ" => 'New Jersey',
      "NM" => 'New Mexico',
      "NV" => 'Nevada',
      "NY" => 'New York',
      "OH" => 'Ohio',
      "OK" => 'Oklahoma',
      "OR" => 'Oregon',
      "PA" => 'Pennsylvania',
      "PR" => 'Puerto Rico',
      "RI" => 'Rhode Island',
      "SC" => 'South Carolina',
      "SD" => 'South Dakota',
      "TN" => 'Tennessee',
      "TX" => 'Texas',
      "UT" => 'Utah',
      "VA" => 'Virginia',
      "VI" => 'Virgin Islands',
      "VT" => 'Vermont',
      "WA" => 'Washington',
      "WI" => 'Wisconsin',
      "WV" => 'West Virginia',
      "WY" => 'Wyoming' 
    }
  EARLIEST_SUPPORTED_CONGRESS = 113 #may lead to breakages but this onl2y takes us back to, like, 2013. Supporting earlier is an easy improvement
    #but may lead to extra logic
  CURRENT_CONGRESS = 116 #need to update this as congresses continue
  PP_KEY="password_filtered"  
  PP_VERS="v1"

  def self.fstSecndThrdEtc(num)
    # 1 -> 1st etc.
    #does not support negatives
    begin
      num = num.to_i
    rescue
      return num
    end
    twoDigits = num % 100
    if 10 < twoDigits && twoDigits < 20
      return num.to_s + "th"
    elsif twoDigits % 10 == 1
      return num.to_s + "st"
    elsif twoDigits % 10 == 2
      return num.to_s + "nd"
    elsif twoDigits % 10 == 3
      return num.to_s + "rd"
    else
      return num.to_s + "th"
    end
    return -1
  end

  def self.shortStateLongState(st)
    st = st.upcase
    if Meritmoot::STATES.has_key?(st)
      return Meritmoot::STATES[st]
    else
      return st
    end
    return -1
  end

  class Engine < ::Rails::Engine
    engine_name "Meritmoot".freeze
    isolate_namespace Meritmoot

    config.after_initialize do
      Discourse::Application.routes.append do
        mount ::Meritmoot::Engine, at: "/meritmoot"
      end
    end
  end

  class Mootdb
    extend MootLogs
     
    ATTR = {
      dtd: nil #date today
    }
    
    def self.voteFailsChecks?(vote, rc)
      fails = vote[:mmmember_id] == nil or
        vote[:mmmember_id].length != 7 or
        vote[:mmrollcall_id] == nil or
        vote[:mmrollcall_id].count("-") != 3 or
        vote[:vote_position] == nil or
        vote[:vote_position] == ""
      fails ? p("FAILING VOTE!!!!!!!! #{vote.inspect} \n rc: #{rc.inspect}") : nil
      return fails
    end

    def self.connectRollCallsToBills(formattedRollCallList)
      frcl = formattedRollCallList
      confirmed = MmCategoryUpdate.bills_exists(frcl.map{|rc| rc[:bill_id]}.select{|a| (not a.nil?) and (not a == "") })
      confirmed = confirmed.map{|ha| [ ha["bill_id"], ha["topic_id"] ] }.to_h
      y = 0
      x=0; while x < frcl.length
        rc=frcl[x]
        topic_id = confirmed[rc[:bill_id]]
        if topic_id != nil #did we find the bill? Everything ok?
          y += 1
          rc[:bill_title] = "<a href= \"/t/#{topic_id}\"> #{rc[:bill_title]} </a>"
        end
      x+=1; end
      p "#{100 * y / x}% rollcalls connected to their bills"
      
    end

    def self.connectBillsToRollCalls(formattedBillList)
      fbl = formattedBillList
      confirmed = MmCategoryUpdate.roll_calls_exists(fbl.map{|bl| bl[:bill_id]})
      conh = {} #as in confirmed hash
      confirmed.map!{|c|
        #actions does not provide all the necessary information to identify the roll call as we would normally do.
        #instead we identify by bill_id and rollcall#. Then we select that rollcall in the list (as for instance, 
        #maybe we have congress, house/senate, session based duplicated roll call numbers for the same bill) which is
        #closest in time.  
        id = [c['bill_id'], c['roll_call']]
        createdAt = c['date'].split('-')
        createdAt += c['time'].split(':')
        createdAt = Time.new(*createdAt)
        conh[id] = [] if conh[id].nil?
        conh[id] << {topic_id: c['topic_id'], title: c['question'], created_at: createdAt}
      }
      total = 0
      replaced = 0
      z=0; while z < fbl.length
        #iterate through the bills
        bill = fbl[z]
        x = 0; while x < bill[:bulk]["actions"].length
          #iterate through that bills various actions
          roll = bill[:bulk]["actions"][x]["roll"]
          if roll != nil #see if the action involves a rollcall
            total+=1
            id = [bill[:bill_id], roll]
            if conh[id] != nil and conh[id].length != 0 #see if we have that rollcall handled
              replaced+=1
              acted_at = Time.parse(bill[:bulk]["actions"][x]["acted_at"])
              #why does everything I code end up doing some crazy shit like this
              #its like I allways hit the fucking edge case. Like look what I'm fucking doing rn
              info = conh[id].sort{|a,b|
                (a[:created_at] - acted_at).abs <=> (b[:created_at] - acted_at).abs
              }[0]
              tid = info[:topic_id]
              title = info[:title]
              bill[:bulk]["actions"][x]["roll"] = "<a href=\"/t/#{tid}\">#{title}</a>"
            end
          end
        x+=1; end
      z+=1; end
      p "#{100 * replaced / total}% bill rolls connected to their roll calls"
    end

    def self.formatUpsertRollCallsAndVotes(rollCallDat)
      #NOTE - to allow for timestamps to determine vote update time (as for some reason it takes a fuggin lifetime)
      #we are moving the rollcallvote upsert into the rollcall upsert.
      if rollCallDat.length == 0
        return
      end
      rcs = []
      #have to shuffle votes before entering them as b-tree
      voteGrp = []
      nm = 0
      vnm = 0
      Mootdb::ATTR[:dtd] = Date.today()
      updateCols = Mmrollcall::propublicaUpdateCols
      voteUpdateCols = Mmrollcallvote::propublicaUpdateCols
      p "roll call data length: #{rollCallDat.length} \n"
      for rc in rollCallDat
        nm += 1
        rcForm = {}
        #some formatting...
        rc.transform_keys! {|k| k.to_sym }
        rc[:democratic_majority_position] = rc[:democratic]["majority_position"]
        rc[:democratic_yes] = rc[:democratic]["yes"]
        rc[:democratic_no] = rc[:democratic]["no"]
        rc[:republican_majority_position] = rc[:republican]["majority_position"]
        rc[:republican_yes] = rc[:republican]["yes"]
        rc[:republican_no] = rc[:republican]["no"]
        rc[:total_yes] = rc[:total]["yes"]
        rc[:total_no] = rc[:total]["no"]
        rc[:bill_id] = rc[:bill]["bill_id"]
        #primBil = Mmbill.find_by(bill_id: rc[:bill_id])
        #primBil == nil ? rc[:bill_primary_id] = nil : rc[:bill_primary_id] = primBil.id
        rc[:primary_bill_id] = nil #may not actually end up using this, probably use mm_primary instead
        rc[:bill_number] = rc[:bill]["number"]
        rc[:bill_title] = rc[:bill]['title'] #link later to the thing :P
        rc[:created_at] = Time.now #note these 2 are fucked with down the line(depending on if update etc.)
        rc[:updated_at] = Time.now
        rc[:moot_tagging] = [] #moot tagging cant be null
        votes = rc[:positions]
        father = rc[:mm_primary]
        rez = rc.slice(*updateCols)
        rcs << rez
        for vote in votes
          vnm += 1
          vote = vote.transform_keys! {|k| k.to_sym}
          vote[:mmrollcall_id] = father
          vote[:mmmember_id] = vote[:member_id]
          next if voteFailsChecks?(vote, rc)
          voteGrp << vote.slice(*voteUpdateCols)
        end
      end
      grps = voteGrp.group_by{|v| v} #group by itself to find duplicates
      logWatch("database_irregularities"){|l|
        wtf = grps.select{|k, v| v.size > 1}
        if wtf.size > 0
          l.puts "\"DUPLICATES\": [ \n #{wtf.map{|rcl| [rcl[0][:bill_id], rcl.length] }} ]"
        end
      }
      voteGrp = grps.map{|k, v| k} #remove duplicates
      #upsert rest
      p "\n"
      p "rcs len #{rcs.length}"
      Mootdb.connectRollCallsToBills(rcs)
      Mmrollcall.upsertList(rcs) #custom func
      p "\n"
      p "rcsvt len #{voteGrp.length}"
      Mmrollcallvote.upsertList(voteGrp) #custom func
      #UPSERT VOTES (shufffle due to btree)
      #Also, make sure we dont update ALL the votes, just ones that have not been updated for like, a month.
      #   or ever.
      
      #rollCallDat.shuffle!
      #rcallsUpdated = []
      #update new stuff and more out of date stuff first (new stuff -> year 2000)
      #main reason for this is to make sure general updates dont overload the system
      #and prevent upsert of new material.      
      #vnm = Mootdb.updateVoteSched(rollCallDat, vnm) { |creatDif, upDif| 
#        next creatDif < 9 || upDif > 40 
      #}
      #update the bulk of other stuff, above wont be included as datedif == 0.
      #rand is to spread load out evenly and avoid overloaded days.
      #Mootdb.updateVoteSched(rollCallDat, vnm) { |creatDif, upDif| 
        #next upDif > (25 + Random.rand(10)) 
      #}
      #shuffle and upsert the rest.
    end

    def self.connectBillsToBillAffects(affectInfo)
      #"bioguide_id": "Y000062", 
      #"district": "3", 
      #"name": "Yarmuth, John A.", 
      #"original_cosponsor": false, 
      #"sponsored_at": "2019-01-09", 
      #"state": "KY", 
      #"title": "Rep", 
      #"withdrawn_at": null  
      
      #"bioguide_id": "S001168", 
      #"district": "3", 
      #"name": "Sarbanes, John P.", 
      #"state": "MD", 
      #"title": "Rep", 
      #"type": "person"
      #affectz << { cosponsor: bulk["cosponsors"], sponsor: bulk["sponsor"], bill_id: bill[:bill_id] }

      #@@defaults = {
        #affect: nil,
        #mmmember_id: nil,
        #bill_id: nil,
      #}

      affects = []
      for affect in affectInfo
        spon = affect[:sponsor]
        if spon
          affects << { affect: "sponsor", mmmember_id: spon["bioguide_id"], bill_id: affect[:bill_id] }
        end
        if affect[:cosponsor]
          for co in affect[:cosponsor]
            if co["withdrawn_at"] != nil and co["original_cosponsor"]
              affects << { affect: "withdrew-original-consponsorship", mmmember_id: co["bioguide_id"], bill_id: affect[:bill_id] }
            elsif co["withdrawn_at"] != nil
              affects << { affect: "withdrew-consponsorship", mmmember_id: co["bioguide_id"], bill_id: affect[:bill_id] }
            elsif co["original_cosponsor"]
              affects << { affect: "original-cosponsor", mmmember_id: co["bioguide_id"], bill_id: affect[:bill_id] }
            else
              affects << { affect: "cosponsor", mmmember_id: co["bioguide_id"], bill_id: affect[:bill_id] }
            end
          end
        end
      end
      Mmbillaffect.upsertList(affects)
    end
  end

  class Propub
    include HTTParty
    include MootLogs
    headers 'Accept' => 'text/html'
    base_uri 'https://api.propublica.org'

    #CLEAN
    def currentCongress
      #wow. Just wow. Really ruby?
      @currentCongress
    end

    def earliestSupportedCongress
      @earliestSupportedCongress
    end
    #CLEAN
    def initialize(key, version, earliestSupportedCongress=Meritmoot::EARLIEST_SUPPORTED_CONGRESS, currentCongress=Meritmoot::CURRENT_CONGRESS)
      #information subject to change
      p "initialize is initing."
      p "key #{key}"
      p "version #{version}"
      p "earl #{earliestSupportedCongress}"
      p "curr #{currentCongress}"
      @PpKey = key #for propublica
      @version = version
      @earliestSupportedCongress = earliestSupportedCongress
      @currentCongress = currentCongress
      @urlCongress = "/" + @currentCongress.to_s
      @urlBase = "/congress/" + @version
      @baseUri = 'https://api.propublica.org'
      @logMutex = Mutex.new
      @http = nil
    end
    #Moving to https://github.com/bpardee/persistent_http/tree/0a07dd638e2694756e6cdb18c20838b345559f73
    def persistence()
      @http = PersistentHTTP.new(
        name: 'moot_api',
        pool_size: 30,
        pool_timeout: 10,
        url: URI.parse(@baseUri + @urlBase),
        headers: {'X-API-Key' => @PpKey}
      )
      yield
      @http.shutdown
      @http = nil
    end
    #CLEAN
    def getCommitteeInfo(congress, chamber)
      #curl "https://api.propublica.org/congress/v1/115/senate/committees.json"
      comBase = @urlBase + "/" + congress.to_s + "/" + chamber.to_s + "/committees.json"
      options={
        headers: {
          'X-API-Key' => @PpKey
        }#, query: {}
      }
      coms = self.class.get(comBase, options)
      if coms["status"] == "OK"
        coms = coms["results"][0]["committees"]
        coms.map() {|committee| committee[:mm_primary] = committee[:id]}
        coms.map() {|committee| committee.delete(:id)} #id reserved for rails
        return coms
      else
        p("\n  - #{coms["status"]}, ")
        p("all of coms: #{coms.inspect()}")
        raise "committee get error"
      end
    end

    def fillCommittees #depreciated
      chambers = ["house", "senate"]
      cong = @earliestSupportedCongress
      while cong <= @currentCongress
        for ch in chambers
          #add urls
          coms = getCommitteeInfo(cong, ch)
          Mmcommittee.upsertList(coms)
        end
        cong += 1
      end
    end

    def getRollCallVotes (congress, session, chamber, roll_call_num, out=false)
      #GET https://api.propublica.org/congress/v1/{congress}/{chamber}/sessions/{session-number}/votes/{roll-call-number}.json
      #logWatch("RollCallVote") { |l|
        rollBase = @baseUri + @urlBase + "/" + congress.to_s + "/" + chamber.to_s + "/sessions/" + session.to_s + "/votes/" + roll_call_num.to_s + ".json"
        uri = URI.parse(rollBase)
        reqSetup = Net::HTTP::Get.new(uri)
        reqSetup.add_field('X-API-Key', @PpKey)
        rollResp = @http.request(reqSetup)
        roll = JSON.parse(rollResp.body)
#        JSON::ParserError
#Empty input () at line 1, column 1 [parse.c:995] in <html>
#<head><title>503 Service Temporarily Unavailable</title></head>
#<body bgcolor="white">
#<center><h1>503 Service Temporarily Unavailable</h1></center>
#</body>
#</html>
        #roll = self.class.get(rollBase, options)
        if roll["status"] == "OK" and roll["results"] and roll["results"]["votes"] and roll["results"]["votes"]["vote"]
          #l.p "rc returned"
          return roll["results"]["votes"]["vote"]
        else
          begin
            if out == true
              @logMutex.synchronize() {
                logWatch("RollCallIssue") { |l| 
                  l.puts("\n  - #{roll["status"]}, ")
                  l.puts("#{roll["errors"][0]["error"]}")
                }
              }
            end
          rescue
            @logMutex.synchronize() {
              logWatch("RollCallIssue") { |l|
                l.puts "ERROR NOT IN EXPECTED FORMAT 🐍😭🐍😭🐍😭🐍😭🐍😭🐍😭🐍😭🐍😭🐍😭🐍😭🐍😭"
                l.puts "#{roll}"
              }
            }
          end
          #l.puts "returning -1 \nroll: #{roll}"
          #logWatch("debug") {
            #p "#{congress} #{session} #{chamber} ##{roll_call_num}"
            #p "returning -1 for rollcallvote, rollResp:#{rollResp.inspect}, roll: #{roll.inspect}"
          #}
          return -1
        end
      #}
    end
     
    #CLEAN
    def fillRollCalls(pout=false, testLimit = 611686018427387903) #pout means print out
      #return a list of votes including voteId and such
      p "in fillVotes"
      escTemp = @earliestSupportedCongress
      cgrTemp = @currentCongress
      p "earliest: #{escTemp}, current: #{cgrTemp}"
      rolls = []
      #go through the diffrent options
      while cgrTemp >= escTemp
        chambers = ["house", "senate"]
        chamber = 0
        while chamber <= 1
          session = 1
          while session <= 2
            Meritmoot.deployThreads({ cg: cgrTemp.to_s,
               se: session.to_s, 
               ch: chambers[chamber].to_s,
               testLimit: testLimit,
               pout: pout }, {flushAt: 3000}) { |type, inf, n|
              if type == "from"
                out = getRollCallVotes(inf[:cg], inf[:se], inf[:ch], n, inf[:pout])
                if out == -1 or n > inf[:testLimit]
                  next -1
                end
                out["mm_primary"] = "#{inf[:cg]}-#{inf[:ch]}-#{inf[:se]}-#{n}"
                next out
              elsif type == "to"
                p "information length: #{inf.length}"
                Mootdb.formatUpsertRollCallsAndVotes(inf)
              end
            }
            pout == true ? p("=======================================") : nil
            pout == true ? p("NEXT SESSION") : nil
            pout == true ? p("=======================================") : nil
            session = session + 1
          end
          chamber = chamber + 1
        end
        cgrTemp = cgrTemp - 1
      end
      return rolls
    end
    #NAF
     
    def getCosponsors(bill)
      cosponsorUri = bill['bill_uri']
      cosponsorUri['.json'] = '/cosponsors.json'
      begin
        uri = URI.parse(cosponsorUri)
        reqSetup = Net::HTTP::Get.new(uri)
        reqSetup.add_field('X-API-Key', @PpKey)
        reqRet = @http.request(reqSetup)
        cosps = JSON.parse(reqRet.body)
        if cosps['status'] == 'OK'
          x = 0
          #p cosps
          cosps = cosps['results'][0]
          cosps = cosps['cosponsors']
          final = []
          while x < cosps.length
            inf = {}
            inf[:affect] = 'cosponsor'
            inf[:bill_id] = bill['bill_id']
            inf[:mmmember_id] = cosps[x]['cosponsor_id']
            final << inf
          x+=1; end
          Meritmoot.asshurt("final is not array: #{final.inspect}") { final.class == Array }
          return final
        else
          @logMutex.synchronize() {
            logWatch("cosponsors_issue"){
              p "cosponsors went neurotic"
              p "reqRet: #{reqRet.inspect}"
              p "body: #{cosps.inspect}"
              p "uri: #{cosponsorUri}"
            }
          }
          return []
        end
      rescue Exception => e
        @logMutex.synchronize() {
          logWatch("cosponsors_issue"){
            p e.message
            p e.class
            p cosps
          }
        }
        return []
      end
    end
    
    def processBills
      billz = []
      affects = []
      now = Time.now.utc
      p `pwd`
      tagFile = File.open("plugins/meritmoot/lib/meritmoot/tags.json")
      tags = JSON.parse(tagFile.read)
      unhandledSubjects = {}
      n = 1
      #processeZippedBills deals with the zipping/filenavigation/parsing and passes back
      #individual bill information into our code-block which will be run on all bills.
      processZippedBills { |bulk|
        bill = {}
        bill[:bill_id] = bulk["bill_id"]
        if bulk["subjects"]
          #translate bill subjects to their tags
          count = {}
          moot_tagging = bulk["subjects"].map{|s| 
            if tags[s].nil?
              #if unhandled add to list along with incrementing reference count
              unhandledSubjects[s]=0 if unhandledSubjects[s].nil?
              unhandledSubjects[s] += 1
            end
            next tags[s]
          }.select{|t| t != nil and t != "" }.flatten.map { |t|
            #count tags
            count[t] = 0 if count[t].nil?
            count[t] += 1
          }
          #get top 5 and store in bulk
          bulk["moot_tagging"]=count.keys.max(5){|a,b| count[a] <=> count[b]}
        end
        affects << { cosponsor: bulk["cosponsors"], sponsor: bulk["sponsor"], bill_id: bill[:bill_id] }
        bulk = bulk.slice( * Mmbill.bulk_tracked )
        #set bill up 
        bill[:created_at] = now
        bill[:updated_at] = now
        bill[:do_reformat] = 'no' #WE NEED THIS
        begin
          Time.parse(bulk["history"]["active_at"])
        rescue Exception => e
          logWatch("err") {
            p "times fucked up"
            p "active at: #{bulk[:active_at]}, printing data"
            pp bulk
          }
          raise e
        end
        raise StandardError.new("empty_bulk") if bulk == {}
        raise StandardError.new("bulk aint a hash") if bulk.class != Hash
        bill[:bulk] = bulk
        
        billz << bill
        if n % 1000 == 0
          p "early bill upsert @ #{n}"
          Mootdb.connectBillsToBillAffects(affects)
          affects = []
          Mootdb.connectBillsToRollCalls(billz)
          Mmbill.upsertList(billz)
          billz = []
          logWatch("unhandledSubjs", {overwrite: true}) {
            unhandledSubjects.keys.max(1000) { |a,b| unhandledSubjects[a] <=> unhandledSubjects[b] }.map{ |k,v|
              p "  \"#{k}\": \"#{v}\","
            }
          }
        end
        n += 1
      }
      p "DONE PROCESSING THE #{n} BILLS. BILLZ @ len #{billz.length}"
      logWatch("unhandledSubjs", {overwrite: true}) {
        unhandledSubjects.keys.max(1000) { |a,b| unhandledSubjects[a] <=> unhandledSubjects[b] }.map{ |k,v|
          p "#{k}: [v],"
        }
      }
      if billz.length != 0
        Mootdb.connectBillsToBillAffects(affects)
        Mootdb.connectBillsToRollCalls(billz)
        Mmbill.upsertList(billz)
      end
    end

    def _readBillBody(r, bulkFile)
      if r.code.to_i == 200
        p "Zip Content Type #{r["content-type"]}"
        p "setting to UTF-8"
        r.body.force_encoding("UTF-8")
        bulkFile << r.body
        p "done"
      else
        raise(StandardError.new("not 200 #{r.code}"))
      end
    end
    
    def _remove_dir(path)
      #https://stackoverflow.com/questions/12335611/ruby-deleting-directories
      if File.directory?(path)
        Dir.foreach(path) do |file|
          if ((file.to_s != ".") and (file.to_s != ".."))
            _remove_dir("#{path}/#{file}")
          end
        end
        Dir.delete(path)
      else
        File.delete(path)
      end
    end

    def processZippedBills(&blk)
      uriStrt = "https://s3.amazonaws.com/pp-projects-static/congress/bills/"
      uriEnd = ".zip"
      cong = @currentCongress
      lowCong = @earliestSupportedCongress
      stub = "moot_zip_"
      now = Time.now
      host = URI.parse("https://s3.amazonaws.com")

      #cleanup past directories and files older than a day
      delmes = Dir.entries("/tmp")
      delmes = delmes.select{ |d| d[stub] != nil } #make sure we own them
      delmes.map!{|nm| "/tmp/#{nm}"}

      #if we have a recent update, use that instead of calling the endpoint again (good for testing)
      useInstead = delmes.select{|file| (now - File.ctime(file)) < (1.5 * 60 * 60) }

      #continue deletion
      delmes = delmes.select{|file| (now - File.ctime(file)) > (1 * 24 * 60 * 60) }
      for file in delmes
        _remove_dir(file)
      end
  
      while cong >= lowCong
        #we have saved information ?
        alternatives = useInstead.select{|nm| nm["_#{cong}-"] != nil and nm["_dir"] != nil}
        dirLoc = nil #location of directory file is extracted into
        if alternatives.length == 0
          p "Getting new bill info"
          #no - hit the endpoint and unzip
          bulkFile = nil #file object
          fileLoc = nil #files location
          Net::HTTP.start(host.host) do |http|
              #   Get the Data
            uri = uriStrt + cong.to_s + uriEnd
            uri = URI.parse(uri)
            file = stub + cong.to_s + "-" + Time.now.utc.to_i.to_s
            dirLoc = "/tmp/" + file + "_dir"
            fileLoc = "/tmp/" + file
            bulkFile = File.new(fileLoc, "w+")
            FileUtils.mkdir_p(dirLoc)
            why = 0
            http.request_get(uri) do |r|
              why != 0 ? next : nil
              why = "the fuck" #do i have to do this fuck this library
              if r.code.to_i == 301 or r.code.to_i == 302
                p "--> Redirected"
                uri = URI.parse(r.header['location'])
                Net::HTTP.start(uri.host) do |newhttp|
                  newhttp.request_get(uri) do |r|
                    _readBillBody(r, bulkFile)
                  end
                end
              else
                _readBillBody(r, bulkFile)
              end
              p "at end of get"
            end
          end
          bulkFile.close
          p "bulkFile: #{bulkFile.inspect}"
          #   Extract the data
          Zip::File.open(bulkFile) do |zipFile|
            #puts "zippy: #{zipFile.inspect}"
            zipFile.each do |f|
              #p "fclass: #{f.class}"
              loc = File.join(dirLoc, f.name)
              FileUtils.mkdir_p(File.dirname(loc))
              zipFile.extract(f, loc)
            end
          end
          #close and delete e file
          bulkFile.close unless bulkFile.closed?
          File.delete(fileLoc)
        else
          #there is a very recent one, so we are testing. Skip the boring shit
          p "recycling past bill information"
          file = alternatives[0]
          dirLoc = file
        end
        #    Read the data
        if cong == 115
          #    ffs propublica
          dirCats = dirLoc + "/115/bills"
        else
          dirCats = dirLoc + "/congress/data/#{cong}/bills"
        end
        for billCat in (Dir.entries(dirCats))
          next if billCat[0] == "."
            
          billCat = dirCats + "/" + billCat
          for bill in (Dir.entries(billCat))
            next if bill[0] == "."
            begin
              datFile = File.open("#{billCat}/#{bill}/data.json", "r")
            rescue Errno::ENOENT => e
              pr "🤢"
              logWatch("database_irregularities") {
                p "#{billCat}/#{bill}/data.json"
                p e.message
              }
              next
            end
            dat = JSON.parse(datFile.read())
            #CHECK EQUALITY, RECORD, OUTPUT
            if dat["history"] and dat["history"]["active"]
              #CALLS PROVIDED BLOCK HERE WITH BILL DATA
              blk.call(dat)
            end
            datFile.close()
          end
        end
      cong-=1; end
      #ez = `rm -rf /tmp/#{stub}*`
    end

    def getPpl (congress, branch)
      # gets house members active in house / senate
      # used in get congressmen
      #GET https://api.propublica.org/congress/v1/{congress}/{chamber}/members.json
      
      conBase = @urlBase + "/"
      conBase = conBase + congress.to_s + "/" 
      conBase = conBase + branch.to_s + "/members.json"
      options = { headers: { 'X-API-Key' => @PpKey, 'in_office' => "True" } }
      self.class.get(conBase, options)
    end
     
    def fillMembers()
      #MUST BE IN ORDER OF OLDEST TO MOST RECENT CONGRESS
      congress = self.earliestSupportedCongress
      while congress <= self.currentCongress
        #get members of house, 
        house = self.getPpl(congress, "house")
        #get members senate
        senate = self.getPpl(congress, "senate")
        members = []
        if house["status"] == "OK"
          #note from house
          houseMems = house["results"][0]["members"]
          num = 0
          while num < houseMems.length
            #label house
            houseMems[num]['mm_chamber'] = 'House'
            #get ref str
            houseMems[num]["mm_reference_str"] = houseMems[num]['first_name'] + " " + houseMems[num]['last_name']
            if congress != self.currentCongress
              houseMems[num]['mm_reference_str'] += " (#{Meritmoot.fstSecndThrdEtc(congress)} congress)"
            else
              houseMems[num]['mm_reference_str'] += " (#{houseMems[num]['state']}#{houseMems[num]['district']})"
            end
            num = num + 1
          end
          #add to all list
          members.concat(houseMems)
        end

        if senate["status"] == "OK"
          #note from senate.
          senateMems = senate["results"][0]["members"]
          num = 0
          while num < senateMems.length
            #label senate
            senateMems[num]['mm_chamber'] = 'Senate'
            #get ref str
            senateMems[num]["mm_reference_str"] = senateMems[num]['first_name'] + " " + senateMems[num]['last_name']
            if congress != self.currentCongress
              senateMems[num]['mm_reference_str'] += " (#{congress}th)"
            else
              senateMems[num]['mm_reference_str'] += " (#{senateMems[num]['state']})"
            end
            num = num + 1
          end
          #add to lsit
          members.concat(senateMems)
        end
        num = 0
        while num < members.length
          members[num]['mm_latest_congress'] = congress.to_s
          members[num]['mm_first_lower'] = members[num]['first_name'].downcase
          members[num]['mm_last_lower'] = members[num]['last_name'].downcase
          members[num]['mm_primary'] = members[num]['id']
          members[num]['mm_reference_str_lower'] = members[num]['mm_reference_str'].downcase
          num = num + 1
        end
        Mmmember.upsertList(members)
        congress += 1
      end
    end
  end
   
  class Controller
    include MootLogs

    def initialize(dat={})
      defaults = {
        ppkey: Meritmoot::PP_KEY,
        ppvers: Meritmoot::PP_VERS,
        earliestSupportedCongress: Meritmoot::EARLIEST_SUPPORTED_CONGRESS,
        currentCongress: Meritmoot::CURRENT_CONGRESS
        #db_pwd: 'slammedDrunk/785',
        #db_name: 'moot',
        #db_usr: 'postgres',
        #civ_key: "password_filtered"
      }
      dat = defaults.merge(dat)
      class << self; #not completely sure tb honest
        attr_accessor :mdb #http://www.railstips.org/blog/archives/2006/11/18/class-and-instance-variables-in-ruby/
      end
      @caller = Propub.new(key = dat[:ppkey], version = dat[:ppvers], earliestSupportedCongress = dat[:earliestSupportedCongress], currentCongress = dat[:currentCongress])
      #@mdb = MootDb.new(dat[:db_pwd], dat[:db_usr], dat[:db_name])
      #@capi = CivicAPI.new(key)
    end

    def fillRollCalls(pout = true, testLimit = 611686018427387903)
      p "_________________________________NEW_______________________________________"    
      logWatch("custom_migration") { |l|
        l.puts "entering roll call custom migration..."
        if Mmrollcall.column_names.include?("id")
          l.puts "Custom Migrating Mmrollcalls away from id"
          ActiveRecord::Base.connection.execute("ALTER TABLE \"mmrollcalls\" DROP COLUMN IF EXISTS \"id\"")
          Mmrollcall.reset_column_information
          l.puts "success"
        end
        begin
          Mmrollcall.getCatId("Roll Calls")
        rescue ActiveRecord::RecordInvalid => e
          l.puts "creating Roll Calls category"
          Category.create!({
            user: Discourse.system_user,
            name: "Roll Calls"
          })
        end
      }
      #puts "inst #{Mmrollcall.instance_methods}"
      Mmrollcall.clearJobLeftovers(Mmrollcall, :mm_primary)
      @caller.persistence {
        @caller.fillRollCalls(pout = pout, testLimit = testLimit)
      }
      p "done rollcalls"
    end
     
    def fillBills(pout = true, testLimit = 611686018427387903)
      logWatch("custom_migration") { |l|
        if Mmbill.column_names.include?("id")
          l.puts "column names: #{Mmbill.column_names.inspect}"
          l.puts "Custom Migrating Mmbills away from id"
          ActiveRecord::Base.connection.execute("ALTER TABLE \"mmbills\" DROP COLUMN IF EXISTS \"id\"")
          Mmbill.reset_column_information
          l.puts "success"
        end
        begin
          Mmbill.getCatId("Bills")
        rescue ActiveRecord::RecordInvalid => e
          l.puts "creating rollcalls category"
          Category.create!({
            user: Discourse.system_user,
            name: "Bills"
          })
        end
        Mmbill.reset_column_information #useful if you accidently set all columns to strings during a reformat
        #this way when you set it back it will reset column information.
        p "columns: #{Mmbill.columns.inspect()}"
      }
      Mmbill.clearJobLeftovers(Mmbill, :bill_id)
      @caller.processBills()
      p "done bills"
    end
    
    def fillMembers()
      @caller.fillMembers()
    end

    def fillCommittees()
      @caller.fillCommittees()
    end
  end
   
  #SUPPORT
  class AsshurtError < RuntimeError #assert. Get It? Ha. Ha Ha. ITS LIKE ASSERT BUT ASSHURT
  end
  class TooManyApiRequests < Exception
  end
  #SUPPORT
  def self.asshurt(msg="AsshurtError (assert, get it? Lmao so funny guys)", &block)
    raise AsshurtError.new(msg) unless yield
  end
   

  class Tests
    extend MootLogs
    # test untested. Tests diffrences in JSON files between two latest zip downloads
    def self.update_validity_check(cong)
      testing = true
      equals = 0
      ineq = 0
      #parse filenames for most recent.
      otherLocs = Dir.entries("/tmp")
      otherLocs.delete(dirLoc)
      otherLocs = otherLocs.select{ |d| d["moot_#{cong}"] != nil }
      otherLocsUtc = otherLocs.map{ |s| [s.gsub(/\D/, ""), s] } #attach utc to string
      p "otherLocUtc: #{ otherLocsUtc }"
      p "otherLocs: #{ otherLocs }"
      otherLoc = "/tmp/" + otherLocsUtc.max(2){ |a, b| a[0] <=> b[0] }[1][1] #get string from max utc
      dirLoc = "/tmp/" + otherLocsUtc.max(2){ |a, b| a[0] <=> b[0] }[0][1]
      p "OTHERLOC: #{otherLoc.inspect}"
      

      #    Read the data
      if cong == 115
<<<<<<< HEAD
        #ugh propublica why
=======
      #ffs propublica
>>>>>>> 50080a746ede62707d4dd9480bacc227e5140c93
        dirCats = dirLoc + "/115/bills"
        otherCats = otherLoc + "/115/bills"
      else
        dirCats = dirLoc + "/congress/data/#{cong}/bills"
        otherCats = otherLoc + "/congress/data/#{cong}/bills"
      end
      for billCat in (Dir.entries(dirCats))
        next if billCat[0] == "."
        otherCat = otherCats + "/" + billCat
        billCat = dirCats + "/" + billCat
        for bill in (Dir.entries(billCat))
          next if bill[0] == "."
          begin
            datFile = File.open("#{billCat}/#{bill}/data.json", "r")
            otherFile = File.open("#{otherCat}/#{bill}/data.json", "r")
          rescue Errno::ENOENT => e
            pr "🤢"
            logWatch("database_irregularities") {
              p "#{billCat}/#{bill}/data.json"
              p "#{otherCat}/#{bill}/data.json"
              p e.message
            }
            next
          end
          dat = JSON.parse(datFile.read())
          #TST
          otherdat = JSON.parse(otherFile.read())
          #CHECK EQUALITY, RECORD, OUTPUT
          if dat == otherdat
            equals += 1
          else
            ineq += 1
          end
          if (equals + ineq) % 1000 == 0
            p "files equal: #{equals}"
            p "files ineq: #{ineq}"
          end
          otherFile.close() 
          datFile.close()
        end
      end
    end
    def self.test_Bulks
      #TESTING (activate in plugin.rb)
      begin
        p "entered test_bulks"
        post = PostCreator.new(Discourse.system_user,
          title: "mootBulkTest",
          raw: "raw",
          cooked: "change me",
          cook_methods: Post.cook_methods[:raw_html],
          archetype: 'regular',
          created_at: Time.now,
          category: 1,
          is_warning: false,
          shared_draft: false,
          skip_validations: true,
          topic_opts: {skip_validations: true} #passed through post_creator to topic_creator
        )
        post = post.create!()
        p "post topic test start"
        changedIds = MmCategoryUpdate::TopicsBulkAction.postgresql_bulk_post_topic_update([{
          post_id: post.id,
          topic_id: post.topic_id,
          cooked: "Pineapple 78321, search find me?",
          title: "Pineapple",
          updated_at: Time.now(),
          tags: [{tag: "test", tagGroup: "system_tags"}]
        }], "Uncategorized")
        p changedIds.inspect
        p "changedId: #{post}"
        p "Tag Test Start"
      ensure
        p "sleeping for 150 seconds. Test Search"
        #sleep 150
        #Topic.find_by(id: post.topic_id).destroy()
        #post.destroy()
        #p "post destroyed"
      end
    end
  end
end
