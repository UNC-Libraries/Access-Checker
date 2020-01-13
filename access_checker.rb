#!/usr/bin/env ruby

# Tested in JRuby 1.7.3
# Written by Kristina Spurgin

# Usage:
# jruby -S access_checker.rb [arguments] [inputfilelocation] [outputfilelocation]

# Input file:
# .csv file with:
# - one header row
# - any number of columns to left of final column
# - one URL in final column
# - accepts tab-delimited files through use of arguments

# Output file:
# .csv file with all the data from the input file, plus a new column containing
#   access checker result

# Optional arguments:
#   e.g. jruby -S access_checker.rb -t -b inputfile.txt outputfile.csv
#
# -t (or --tab_delimited):
#   The input file is read as a tab-delimited file rather than a csv. If
#   newlines or tabs are contained in the data fields themselves, this could
#   cause errors. Should work with utf-8 or unicode input files; may not work
#   with some other encodings
#
# -b (or --write_utf8_bom)
#   When writing to a new (non-existing) output file, manually add a UTF-8 BOM
#   (primary use case: allowing Excel to directly open the csv with proper
#   encoding). Has no effect if appending to an existing output file.
#

require 'celerity'
require 'csv'
require 'highline/import'
require 'open-uri'

puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
puts "What platform/package are you access checking?"
puts "Type one of the following:"
puts "  asp    : Alexander Street Press links"
puts "  alman  : Al Manhal"
puts "  apb    : Apabi ebooks"
puts "  brep   : Brepols (brepolsonline.net)"
puts "  cup    : Cambridge University Press"
puts "  ciao   : Columbia International Affairs Online"
puts "  cod    : Criterion on Demand"
puts "  dgry   : De Gruyter ebook platform"
puts "  dgtla  : Digitalia ebooks"
puts "  dram   : DRAM"
puts "  dupsc  : Duke University Press (via Silverchair)"
puts "  eai    : Early American Imprints (Readex)"
puts "  ebr    : Ebrary links"
puts "  ebs    : EBSCOhost ebook collection"
puts "  end    : Endeca - Check for undeleted records"
puts "  fmgfod : FMG Films on Demand"
puts "  ieee   : IEEE"
puts "  igi    : IGI Global"
puts "  kan    : Kanopy Streaming Video"
puts "  knv    : Knovel"
puts "  lion   : LIterature ONline (Proquest)"
puts "  nccorv : NCCO - Check for related volumes"
puts "  obo    : Oxford Bibliographies Online"
puts "  oho    : Oxford Handbooks Online"
puts "  psynet : Psychotherapy.net videos"
puts "  sabov  : Sabin Americana - Check for Other Volumes"
puts "  skno   : SAGE Knowledge links"
puts "  srmo   : SAGE Research Methods Online links"
puts "  scid   : ScienceDirect ebooks (Elsevier)"
puts "  ss     : SerialsSolutions links"
puts "  spr    : SpringerLink links"
puts "  upso   : University Press (inc. Oxford) Scholarship Online links"
puts "  waf    : Wright American Fiction"
puts "  wol    : Wiley Online Library"
puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

package = ask("Package?  ")
if package == "spr"
  get_ebk_pkg = ask("Do you also want to retrieve subject module/ebook package for each title? y/n  ")
end

puts "\nPreparing to check access...\n"

if ARGV.include?('-t') || ARGV.include?('--tab_delimited')
  input_is_tab_delimited = true
  ARGV.delete('-t')
  ARGV.delete('--tab_delimited')
else
  input_is_tab_delimited = false
end

if ARGV.include?('-b') || ARGV.include?('--write_utf8_bom')
  write_utf8_bom = true
  ARGV.delete('-b')
  ARGV.delete('--write_utf8_bom')
else
  write_utf8_bom = false
end

input = ARGV[0]
output = ARGV[1]


if input_is_tab_delimited
  begin
    # attempt to read the file using default quote_char
    csv_data = CSV.read(input,
                        :headers => true,
                        :col_sep => "\t")
  rescue CSV::MalformedCSVError
    begin
      # CSV wants unescaped quote_char only around entire fields. So, try
      # giving it an unprintable char.
      csv_data = CSV.read(input,
                          :headers => true,
                          :col_sep => "\t",
                          :quote_char => "\x00")
    rescue CSV::MalformedCSVError
      # try to read the file as Unicode; will convert to utf-8
      csv_data = CSV.read(input,
                          :headers => true,
                          :col_sep => "\t",
                          :quote_char => "\x00",
                          :encoding => "BOM|UTF-16LE:UTF-8")
    end
  end
