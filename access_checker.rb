# Tested in JRuby 1.7.3
# Written by Kristina Spurgin
# Last updated: 20130412

# Usage:
# jruby -S access_checker.rb [inputfilelocation] [outputfilelocation]

# Input file: 
# .csv file with: 
# - one header row
# - any number of columns to left of final column
# - one URL in final column

# Output file: 
# .csv file with all the data from the input file, plus a new column containing
#   access checker result

require 'celerity'
require 'csv'
require 'highline/import'
require 'open-uri'

  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  puts "What platform/package are you access checking?"
  puts "Type one of the following:"
  puts "  apb    : Apabi ebooks"
  puts "  asp    : Alexander Street Press links"
  puts "  cup    : Cambridge University Press"
  puts "  ciao   : Columbia International Affairs Online"  
  puts "  cod    : Criterion on Demand"
  puts "  duphw  : Duke University Press (via HighWire)"
  puts "  ebr    : Ebrary links"
  puts "  ebs    : EBSCOhost ebook collection"
  puts "  end    : Endeca - Check for undeleted records"
  puts "  fmgfod : FMG Films on Demand"
  puts "  kan    : Kanopy Streaming Video"
  puts "  lion   : LIterature ONline (Proquest)"
  puts "  nccorv : NCCO - Check for related volumes"
  puts "  sabov  : Sabin Americana - Check for Other Volumes"
  puts "  scid   : ScienceDirect ebooks (Elsevier)"
  puts "  spr    : SpringerLink links"
  puts "  skno   : SAGE Knowledge links"
  puts "  srmo   : SAGE Research Methods Online links"
  puts "  ss     : SerialsSolutions links"
  puts "  upso   : University Press (inc. Oxford) Scholarship Online links"
  puts "  waf    : Wright American Fiction links"
  puts "  wol    : Wiley Online Library"
  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

  package = ask("Package?  ")

  puts "\nPreparing to check access...\n"

input = ARGV[0]
output = ARGV[1]

csv_data = CSV.read(input, :headers => true)

counter = 0
total = csv_data.count

headers = csv_data.headers
headers << "access"

CSV.open(output, "a") do |c|
  c << headers
end

b = Celerity::Browser.new(:browser => :firefox)
#b = Celerity::Browser.new(:browser => :firefox, :log_level => :all)

if package == "spr" || "ebr" || "kan" || "lion"
    b.css = false
    b.javascript_enabled = false
end

