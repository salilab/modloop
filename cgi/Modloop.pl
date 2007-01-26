#!/usr/bin/perl -w

###############################################################
#                                                             #
# on-line loop modeling script, including parallel processing #
# with codine system                                          #
# copyright Andras Fiser, March 22, 2002,                     #
# andras@viol.compbio.ucsf.edu                                 #
# Rockefeller University, New York, NY 10021                  #
#                                                             #
###############################################################

use strict;
use Cwd;
use CGI qw/:standard /;
use CGI::Carp;
# To catch all fatal errors in the browser:
#use CGI::Carp qw(fatalsToBrowser);

# Substituted in at install time by Makefile:
my $tmp="@QUEUEDIR@";

################################
###some defaults
my $number_of_users=10;         #simultaneous users

################################
### get parameters from html

my $user_pdb_name = param('user_pdb2')||"";     # uploaded file name
my $iteration     = param('iteration')||300;    # number of models
my $user_name     = param('user_name')||"";     # root name
my $email         = param('email');             # users e-mail
my $modkey        = param('modkey')||"";        # passwd 
my $szoveg        = param('text')||"";          # selected loops

################################
###check and fix iteration param
if ($iteration < 1 || $iteration > 400) {
  $iteration = 400;
}
  $iteration = 4;


################################
###check and fix loop name 
$user_name =~ s/\s+//g;

check_modeller_key($modkey);

check_loop_selection($szoveg);

check_pdb_name($user_pdb_name);

###############################
#### extract loops
$szoveg =~ tr/a-z/A-Z/;    # capitalize
$szoveg =~ s/\s+//g;       # remove spaces
$szoveg =~ s/::/: :/g;     # replace null chain IDs with a single space

my @loop_data=split (/:/,$szoveg);

my $total_res=0;
my (@start_res, @start_id, @end_res, @end_id);
my $loops = 0;
while ($loops*4+3 <= $#loop_data and $loop_data[$loops*4] ne "") {
    $start_res[$loops]=$loop_data[$loops*4];
    $start_id[$loops]=$loop_data[$loops*4+1];
    $end_res[$loops]=$loop_data[$loops*4+2];
    $end_id[$loops]=$loop_data[$loops*4+3];
    $total_res=$total_res+($end_res[$loops]-$start_res[$loops]); #all the selected residues

    ################################
    # too long loops rejected
    if ((($end_res[$loops]-$start_res[$loops]) > 20)
        || ($start_id[$loops] ne $end_id[$loops])
        || (($end_res[$loops]-$start_res[$loops])<0)
        || ($start_res[$loops] eq "")
        || ($end_res[$loops] eq ""))
      {
       print header(), start_html("MODLOOP ERROR"),
       h2({-align=>'CENTER'},font({-color=>"#AA0000"},"ERROR!")),
       hr,
       h4({-align=>'CENTER'},font({-color=>"#AA0000"},"The loop selected is too long (>20 residues) or shorter than 1 residue or not selected properly (syntax problem?)")),
       h4({-align=>'CENTER'},font({-color=>"#AA0000"},"starting position $start_res[$loops]:$start_id[$loops], ending position: $end_res[$loops]:$end_id[$loops]")),
       h4({-align=>'CENTER'},font({-color=>"#AA0000"},"Please correct! Try again!")),
       end_html(); exit;       
     }
    $loops++;
  }


################################
# too many or no residues rejected
if ($total_res > 20) {
  quit_with_error("Too many loop residues have been selected ".
                  " (selected:$total_res > limit:20)!");
}
if ($total_res <= 0) {
  quit_with_error("No loop residues selected!");
}

#################################
### if email empty

check_email($email);

##################################
### if there are too many users

check_users($tmp, $number_of_users);

###################################
### read coordinates from file, replace if needed the pdb_user

$szoveg="";
my $user_pdb = "";

if ($user_pdb_name && ($user_pdb_name ne "")) 
   {
     while (<$user_pdb_name>)  {
       $szoveg .= $_;
     }
    $user_pdb=$szoveg;
     }

##################################
### generate a unique memo file for each submission

srand;
my $jobid = time()."_AF_".int(rand(1)*100000);

$user_name =~ s/[\/ ;\[\]\<\>&\t]/_/g;

open(JOBFILE, "> $tmp/modloop_$jobid") or die "Cannot create job file: $!";
print JOBFILE "$email $user_name $jobid $iteration\n";
close(JOBFILE);

my $loopout = "";
for (my $j=0;$j<$loops;$j++) {
  $loopout .= $start_res[$j].":".$start_id[$j]."-".$end_res[$j].":".$end_id[$j]." "; 
}

##################################
### send a mail each time someone is using it

open(OUTMAIL, "| /bin/mail modloop\@salilab.org") or die "Cannot open pipe: $!";
print OUTMAIL "This is the  LOOP SERVER speaking!!\n\n";
print OUTMAIL "who is attempting to use modloop? (e-mail):>$email<\n";
print OUTMAIL "protein code: >$user_name<\n";
print OUTMAIL "loops: >$loopout<\n";
print OUTMAIL "job id: >$jobid<\n";
print OUTMAIL "\n\n...adios...\n";
close (OUTMAIL);

###################################
### write pdb output

open(OUT,">$tmp/pdb-$jobid.pdb");
print OUT $user_pdb;
close(OUT);