else
  csv_data = CSV.read(input, :headers => true)
end
headers = csv_data.headers


if write_utf8_bom and not File.exist?(output)
  File.open(output, 'w') do |file|
    file.write "\uFEFF"
  end
end


counter = 0
total = csv_data.count


headers << "access"

if get_ebk_pkg == "y"
  headers << "ebook package"
end

CSV.open(output, "a") do |c|
  c << headers
end


if package == "kan"
  agent_spoof = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36'
  b = Celerity::Browser.new(:browser => :firefox, :user_agent => agent_spoof)
elsif package == "asp" || package == "lion"
  # On 12/6/17, ASP was redirecting from http to https when using celerity
  # and for unknown reason causing SSL/certificate errors. Disabling
  # secure_ssl, which I don't know that we really care about, for ASP.
  # ASP should finish making changes to their site in Jan 2018, so some
  # time after that see if this exception can be removed. (At the time
  # this was happening visiting an http URL in firefox was not redirecting
  # and visiting an https URL was not resulting in certificate problems.)
  b = Celerity::Browser.new(:browser => :firefox, :secure_ssl => false)
else
  b = Celerity::Browser.new(:browser => :firefox)
  #b = Celerity::Browser.new(:browser => :firefox, :log_level => :all)
end


if package == "oho" || package == "obo"
  # unite Oxford logic under upso
  package = "upso"
end


b.css = false
b.javascript_enabled = false



