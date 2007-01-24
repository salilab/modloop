#!/usr/bin/perl 
#####use strict;

###############################################################
#                                                             #
# on-line loop modeling script, including parallel processing #
# with codine system                                          #
# copyright Andras Fiser, March 22, 2002,                     #
# afiser@aecom.yu.edu                                         #
# Rockefeller University, New York, NY 10021                  #
#                                                             #
###############################################################

################################
###find new tasks, remove their memo and execute them
$tmp="/diva2/home/andras/html/tmploop";
chdir ("$tmp/");
system("ls -1 modloop* | grep mod > process_it ");

### codine local setup:
#local $ENV{"SGE_ROOT"} = `/diva1/codine`;
#local $ENV{"ARCH"} = `/diva1/codine/util/arch`;

@utasitas=sprintf (" source /home/sge6/default/common/settings.csh");
system(@utasitas);


open (TMPIN, "$tmp/process_it");
foreach (<TMPIN>)
   {
   open (TMPIN2, "$tmp/$_");
   $line=<TMPIN2>;
   @bejon=split ( / /,$line );
   my $email    = $bejon[0];
   my $name     = $bejon[1];
   my $bemenet  = $bejon[2];   
   my $iteration= $bejon[3];   
   close TMPIN2;

###remove submitted jobs from que
@utasitas=sprintf ("rm -f $tmp/modloop_$bemenet");
system(@utasitas);

#####################
### codine run
chdir ("$tmp/do_modloop_$bemenet"); 

$result = `/home/sge6/bin/sol-sparc64/qsub codine-$bemenet.sh`;
chomp $result;

$jobid = (split(" ",$result))[2];
$jobid =~ s/\..*//;#

### wait for job completion and collect results
while ( 1 )
  {
  sleep 30; # take  a nap
  $output = `/home/sge6/bin/sol-sparc64/qstat -j $jobid 2>&1`;
  if ( $output =~ /^Following jobs do not exist/ ) {last; }
  }

####################
###  put comments into pdb, mail results, remove memo
open(WIN,"$tmp/do_modloop_$bemenet/winner");
   $winner = <WIN>;
close WIN;
chomp $winner;

@utasitas=sprintf ("cat $tmp/do_modloop_$bemenet/toptext.tex  $tmp/do_modloop_$bemenet/$winner > $tmp/do_modloop_$bemenet/to_mail");
##@utasitas=sprintf ("cat $tmp/do_modloop_$bemenet/toptext.tex  $tmp/do_modloop_$bemenet/$winner > $tmp/do_modloop_$bemenet/../to_mail");
system(@utasitas);

@utasitas=sprintf ("/usr/bin/mailx -r\"Andras Fiser\<andras\@fiserlab.org\>\" -s\"Your ModLoop Results\"  $email  < $tmp/do_modloop_$bemenet/to_mail\n");
system(@utasitas);
                                                                                                                                                                                        
@utasitas=sprintf ("echo $email >  $tmp/do_modloop_$bemenet/address \n");
system(@utasitas);

@utasitas=sprintf ("/usr/bin/mailx -r\"Andras Fiser\<andras\@fiserlab.org\>\" -s\"Your ModLoop Results\" andras\@fiserlab.org  < $tmp/do_modloop_$bemenet/to_mail\n");
system(@utasitas);

#@utasitas=sprintf ("rm -rf $tmp/do_modloop_$bemenet/");
#system(@utasitas);
}
close TMPIN;
  exit (0);

