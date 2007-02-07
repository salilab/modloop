#!/usr/bin/perl 
use strict;
use File::Copy;
use File::Path;

###############################################################
#                                                             #
# on-line loop modeling script, including parallel processing #
# with codine system                                          #
# copyright Andras Fiser, March 22, 2002,                     #
# afiser@aecom.yu.edu                                         #
# Rockefeller University, New York, NY 10021                  #
#                                                             #
###############################################################

my $queuedir="@QUEUEDIR@";
my $scriptsdir="@SCRIPTS@";
my $rundir="$queuedir/../running";

# SGE setup
$ENV{'SGE_ROOT'} = "/home/sge6";
my $sge_bindir = "/home/sge6/bin/sol-sparc64";

# Submit any new jobs
chdir($queuedir);
my @queue = glob("modloop*");
submit_jobs($queuedir, $rundir, @queue);

# Check for finished jobs
chdir($rundir);
my @running = glob("*AF*");
check_finished_jobs($rundir, @running);


# Generate .top and SGE script
sub generate_files {
  my ($iteration, $email, $jobid, $rundir) = @_;

  ### generate  top files
  my $topfile="";
  for (my $i = 1; $i <= $iteration; $i++) {
    #get a random number here
    my $random_seed = int(rand(1)*48000) - 49000;
    open(INFILE, "loop-$jobid.top")
        or die "Cannot open input: $!";
    open(OUTFILE, "> $i.top")
        or die "Cannot open output: $!";
    while(<INFILE>) {
      s/CODINE_RND/$random_seed/;
      s/item/$i/;
      print OUTFILE;
    }
    close(INFILE);
    close(OUTFILE);
    $topfile .= " $i.top";  # collect names for codine
  }

  # generate codine script
  my $oldcodine = "$scriptsdir/codinetmp.sh";
  my $newcodine = "codine-$jobid.sh";
  open(NEWCONF, "> $newcodine") or die "Cannot open: $!";
  open(OLDCONF, $oldcodine) or die "Cannot open $oldcodine: $!";
  while(<OLDCONF>) {
    s/iteration/$iteration/g;
    s/INFILES/$topfile/g;
    s/DIR/$rundir/g;
    print NEWCONF;
  }
  close(OLDCONF);
  close(NEWCONF);
  open (EMAIL, "> email") or die "Cannot open email: $!";
  print EMAIL "$email\n";
  close EMAIL;
}


# Find any queued jobs, and submit them to SGE
sub submit_jobs {
  my ($queuedir, $rundir, @queue) = @_;

  foreach (@queue) {
    open (TMPIN, $_);
    my $line = <TMPIN>;
    my @bejon = split ( / /,$line );
    my $email    = $bejon[0];
    my $name     = $bejon[1];
    my $jobid  = $bejon[2];   
    my $iteration= $bejon[3];   
    close TMPIN;

    # Take ownership (from nobody) and copy to running directory
    my $jobdir = "$rundir/$jobid";
    mkdir($jobdir, 0755) or die "Cannot make run directory $jobdir: $!";
    my @files = ("loop-$jobid.top", "pdb-$jobid.pdb", "toptext-$jobid.tex");
    for my $file (@files) {
      copy($file, $jobdir) or die "Copy of $file failed: $!";
    }
    chdir($jobdir) or die "Cannot change to $jobdir: $!";

    # Make TOP scripts and SGE submission script
    generate_files($iteration, $email, $jobid, $jobdir);

    # SGE run
    my $result = `${sge_bindir}/qsub codine-$jobid.sh`;

    if ($result =~ /Your job (\d+)\./) {
      my $sge_jobid = $1;
      open(OUT, "> sge-jobid") or die "Cannot write job id: $!";
      print OUT "$sge_jobid\n";
      close(OUT);
    } else {
      die "Cannot parse SGE output: $result";
    }

    # Remove job from queue
    chdir($queuedir);
    for my $file (@files, "modloop_$jobid") {
      unlink $file or die "Delete of $file failed: $!";
    }
  }
}


# Check for any finished jobs
sub check_finished_jobs {
  my ($tmp, @running) = @_;
  for my $job (@running) {
    chdir($tmp);
    my @statlst = stat("$job/sge-jobid");
    my $timenow = time();
    if (@statlst) {
      open(FILE, "$job/sge-jobid")
          or die "Cannot open job ID file $job/sge-jobid: $!";
      my $sge_jobid = <FILE>;
      chomp $sge_jobid;
      my $status = `${sge_bindir}/qstat -j $sge_jobid 2>&1`;
      if ($status =~ /^Following jobs do not exist/) {
        finish_job($job);
        unlink("$job/sge-jobid") or die "Cannot delete sge-jobid: $!";
      } elsif ($timenow - $statlst[9] > 60*60*24*7) {
        # Complain about running jobs after 7 days
        print "ModLoop job $job still running...\n";
      }
    } else {
      @statlst = stat($job);
      if (@statlst and $timenow - $statlst[9] > 60*60*24*15) {
        # Delete finished job directories more than 15 days old
        rmtree($job);
      }
    }
  }
}


# Get the PDB file with the lowest score
sub get_winner {
  my ($job) = @_;

  my @pdbs = glob("$job/*.B*");
  my $winpdb = "";
  my $winscore;
  for my $pdb (@pdbs) {
    open(PDB, $pdb) or die "Cannot open $pdb: $!";
    while(<PDB>) {
      if (/OBJECTIVE FUNCTION:(.*)$/) {
        my $score = $1 + 0.;
        if ($winpdb eq "" or $score < $winscore) {
          $winpdb = $pdb;
          $winscore = $score;
        }
      }
    }
    close PDB;
  }
  return $winpdb;
}

sub finish_job {
  my ($job) = @_;

  my $winner = get_winner($job);

  open(EMAIL, "$job/email") or die "Cannot open email: $!";
  my $email = <EMAIL>;
  chomp $email;
  close EMAIL;

  open(HEADER, "$job/toptext-$job.tex") or die "Cannot open header: $!";
  open(PDB, $winner) or die "Cannot open PDB $winner: $!";

  open(MAIL, "| /usr/bin/mail -t modloop\@salilab.org $email") or die "Cannot open pipe: $!";
  print MAIL "Subject: ModLoop results\n\n";
  while(<HEADER>) {
    print MAIL;
  }
  while(<PDB>) {
    print MAIL;
  }
  close MAIL or die "Cannot close pipe: $!";
}
