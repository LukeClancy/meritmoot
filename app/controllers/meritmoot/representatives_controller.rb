#DELETE FILE AFTER JUNE 20 IF NO ISSUES ARISING FROM COMMENTATION OCCUR
module Meritmoot
  class RepresentativesController < ::ApplicationController
    #def memSearch
      #return MootLogs.logWatch("MootApi-memSearch") { |log|
        ##format input for query
        #substr = params["input-str"]
        #if substr == ""
          #return []
        #end
        #substr = substr.split(" ")
        #quer = ""
        #annnd = 0
        #num = 0
        #while num < substr.length
          #annnd ? quer << "AND " : annnd = true #skip first AND, then, subsequently add at beginning.
          #quer << "mm_reference_str_lower LIKE %?%"
          #substr[num] = substr[num].downcase
        #end
#        
        #log.puts "quer: #{quer}"
        #log.puts "substr: #{substr}"
#
        ##get at most 10 from Mmmember where for each word provided, that word is in the member's mm_reference_str (yet to be constructed)
        #mems = Mmmember.limit(10).where(quer, *substr)
        #log.puts "mems #{mems}"

        #make sure we only take what we actually want
        #retMems = []
        #for mem in mems
          #retMem = {
            #mm_reference_str: mem.mm_reference_str,
            #id: mem.id
          #}
          #retMems << retMem
        #end
        #log.puts "retMems: #{retMems}"
        #render json: {memList: retMems}
      #}
    #end
    #def addMem
      #render json: {error: 'not implemented'}
    #end
    #def delMem
    #  render json: {error: 'not implemented'}
    #end
  end
end