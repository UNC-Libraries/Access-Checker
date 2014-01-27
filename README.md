# Ebook access checker
A simple JRuby script to check for full-text access to e-resource titles. Plain old URL/link checking won't alert you if one of your ebook links points to a valid HTML page reading "NO ACCESS." This script will.

This script can currently check for access problems for the following platforms/vendors (so far): 
- Alexander Street Press 
- Apabi
- Ebrary
- EBSCOhost eBook Collection
- Duke University Press ebooks (on HighWire platform)
- ScienceDirect ebooks (Elsevier)
- SAGE Knowledge
- SAGE Research Methods Online 
- SerialsSolutions
- SpringerLink 
- University Press (inc. Oxford) Scholarship Online
- Wiley Online Library

The script can check for some other special issues on certain platforms:
- Nineteenth Century Collections Online - check for presence of "Related Volumes" section on an ebook landing page
- Endeca - check whether a record has been deleted or not

# Requirements
- You must have [JRuby] (http://jruby.org/) installed. This script has been tested on JRuby 1.7.3. Installing JRuby is super-easy; point-and-click .exe installers are available for Windows on the [JRuby homepage] (http://jruby.org/).

- Once JRuby is installed, you will need to install the JRuby Gems [Celerity] (http://celerity.rubyforge.org/) and [Highline] (http://highline.rubyforge.org/).

To install these Gems, open the command line shell and type the following commands: 
- jruby -S gem install celerity
- jruby -S gem install highline

# Set up before first-time use
## Prepare your script directory
Choose or create a directory/folder on your computer in which to place the access_checker.rb script. This directory can be called whatever you want, but here I'll call it the "rubyscripts" directory. 

**For the rest of the instructions, we'll assume the path of the rubyscripts folder is:** C:\Users\you\rubyscripts

## Download the script and put it in the rubyscripts directory
* Go to https://github.com/UNC-Libraries/Ebook-Access-Checker
* Download ZIP file containing the files (bottom of right column)
* Unzip the ZIP file on your computer
* Put a copy of the access_checker.rb file from the unzipped directory into your rubyscripts directory: C:\Users\you\rubyscripts\access_checker.rb

# How to use
## Prepare your input file
The script expects a .csv file containing URLs for which to check access. The column containing the URL **MUST** be the last/right-most column. You may include any number of columns (RecordID#, Title, Publication Date, etc.) to the left of the URL column. 
Make sure there is only **one** URL per row.

All URLs/titles in one input file must be in/on the same package/platform. 

If your URLs are prefixed with proxy strings, and you are running the script from a location where proxying isn't needed for access, deleting the proxy strings from the URLs first will speed up the script. Use Excel Replace All to do this. 

**Put the input file in the rubyscripts directory. Example location: C:\Users\you\rubyscripts\inputfile.csv**

## Run the script
* Open your command line shell (this will be Windows PowerShell for most Windows users)
* In shell, move to the rubyscripts directory. Given the example locations listed above, you will type the following and then hit Enter: 
```cd C:\Users\you\rubyscripts```

In your command line shell, type (substitute in the name of your actual input file and the desired name for your actual output file): 
```jruby -S access_checker.rb inputfile.csv outputfile.csv```

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
