#!/usr/local/bin/perl -w

# Display status of the ModLoop queue

use strict;
use File::Basename;
use CGI qw/:standard /;
use CGI::Carp;
# To catch all fatal errors in the browser:
#use CGI::Carp qw(fatalsToBrowser);

# Substituted in at install time by Makefile:
my $queuedir="@QUEUEDIR@";

my $queued = get_queued(glob("$queuedir/modloop_*"));
my ($running, $gridqueue, $finished, $submitting) =
    get_running(glob("$queuedir/../running/*"));

print header();
print start_html(-title=>"ModLoop queue", -style=>{-src=>"../modloop.css"});

print h1("ModLoop queue");

print table(Tr([ th(['Job ID', 'Status']),
                 get_rows($queued, "Queued"),
                 get_rows($submitting, "Submitting to grid queue"),
                 get_rows($gridqueue, "Waiting in grid queue"),
                 get_rows($running, "Running on grid"),
                 get_rows($finished, "Finished")
               ]));

print_key();

print end_html();

# Format job/status information into HTML table rows
sub get_rows {
  my ($jobids, $status) = @_;

  my @rows;
  for my $job (@$jobids) {
    push @rows, td([$job, $status]);
  }
  return @rows;
}

# Get a list of all jobs in the ModLoop queue
sub get_queued {
  my @queuefiles = @_;
  my @queued;

  foreach my $job (@queuefiles) {
    my $base = basename($job);
    if ($base =~ /modloop_(.*)$/) {
      push @queued, $1;
    }
  }
  return \@queued;
}

# Get a list of all jobs submitted to SGE
sub get_running {
  my @runningfiles = @_;
  my (@running, @gridqueue, @finished, @submitting);

  foreach my $job (@runningfiles) {
    my $jobid = basename($job);
    my $in_sge = stat("$job/sge-jobid");
    my $on_node = stat("$job/output.error");
    if ($in_sge) {
      if ($on_node) {
        push @running, $jobid;
      } else {
        push @gridqueue, $jobid;
      }
    } elsif ($on_node) {
      push @finished, $jobid;
    } else {
      push @submitting, $jobid;
    }
  }
  return (\@running, \@gridqueue, \@finished, \@submitting);
}

# Print an informative key
sub print_key {
  print h2("Key");

  print p(b("Queued:"), " the job has been successfully submitted by the " .
          "web interface. If your job is stuck in this state for more than " .
          "15 minutes, contact us for help.");

  print p(b("Submitting to grid queue:"), " the job is in the process of " .
          "being submitted to the grid system. This process should only take " .
          "a few seconds, so if your job is stuck in this state, contact us.");

  print p(b("Waiting in grid queue:"), " the job has been submitted to the " .
          "grid system, and is now waiting for machines to become available. " .
          "When the system is particularly busy, this could take hours or " .
          "days, so please be patient. Resubmitting your job will not help.");

  print p(b("Running on grid:"), " the job is running on our grid machines. " .
          "Again, when the system is particularly busy, this could take " .
          "hours or days.");

  print p(b("Finished:"), " the job has finished. If you did not receive an " .
          "email with your results, please check your spam filter and mail " .
          "server logs, and then contact us.");
}
