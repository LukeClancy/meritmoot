module Meritmoot
  class ActionsController < ::ApplicationController
    requires_plugin Meritmoot


    #SWITCH BELOW GOVINFO THING TO HTTPS ONCE THATS A THING
    def index
      render_json_dump({ actions: [] })
    end

    def show
      render_json_dump({ action: { id: params[:id] } })
    end

    def getbvotes
      begin
        render_json_dump({ "Bvotes" => Bvote.columns.each { |col| 
              { "nm" => col.name,
                "type" => col.type }
        }})
      rescue Exception => e
        render_json_dump({"exception" => {"func" => "getbvotes in ActionsController.",
          "mess" => e.message.to_s, "class" => e.class.to_s, "time" => Time.now.to_s}})
      end
    end

    #before_action :ensure_logged_in
    def getPdf
      #capture errors
      return ::Meritmoot::capture("MootGetBillPdf") {
        require 'net/http'
        #for some reason objectize the uri
        pdfFile = Tempfile.new("tmp.pdf", :encoding => 'ascii-8bit')
        #read_body wont work unless passed into a block for no particular reason ugggggh
        Net::HTTP.get_response(URI.parse('http://www.govinfo.gov/content/pkg/BILLS-116hr502rfs/pdf/BILLS-116hr502rfs.pdf')) do |r|
          if r.code == "301" or r.code=="302"
            Net::HTTP.get_response(URI.parse(r.header['location'])) do |r|
              r.read_body(pdfFile)
              puts r.inspect()
            end
          else
            r.read_body(pdfFile)
            puts r.inspect()
          end
        end
        puts pdfFile.size()
        wat = send_data(pdfFile, filename: "yeeep.pdf", type: 'application/pdf', disposition: 'inline')
        pdfFile.close()
        puts "wat: #{wat.inspect()}"
      }
    end
  end
end
