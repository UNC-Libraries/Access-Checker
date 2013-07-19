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

  puts "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  puts "What platform/package are you access checking?"
  puts "Type one of the following:"
  puts "  asp  : Alexander Street Press links"
  puts "  ebr  : Ebrary links"
  puts "  ebs  : EBSCOhost ebook collection"
  puts "  ss   : SerialsSolutions links"
  puts "  srmo : Sage Research Methods Online links"
  puts "  spr  : SpringerLink links"
  puts "  upso : University Press (inc. Oxford) Scholarship Online links"
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

b = Celerity::Browser.new

csv_data.each do |r|
  row_array = r.to_csv.parse_csv
  url = row_array.pop
  rest_of_data = row_array

  b.goto(url)
  page = b.html

  if package == "asp"
    if page.include?("Page Not Found")
      access = "not found"
    elsif page.include?("error")
      access = "error"
    elsif page.include?("Browse")
        access = "access ok"
    else
      access = "check"
    end

  elsif package == "ebr"
    if page.include?("Document Unavailable\.")
      access = "no access"
      elsif page.include?("Date Published")
        access = "access"
    else
      access = "check"
    end

  elsif package == "ebs"
    if page.match(/class="std-warning-text">No results/)
      access = "no access"
    elsif page.include?("eBook Full Text")
        access = "access"
    else
      access = "check"
    end
    
  elsif package == "srmo"
    if page.include?("Page Not Found")
      access = "not found"
      elsif page.include?("Add to Methods List")
        access = "found"
    else
      access = "check"
    end

  elsif package == "ss"
    if page.include? "SS_NoJournalFoundMsg"
      access = "no access"
    elsif page.include? "SS_Holding"
      access = "access"
    else
      access = "check manually"
    end

  elsif package == "spr"
    if page.match(/viewType="Denial"/) != nil
      access = "restricted"
      elsif page.match(/viewType="Full text download"/) != nil
        access = "full"
      elsif page.match(/DOI Not Found/) != nil
        access = "DOI error"
      elsif page.include?("Bookshop, Wageningen")
        access = "wageningenacademic.com"
    else
      access = "check"
    end

  elsif package == "upso"
    if page.include?("<div class=\"contentItem\">")
      access = "access ok"
    else
      access = "check"
    end
  end

  CSV.open(output, "a") do |c|
    c << [rest_of_data, url, access].flatten
  end

  counter += 1
  puts "#{counter} of #{total}, access = #{access}"
  
  sleeptime = 1
  sleep sleeptime
end
