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
my $rundir="@RUNDIR@";
my $finisheddir="@FINISHEDDIR@";
my $modloop_email="modloop\@salilab.org";

# SGE setup for Sali cluster
$ENV{'SGE_ROOT'} = "/home/sge61";
$ENV{'SGE_CELL'} = "sali";
my $sge_bindir = "/home/sge61/bin/lx24-amd64";

# SGE setup for QB3 cluster
#$ENV{'SGE_ROOT'} = "/ccpr1/sge6";
#$ENV{'SGE_CELL'} = "qb3";
#$ENV{'SGE_QMASTER_PORT'} = "536";
#$ENV{'SGE_EXECD_PORT'} = "537";
#my $sge_bindir = "/ccpr1/sge6/bin/lx24-amd64";

# Submit any new jobs
chdir($queuedir);
my @queue = glob("modloop*");
submit_jobs($queuedir, $rundir, @queue);

# Check for finished jobs
check_finished_jobs($rundir, $finisheddir);

# Expire old finished jobs
expire_jobs($finisheddir);

# Generate SGE script
sub generate_script {
  my ($iteration, $email, $jobid, $rundir) = @_;

  my $oldsge = "$scriptsdir/sge-template.sh";
  my $newsge = "sge-$jobid.sh";
  open(NEWCONF, "> $newsge") or die "Cannot open $newsge: $!";
  open(OLDCONF, $oldsge) or die "Cannot open $oldsge: $!";
  while(<OLDCONF>) {
    s/iteration/$iteration/g;
    s/DIR/$rundir/g;
    s/\@JOBID\@/$jobid/g;
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
    my @files = ("loop-$jobid.py", "pdb-$jobid.pdb", "toptext-$jobid.tex");
    for my $file (@files) {
      copy($file, $jobdir) or die "Copy of $file failed: $!";
    }
    chdir($jobdir) or die "Cannot change to $jobdir: $!";

    # Make SGE submission script
    generate_script($iteration, $email, $jobid, $jobdir);

    # SGE run
    my $result = `${sge_bindir}/qsub sge-$jobid.sh`;

    if ($result =~ /Your job\-array (\d+)\./) {
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
  my ($rundir, $finisheddir) = @_;
  chdir($rundir);
  my @running = glob("*AF*");
  for my $job (@running) {
    chdir($rundir);
    my @statlst = stat("$job/sge-jobid");
    my $timenow = time();
    if (@statlst) {
      open(FILE, "$job/sge-jobid")
          or die "Cannot open job ID file $job/sge-jobid: $!";
      my $sge_jobid = <FILE>;
      chomp $sge_jobid;
      my $status = `${sge_bindir}/qstat -j $sge_jobid 2>&1`;
      if ($status =~ /^Following jobs do not exist/) {
        finish_job($job, $finisheddir);
        unlink("$finisheddir/$job/sge-jobid") or die "Cannot delete sge-jobid: $!";
      } elsif ($timenow - $statlst[9] > 60*60*24*7) {
        # Complain about running jobs after 7 days
        print "ModLoop job $job still running...\n";
      }
    # If the directory is empty, just delete it:
    } elsif (!rmdir($job)) {
      print "ModLoop job $job has no SGE job ID, but is not in finished directory\n";
    }
  }
}


# Expire old jobs
sub expire_jobs {
  my ($finisheddir) = @_;
  chdir($finisheddir);
  my $timenow = time();
  my @jobs = glob("*AF*");
  for my $job (@jobs) {
    my @statlst = stat($job);
    if (@statlst and $timenow - $statlst[9] > 60*60*24*15) {
      # Delete finished job directories more than 15 days old
      rmtree($job);
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
  my ($job, $finisheddir) = @_;

  # Move job data to finished directory
  mkdir("$finisheddir/$job", 0755) or die "Cannot make finished directory $finisheddir/$job: $!";
  my @files = glob("$job/*");
  for my $file (@files) {
    move($file, "$finisheddir/$job") or die "Cannot move $file to $finisheddir: $!";
  }
  # Note that this may fail if rundir is on NFS; we clean empty directories
  # elsewhere
  rmdir($job);

  chdir($finisheddir);
  my $winner = get_winner($job);

  open(EMAIL, "$job/email") or die "Cannot open email: $!";
  my $email = <EMAIL>;
  chomp $email;
  close EMAIL;

  if ($winner eq "") {
    # job failed for some reason
    email_job_failure($email, $job);
  } else {
    email_job_results($email, $job, $winner);
  }

  # Compress PDB files to save space
  # system("gzip $job/*.pdb");
}

# Report a failed job by email
sub email_job_failure {
  my ($email, $job) = @_;

  open(MAIL, "| /bin/mail -s 'ModLoop job FAILED' $modloop_email $email")
      or die "Cannot open pipe: $!";
  print MAIL "Your ModLoop job $job failed to produce any output models.\n";
  print MAIL "This is usually caused by incorrect inputs (e.g. corrupt PDB\n";
  print MAIL "file, incorrect loop selection).\n\n";
  print MAIL "For a discussion of some common input errors, please see the\n";
  print MAIL "help page at http://salilab.org/modloop/help.html#errors\n\n";
  print MAIL "For reference, the MODELLER log is shown below. If the problem\n";
  print MAIL "is not clear from this log (or if no log is shown), please\n";
  print MAIL "contact us for further assistance.\n\n";
  my @logs = glob("$job/*.log");
  if (scalar(@logs) > 0) {
    open(LOG, $logs[0]) or die "Cannot open $logs[0]: $!";
    while(<LOG>) {
      print MAIL;
    }
    close LOG;
  }
  close MAIL or die "Cannot close pipe: $!";
}

# Return top-scoring PDB by email
sub email_job_results {
  my ($email, $job, $winner) = @_;

  open(HEADER, "$job/toptext-$job.tex") or die "Cannot open header: $!";
  open(PDB, $winner) or die "Cannot open top-scoring PDB $winner: $!";

  open(MAIL, "| /bin/mail -s 'ModLoop results' $modloop_email $email")
      or die "Cannot open pipe: $!";
  while(<HEADER>) {
    print MAIL;
  }
  while(<PDB>) {
    print MAIL;
  }
  close MAIL or die "Cannot close pipe: $!";
}
