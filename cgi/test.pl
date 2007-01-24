#!/usr/bin/perl -w

use Cwd;
use CGI qw/:standard /;
$tmp="/diva2/home/andras/html/tmploop/";

################################
###some defaults

 $iteration=400;             # number of loop models
################################
### generate a unique memo file for each submission

srand;
$bemenet = time()."_AF_".int(rand(1)*100000);

#################################
# generate  codine script
  $oldcodine="codinetmp.sh";
  $newcodine = "codine-$bemenet.sh";
  open(NEWCONF,">$tmp/$newcodine");
  open(OLDCONF,$oldcodine);
  while( $line =  <OLDCONF> ) 
    {
     $line =~ s/iteration/$iteration/g;
     print NEWCONF $line;
    }
  close(OLDCONF);
  close(NEWCONF);

#####################################################
### copy/generate  pdb/top/sh files in $tmp directory
#system("cp  $tmp/pdb-$bemenet.pdb $cwd/$runname/");
# already there

$topfile="";
for ($i=1;$i<=$iteration;$i++)
{
    $topfile=$topfile." $i.top";  # collect names for codine
}


###fix codine with job inputs
system("sed \"s;TOPFILES;$topfile;\"  $tmp/codine-$bemenet.sh > $tmp/ide; mv $tmp/ide  $tmp/codine-$bemenet.sh");
exit;

#@utasitas=sprintf ("sed \"s;TOPFILES;$topfile;\"  $tmp/codine-$bemenet.sh > $tmp/ide \n");
#system(@utasitas);
exit
system("sed \"s;DIR;$tmp;\"  $tmp/codine-$bemenet.sh > $tmp/ide; mv $tmp/ide  $tmp/codine-$bemenet.sh");