#################################
### generate top file 

  my $oldconfig="looptmp.top";
  my $newconf = "$tmp/loop-$jobid.top";
  open(NEWCONF, ">$newconf") or die "Cannot open $newconf: $!";
  open(OLDCONF, $oldconfig) or die "Cannot open $oldconfig: $!";
  while(my $line =  <OLDCONF> ) {
    $line =~ s/USR_NAME/$user_name/g;
    $line =~ s/USER_PDB/pdb-$jobid.pdb/g;

  for (my $j=0;$j<$loops;$j++)
    {
      if ($line =~ /\#$j\#/)
	{
        $line =~ s/START_RES/$start_res[$j]/g;
        $line =~ s/START_ID/$start_id[$j]/g;
        $line =~ s/END_RES/$end_res[$j]/g;
        $line =~ s/END_ID/$end_id[$j]/g; 
        $line =~ s/\#$j\#//g; 
        } 
    } 
    print NEWCONF $line;
    }
  close(OLDCONF);
  close(NEWCONF);

#################################
# generate  pdb header
  my $oldtext="toptext.tex";
  open(NEWCONF, ">$tmp/toptext-$jobid.tex") or die "Cannot open: $!";
  open(OLDCONF, $oldtext) or die "Cannot open $oldtext: $!";
  while(my $line =  <OLDCONF> ) 
    {
    $line =~ s/USR_NAME/$user_name/g;
    $line =~ s/USER_PDB/pdb-$jobid.pdb/g;
    
     $line =~ s/LOOP_LIST/$loopout/g;
     $line =~ s/iteration/$iteration/g;
     print NEWCONF $line;
    }
  close(OLDCONF);
  close(NEWCONF);

###############################################
## write subject details into a file and pop up an exit page

### good bye

print header(), start_html("MODLOOP SUBMITTED"),
         h2({-align=>'CENTER'},font({-color=>"#AA0000"},"Dear User")),
       hr,
         h4({-align=>'CENTER'},font({-color=>"#AA0000"},"Your job has been submitted to the server! Your process ID is $jobid")),
         h4({-align=>'LEFT'},font({-color=>"#AA0000"},"The following loop segment(s) will be optimized: $loopout in protein: >$user_name< ")),
         h4({-align=>'LEFT'},font({-color=>"#AA0000"},"using the method of Fiser et al. (Prot. Sci. (2000) 9,1753-1773")),
         h4({-align=>'LEFT'},font({-color=>"#AA0000"},"You will receive the protein coordinate file with the optimized loop region by e-mail, to the adress: $email")),
        h4({-align=>'LEFT'},font({-color=>"#AA0000"},"The estimated execution time is ~90 min, depending on the load..")),
        h4({-align=>'LEFT'},font({-color=>"#AA0000"},"If you experience a problem or you do not receive the results for more than  12 hours, please contact modloop\@salilab.org")),
h4({-align=>'CENTER'},font({-color=>"#AA0000"},"Thank you for using our server and good luck in your research!")),
    h4({-align=>'RIGHT'},font({-color=>"#AA0000"},"Andras Fiser")),
	hr,
         end_html(); exit;  




sub end_modloop {

	my @message=@_;
	my $errortable;
	print header,start_html("MODLOOP ERROR");

	$errortable=table({-border=>0, -width=>"70%", -bgcolor=>"white", -align=>"center"},
                Tr({-cellspacing=>0, -cellpadding=>0},
                        td({-class=>"redtxt", -align=>"left"},b("MODLOOP Error"))),
                Tr({-cellspacing=>0, -cellpadding=>0},
                        td({-class=>"redtxt", -align=>"left"},b("An error occured during your request:"))),
                Tr({-cellspacing=>0, -cellpadding=>0},
                        td({-class=>"smallindented", -align=>"left"},br,b(join(br,@message)),br,br)),
                Tr({-cellspacing=>0, -cellpadding=>0},
                        td({-class=>"redtxt",-align=>"left"},
			b("Please click on your browser's \"BACK\" button, and correct the problem.",br))));

	print $errortable;
	print end_html;
	exit;

}

# Quit with an error message
sub quit_with_error {
  my ($err) = @_;
  print header(), start_html("MODLOOP ERROR"),
        h2({-align=>'CENTER'},font({-color=>"#AA0000"},"ERROR!")), hr,
        h4({-align=>'CENTER'},font({-color=>"#AA0000"}, $err)),
        h4({-align=>'CENTER'},font({-color=>"#AA0000"},"Try again!")),
        end_html();
  exit;
}

# Check Modeller license key
sub check_modeller_key {
  my ($key) = @_;
  if ($key ne "***REMOVED***") {
    quit_with_error("You have entered an invalid MODELLER KEY!");
  }
}

# Check for loop selection
sub check_loop_selection {
  my ($loop) = @_;
  if ($loop eq "") {
    quit_with_error("No loop segments were specified!");
  }
}

# Check if a PDB name was specified
sub check_pdb_name {
  my ($pdb_name) = @_;
  if ($pdb_name eq "") {
    quit_with_error("No coordinate file has been submitted!");
  }
}

# Check for valid email address
sub check_email {
  my ($email) = @_;

  if (!$email || $email eq "") {
    end_modloop("Please provide an e-mail address, because results will " .
                "be sent by email!");
  }

  unless ($email =~ /^[\w.+-]+\@[\w.+-]+$/) {
    end_modloop("Your email address contains special characters. " .
                "Please enter a regular email address! ");
  }
}

# Check for user limit
sub check_users {
  my ($tmp, $number_of_users) = @_;

  my @oldruns = glob("$tmp/modloop_*");

  if (scalar(@oldruns) >= $number_of_users ) {
    end_modloop("The server queue has reached its maximum number of " .
                "$number_of_users  simultaneous users. Please try later on!",
                "Sorry!");
  }
}