csv_data.each do |r|
  row_array = r.to_csv.parse_csv
  url = row_array.pop
  rest_of_data = row_array

  b.goto(url)
  page = b.html

  if package == "apb"
    sleeptime = 1
    if page.match(/type="onlineread"/)
      access = "Access probably ok"
    else
      access = "Check access manually"
    end  
      
  elsif package == "asp"
    sleeptime = 1    
    if page.include?("Page Not Found")
      access = "Page not found"
    elsif page.include?("error")
      access = "Error returned"
    elsif page.include?("Browse")
        access = "Full access"
    else
      access = "Check access manually"
    end

  elsif package == "ciao"
    sleeptime = 1    
    if page.match(/<dd class="blacklight"><embed src="\/attachments\//)
      access = "Full Access"
    else
      access = "Check access manually"
    end
    
  elsif package == "cod"
    sleeptime = 1    
    if page.include?("Due to additional requirements on the part of some of our studios")
      access = "studio permissions error"
    elsif page.match(/onclick='dymPlayerState/)
        access = "Full access"
    else
      access = "Check access manually"
    end

  elsif package == "cup"
    sleeptime = 1    
    if page.include?("This icon indicates that your institution has purchased full access.")
      access = "Full access"
    else
      access = "Restricted access"
    end        

  elsif package == "duphw"
    sleeptime = 1    
    if page.include?("DOI Not Found")
      access = "DOI error"
    else
      # I could find nothing on the ebook landing page to differentiate those to which we have full text access from those to which we do not.
      # This requires an extra step of having the checker visit one of the content pages, and testing whether one gets the content, or a log-in page
      url_title_segment = page.match(/http:\/\/reader\.dukeupress\.edu\/([^\/]*)\/\d+/).captures[0]
      content_url = "http://reader.dukeupress.edu/#{url_title_segment}/25"
  
      # Celerity couldn't handle opening the fulltext content pages that actually work,
      #  so I switch here to using open-uri to grab the HTML
  
      thepage = ""
      open(content_url) {|f|
        f.each_line {|line| thepage << line}
        }
      
      if thepage.include?("Log in to the e-Duke Books Scholarly Collection site")
        access = "No access"
      elsif thepage.include?("t-page-nav-arrows")
        access = "Full access"
      else
        access = "Check access manually"
      end
    end
  
  
  elsif package == "ebr"
    sleeptime = 1
    if page.include?("Sorry, this ebook is not available at your library.")
      access = "No access"
    elsif page.match(/Your institution has (unlimited |)access/)
      access = "Full access"
    else
      access = "Check access manually"
    end

  elsif package == "ebs"
    sleeptime = 1
    if page.match(/class="std-warning-text">No results/)
      access = "No access"
    elsif page.match(/"available":"True"/)
      access = "Full access"
    else
      access = "check"
    end

  elsif package == "end"
    sleeptime = 1
    if page.include?("Invalid record")
      access = "deleted OK"
    else
      access = "possible ghost record - check"
    end    

  elsif package == "fmgfod"
    sleeptime = 10
    if page.include?("The title you are looking for is no longer available")
      access = "No access"
    elsif page.match(/class="now-playing-div/)
      access = "Full access"
    else
      access = "Check access manually"
    end

  elsif package == "kan"
    sleeptime = 10
    if page.include?("Your institution has not licensed")
      access = "No access"
    elsif page.match(/<div class="player-wrapper"/)
      access = "Full access"
    else
      access = "Check access manually"
    end

  elsif package == "lion"
    sleeptime = 5
    if page.match(/javascript:fulltext.*textsFT/)
      access = "Full access"
    elsif page.match(/<div class="critrefft">/)
      access = "Full access (Crit/Ref)"
    elsif page.match(/forward=critref_ft/)
      access = "Full access via browse list (crit/ref)"
    elsif page.match(/<i class="icon-play-circle">/)
      access = "Full access (video content)"
    elsif page.include?("An error has occurred which prevents us from displaying this document")
      access = "Error"
    else
      access = "Check access manually"
    end
    
  elsif package == "nccorv"
    sleeptime = 1
    if page.match(/<div id="relatedVolumes">/)
      access = "related volumes section present"
    else
      access = "no related volumes section"
    end

  elsif package == "sabov"
    sleeptime = 1
    if page.match(/<a name="otherVols">/)
      access = "other volumes section present"
    else
      access = "no other volumes section"
    end
      
  elsif package == "scid"
    sleeptime = 1
    if page.match(/<td class=nonSerialEntitlementIcon><span class="sprite_nsubIcon_sci_dir"/)
      access = "Restricted access"
    elsif page.match(/title="You are entitled to access the full text of this document"/)
      access = "Full access"
    else
      access = "check"
    end    

  elsif package == "skno"
    sleeptime = 1
    if page.include?("Page Not Found")
      access = "No access - page not found"
    elsif page.include?("Error 404")
      access = "No access - 404 error"
    elsif page.include?("Unfortunately, there is a problem with this page")
      access = "No access - Oops problem with page"
    elsif page.include?("Users without subscription are not able to see the full content")
      access = "Restricted access"
    elsif page.match(/class="restrictedContent"/)
      access = "Restricted access"
    elsif page.match(/<p class="lockicon">/)
      access = "Restricted access"
    else
      access = "Full access"
    end

  elsif package == "spr"
    sleeptime = 1
    if page.match(/viewType="Denial"/) != nil
      access = "Restricted access"
      elsif page.match(/viewType="Full text download"/) != nil
        access = "Full access"
      elsif page.match(/viewType="Book pdf download"/) != nil
        access = "Full access"
      elsif page.match(/viewType="EPub download"/) != nil
        access = "Full access"
      elsif page.match(/viewType="Chapter pdf download"/) != nil
        access = "Full access (probably). Some chapters can be downloaded, but it appears the entire book cannot. May want to check manually."
      elsif page.match(/DOI Not Found/) != nil
        access = "DOI error"
      elsif page.match(/<h1>Page not found<\/h1>/) != nil
        access = "Page not found (404) error"
      elsif page.include?("Bookshop, Wageningen")
        access = "wageningenacademic.com"
    else
      access = "Check access manually"
    end
    
  elsif package == "srmo"
    sleeptime = 1
    if page.include?("Page Not Found")
      access = "No access - page not found"
      elsif page.include?("Add to Methods List")
        access = "Probable full access"
    else
      access = "Check access manually"
    end

  elsif package == "ss"
    sleeptime = 1
    if page.include? "SS_NoJournalFoundMsg"
      access = "No access indicated"
    elsif page.include? "SS_Holding"
      access = "Access indicated"
    else
      access = "Check access manually"
    end

  elsif package == "upso"
    sleeptime = 1
    if page.include?("<div class=\"contentRestrictedMessage\">")
      access = "Restricted access"
    elsif page.include?("<div class=\"contentItem\">")
      access = "Full access"
    elsif page.include? "DOI Not Found"
      access = "DOI Error"
    else
      access = "Check access manually"
    end

  elsif package == "waf"
    sleeptime = 1
    if page.include?("title=\"View the entire text of the document.  NOTE: Text might be very lengthy.\">Entire Document</a>")
      access = "Full access"
    else
      access = "Check access manually"
    end    

  elsif package == 'wol'
    sleeptime = 1
    if page.match(/<span class="licensedContent"/)
      access = "Full access"
      if page.include?("agu_logo.jpg")
        access += " - AGU"
      end
    elsif page.include?("DOI Not Found")
      access = "DOI error"
    elsif page.include?("page you've requested does not exist at this address")
      access = "Page not found error"
    else
      access = "Check access manually"
    end
  end

  CSV.open(output, "a") do |c|
    c << [rest_of_data, url, access].flatten
  end

  counter += 1
  puts "#{counter} of #{total}, access = #{access}"
  
  sleep sleeptime
end
