# Ebook access checker
A simple JRuby script to check for full-text access to e-resource titles. Plain old URL/link checking won't alert you if one of your ebook links points to a valid HTML page reading "NO ACCESS." This script will.

This script can currently check for access problems for the following platforms/vendors (so far): 
- Alexander Street Press 
- Ebrary
- EBSCOhost eBook Collection
- Sage Research Methods Online 
- SerialsSolutions
- SpringerLink 
- University Press (inc. Oxford) Scholarship Online

The script can check for some other special issues on certain platforms:
- Nineteenth Century Collections Online - check for presence of "Related Volumes" section on an ebook landing page

# Requirements
- You must have [JRuby] (http://jruby.org/) installed. This script has been tested on JRuby 1.7.3. Installing JRuby is super-easy; point-and-click .exe installers are available for Windows on the [JRuby homepage] (http://jruby.org/).

- Once JRuby is installed, you will need to install the JRuby Gems [Celerity] (http://celerity.rubyforge.org/) and [Highline] (http://highline.rubyforge.org/).

To install these Gems, open the command line shell and type the following commands: 
- jruby -S gem install celerity
- jruby -S gem install highline

# How to use
## Prepare your input file
The script expects a .csv file containing URLs for which to check access. The column containing the URL **MUST** be the last/right-most column. You may include any number of columns (RecordID#, Title, Publication Date, etc.) to the left of the URL column. 
Make sure there is only **one** URL per row.

All URLs/titles in one input file must be in/on the same package/platform. 

If your URLs are prefixed with proxy strings, and you are running the script from a location where proxying isn't needed for access, deleting the proxy strings from the URLs first will speed up the script. Use Excel Replace All to do this. 

## Run the script
In your command line shell, type: 
``jruby -S access_checker.rb [inputfilelocation] [outputfilelocation]``

When asked to input "Package?" enter the 3-4 letter code from the list above the input prompt.

## Output
Script will output a .csv file containing all data from the input file, with a new "access" column appended.

## If the script chokes/dies (or you need to otherwise stop it) while running...
You don't have to start over from the beginning. Remove all rows already checked (i.e. included in the output file) from the input file and restart the script, using the same output file location. 

The header row will be inserted into the output file again, so watch for that in the final results. 

# How it works
First, this script does not access, download, or touch *ANY* actual full-text content hosted by our providers. 

It simply visits the landing/description/info page for each ostensibly full-text resource---the page a user clicking the link in a catalog record would be brought to, at the same URL that our ILS link checker would ping. 

Depending on the platform/package, it checks for text indicating full or restricted access a) displayed on that page; OR b) buried in the page source code.