csv_data.each do |r|
  row_array = r.to_csv.parse_csv
  url = row_array.pop
  rest_of_data = row_array

  if package == "ss"
    # this creates a new url based on the library code (e.g. VB3LK7EB4T)
    # and criteria (e.g. JC_005405622) to get around the angular.js
    # it may not work on all serialsolutions URLS. Sample, working urls:
    # url = 'http://VB3LK7EB4T.search.serialssolutions.com/?V=1.0&L=VB3LK7EB4T&S=JCs&C=JC_005405622&T=marc'
    # url = 'http://VB3LK7EB4T.search.serialssolutions.com/?V=1.0&L=VB3LK7EB4T&S=JCs&C=TC_026248270&T=marc'
    match = url.match('://([^.]*).*&C=([^&]*)')
    if match and match.size == 3
      lib, criteria = match[1..2]
      url2 = "http://%s.search.serialssolutions.com/ejp/api/1/libraries/%s/search/types/title_code/%s" % [lib, lib, criteria]
      page = open(url2).read
    else
      page = "This script is not configured to accept this URL structure."
    end
  else
    #
    # For every package but SerSol, do this:
    #
    b.goto(url)
    page = b.html
  end

  if package == "apb"
    sleeptime = 1
    if page.match(/type="onlineread"/)
      access = "Access probably ok"
    else
      access = "Check access manually"
    end

  elsif package == "alman"
    sleeptime = 1
    if page.include?("\"AvailabilityMode\":4")
      access = "Preview mode"
    elsif page.include?("\"AvailabilityMode\":2")
      access = "Full access"
    elsif page.include?("id=\"searchBox")
      access = "No access. Item not found"
    else
      access = "Check access manually"
    end

  elsif package == "asp"
    sleeptime = 1
    if page.include?("Page Not Found")
      access = "Page not found"
    elsif page.include?("This is a sample. For full access:")
      access = "Sample"
    elsif page.include?("Trial login | Alexander Street")
      access = "Trial"
    elsif page.include?("<span>Your institution does not have access to this particular content.</span>")
      access = "Institution does not have access"
    elsif page.match(/<source src="http:\/\/alexstreet\.vo\.llnwd\.net/)
      access = "Streaming access"
    elsif page.match(/link rel="preconnect"/)
      access = "Streaming access"
    elsif page.include?("Browse")
      access = "Full access"
    elsif page.match(/(\s|"|'|\/|\.)[Ee]rror/)
      access = "Error returned"
    else
      access = "Check access manually"
    end

  elsif package == "brep"
    sleeptime = 1
    if page.match(/class="previewContent/)
      access = "No access"
    elsif page.match(/class="error">Book not found./)
      access = "Page not found"
    elsif page.match(/title="Full Access"/)
      access = "Full Access"
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

  elsif package == "dgry"
    sleeptime = 1
    if page.include?("Too Many Requests")
      puts "Too many requests, sleeping 60 seconds then will retry."
      sleep 61
    end
    while page.include?("Too Many Requests")
      puts "Too many requests, retrying after 1 second."
      sleep 1
      b.goto(url)
      page = b.html
    end
    if page.match(/"pf:authorized" ?: ?"authorized"/)
      access = "Full access"
    elsif page.include?("class=\"openAccessImg\"")
      access = "Open access"
    elsif page.match(/"pf:authorized" ?: ?"not-authorized"/)
      access = "Restricted access"
    elsif page.include?("<div class=\"accessModule whiteModule\" id=\"access-from\">")
      access = "Full access"
    else
      access = "Check access manually"
    end

  elsif package == "dgtla"
    sleeptime = 1
    if page.match(/<span class="disponible"/)
      access = "Full access"
    elsif page.match(/span class="ndisp"/)
      access = "No access"
    else
      access = "Check access manually"
    end

  elsif package == "dram"
    sleeptime = 10
    if page.include?("This album has been disabled by its rights holders, and no longer appears in search results.")
      access = "No access"
    elsif page.include?("Play this album")
      access = "Full access"
    else
      access = "Check access manually"
    end

  elsif package == "dupsc"
    sleeptime = 1
    if page.include?("DOI Not Found")
      access = "DOI error"
    elsif page.include?("icon-availability_unlocked")
      access = "Access to at least some content"
    # I don't think there's any books we don't have access to, so can't
    # right now see e.g. if there's an icon-availability_locked" and it's
    # unknown whether books we don't have access to will have "icon-availability_unlocked"
    # for, say, prefatory material. Also unclear whether post-migration
    # grace access is still in effect on 2018-01-10.
    elsif page.include?("Not Found | Duke University Press")
      access = "Bad DOI (leads to DUP 404 error)"
    else
      access = "Check access manually"
    end

  elsif package == "eai"
    sleeptime = 1
    if page.match(/TypeError: Cannot read property "UNQ" from undefined \(eai\.js#595\)/m)
      access = "No access: TypeError: Cannot read property UNQ from undefined (eai.js#595)"
    elsif page.match(/TypeError: Cannot read property "PRDI" from undefined \(eai\.js#718\)/m)
      access = "No access: TypeError: Cannot read property PRDI from undefined (eai.js#718)"
    elsif page.match(/f_mode=downloadPages">Download Pages/)
      access = "Full access"
    else
      access = "Check access manually"
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
    #reformulate url and follow to actual results
    if page.match(/window.location.replace.'([^']*)/)
      query = page.match(/window.location.replace.'([^']*)/)[1]
      baseurl = b.url.gsub(/plink.*/,'')
      url = baseurl + query
      b.goto(url)
      page = b.html
    end
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
    elsif page.include?("It looks like you were provided with the incorrect link.")
      access = "No access"
    elsif page.match(/player_id="divMedia"/)
      access = "Full access"
    elsif page.match(/class="now-playing-div/)
      access = "Full access"
    else
      access = "Check access manually"
    end

  elsif package == "ieee"
    sleeptime = 10
    if page.include?("Included in Your Digital Subscription")
      access = "Full access"
    elsif page.include?("This publication is an Open Access only journal. Open Access provides unrestricted online access to peer-reviewed journal articles.")
      access = "Full access"
    elsif page.include?("Freely Available from IEEE")
      access = "Full access"
    elsif page.include?("Page Not Found")
      access = "Check access manually"
    elsif page.include?("Full text access may be available. Click article title to sign in or learn about subscription options.")
      access = "Check access manually"
    else
      access = "Check access manually"
    end

  elsif package == "igi"
    sleeptime = 10
    if page.match(/title="Owned"/)
      access = "owned"
    elsif page.include?("Institution Prices")
      access = "not owned"
    else
      access = "check manually"
    end

  elsif package == "kan"
    sleeptime = 10
    if page.include?("Your institution has not licensed")
      access = "No access"
    elsif page.include?("This film is not available at your institution")
      access = "No access"
    elsif page.include?("Sorry, this video is not available in your territory")
      access = "No access"
    elsif page.match(/<div class="player-wrapper"/)
      access = "Full access"
    else
      access = "Check access manually"
    end

  elsif package == "knv"
    sleeptime = 10
    if page.include?("This Reference is not available in your current subscription.")
      access = "No access"
    elsif page.match(/<span class="warning-message">/)
      access = "No access"
    else
      access = "Full access"
    end

  elsif package == "lion"
    sleeptime = 5
    if page.match(/Open access/)
      access = "Open access"
    elsif page.match(/Full text available/)
      access = "Full access"
    elsif page.match(/javascript:fulltext.*textsFT/)
      access = "Full access"
    elsif page.match(/<div class="critrefft">/)
      access = "Full access (Crit/Ref)"
    elsif page.match(/forward=critref_ft/)
      access = "Full access via browse list (crit/ref)"
    elsif page.match(/<i class="icon-play-circle">/)
      access = "Full access (video content)"
    elsif page.include?("An error has occurred which prevents us from displaying this document")
      access = "Error"
    elsif page.match(/publication was not found/)
      access = "Not found"
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

  # elsif package == "obo"
  # elsif package == "oho"
  #
  # Oxford logic is united under 'upso'
  # obo and oho remain as entries on the menu, but if selected are
  # reassigned to 'upso' before this conditional

elsif package == "psynet"
  sleeptime = 1
  if page.match(/The stream you requested does not exist./)
    access = "Page not found"
  elsif page.match(/id="stream_content">/)
    access = "Full access likely"
  else
    access = "Check access manually"
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
    if page.include?("(error 404)")
      access = "404 error"
    elsif page.match(/<span class="offscreen">You are not entitled to access the full text/)
      access = "Restricted access"
    elsif page.include?("Sorry, your subscription does not entitle you to access this page")
      access = "Restricted access - cannot display page"
    elsif page.match(/class="offscreen">Entitled to full text<.+{4,}/)
      access = "Full access"
    elsif page.match(/class="mrwLeftLinks"><a href=\/science\?_ob=RefWorkIndexURL&_idxType=AR/)
      new_url_suffix = /\/science\?_ob=RefWorkIndexURL&_idxType=AR[^ ]+/.match(page)
      new_url = "http://www.sciencedirect.com" + new_url_suffix.to_s
      b.goto(new_url)
      index_page = b.html
      if index_page.match(/<span class="offscreen">You are not entitled to access the full text/)
        access = "Restricted access"
      elsif index_page.match(/class="offscreen">Entitled to full text<.+{4,}/)
        access = "Full access to 4 or more reference work articles"
      end
    elsif page.match(/<a href="#ancsc\d+"/)
      new_url_suffix = /<a href="#ancsc\d+" data-url="([^"]+)"/.match(page)[1].gsub!(/&amp;/,'&')
      new_url = url + new_url_suffix
      b.goto(new_url)
      index_page = b.html
      if index_page.match(/<span class="offscreen">You are not entitled to access the full text/)
        access = "Restricted access"
      elsif index_page.match(/class="offscreen">Entitled to full text<.+{4,}/)
        access = "Full access to 4 or more reference work articles"
      end
    else
      access = "check manually"
    end

  elsif package == "skno"
    sleeptime = 1
    if page.include?("Page Not Found")
      access = "No access - page not found"
    elsif page.include?("'access': 'false'")
      access = "Restricted access"
    elsif page.include?("'access': 'true'")
      access = "Full access"
    elsif page.include?("Error 404")
      access = "No access - 404 error"
    elsif page.include?("Unfortunately, there is a problem with this page")
      access = "No access - Oops problem with page"
    elsif page.include?("page you requested couldn't be found")
      access = "No access - page not found"
    elsif page.include?("Users without subscription are not able to see the full content")
      access = "Restricted access"
    elsif page.match(/class="restrictedContent"/)
      access = "Restricted access"
    elsif page.match(/<p class="lockicon">/)
      access = "Restricted access"
    elsif page.match(/<div class="lock"><\/div>/)
      access = "Restricted access"
    else
      access = "Check access manually"
    end

  elsif package == "spr"
    sleeptime = 1
    if page.match(/'HasAccess':.Y./i) != nil
      access = "Full access"
    elsif page.match(/'Access Type':.noaccess./) != nil
      access = "Restricted access"
    elsif page.match(/viewType="Denial"/) != nil
      access = "Restricted access"
    elsif page.match(/viewType="Full text download"/) != nil
      access = "Full access"
    elsif page.match(/viewType="Book pdf download"/) != nil
      access = "Full access"
    elsif page.match(/viewType="EPub download"/) != nil
      access = "Full access"
    elsif page.match(/viewType="Chapter pdf download"/) != nil
      access = "Full access (probably). Some chapters can be downloaded, but it appears the entire book cannot. May want to check manually."
    elsif page.match(/viewType="Reference work entry pdf download"/) != nil
      access = "Reference work with access to PDF downloads. May want to check manually, as we have discovered some reference work entry PDFs contain no full text content."
    elsif page.match(/DOI Not Found/) != nil
      access = "DOI error"
      no_spr_content = true
    elsif page.match(/<h1>Page not found<\/h1>/) != nil
      access = "Page not found (404) error"
      no_spr_content = true
    elsif page.include?("Bookshop, Wageningen")
      access = "wageningenacademic.com"
      no_spr_content = true
    else
      access = "Check access manually"
    end

    if get_ebk_pkg == "y"
      if no_spr_content
        ebk_pkg = "n/a"
      else
        match_chk = /href="\/search\?facet-content-type&#x3D;%22Book%22&amp;package&#x3D;\d+&amp;facet-start-year&#x3D;\d{4}&amp;facet-end-year&#x3D;\d{4}">([^<]+)<\/a>/.match(page)
        if match_chk
          ebk_pkg = match_chk[1]
        end
      end
    end

  elsif package == "srmo"
    sleeptime = 1
    if page.include?("Page Not Found")
      access = "No access - page not found"
    elsif page.include?("'access': 'false'")
      access = "Restricted access"
    elsif page.include?("'access': 'true'")
      access = "Full access"
    else
      access = "Check access manually"
    end

  elsif package == "ss"
    sleeptime = 1
    if page.match('{"titles":\[\],"pages":\[\]')
      access = "No access indicated"
    elsif page.match('{"titles":\[{"title":')
      access = "Access indicated"
    elsif page.match("This script is not configured to accept this URL structure.")
      access = "Unknown URL structure."
    else
      access = "Check access manually"
    end

  elsif package == "upso"
    sleeptime = 1
    if page.include?("DOI Not Found")
      access = "DOI error"
    elsif page.match(/pf:authorized":"authorized/)
      access = "Full access"
    elsif page.match(/pf:authorized":"not-authorized/)
      if page.match(/Page Not Found/)
        access = "Page not found"
      else
        access = "Restricted"
      end
    else
      access = "Check manually"
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
    if page.include?("You have full text access to this content</span><h1 id=\"productTitle\">")
      access = "Full access"
      if page.include?("agu_logo.jpg")
        access += " - AGU"
      end
    elsif page.include?("You have full text access to this content</span>")
      access = "Full text access to partial contents"
    elsif page.match(/You have free access to this content<\/span><input type="checkbox" name="doi" id="option[0-9]+" value="\d{2}\.\d{4}\/[0-9Xx]+\.(?!app|fmatter|index)/)
      access = "Free access to some content. Best to check manually. If normal front/backmatter is being reported this way, please report the issue at: https://github.com/UNC-Libraries/Ebook-Access-Checker/issues"
    elsif page.match(/You have free access to this content<\/span><input type="checkbox" name="doi" id="option[0-9]+" value="\d{2}\.\d{4}\/[0-9Xx]+\.(app|fmatter|index)/)
      access = "Free access to normal front/backmatter only. Currently this includes book sections whose DOIs include: .fmatter, .app, and .index."
    elsif page.include?("DOI Not Found")
      access = "DOI error"
    elsif page.include?("page you've requested does not exist at this address")
      access = "Page not found error"
    else
      access = "Check manually"
    end
  end

  if get_ebk_pkg == "y"
    to_write = [rest_of_data, url, access, ebk_pkg].flatten
  else
    to_write = [rest_of_data, url, access].flatten
  end

  CSV.open(output, "a") do |c|
    c << to_write
  end

  counter += 1
  puts "#{counter} of #{total}, access = #{access}"

  sleep sleeptime
end
