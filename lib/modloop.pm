package modloop;
use saliweb::frontend;

use strict;

our @ISA = "saliweb::frontend";

sub new {
    return saliweb::frontend::new(@_, "##CONFIG##");
}

# Add our own CSS to the page header
sub get_start_html_parameters {
  my ($self, $style) = @_;
  my %param = $self->SUPER::get_start_html_parameters($style);
  push @{$param{-style}->{'-src'}}, 'html/modloop.css';
  return %param;
}

sub get_page_is_responsive {
    return 1; # All web pages should look OK on a smartphone
}

sub get_navigation_links {
    my $self = shift;
    my $q = $self->cgi;
    return [
        $q->a({-href=>$self->index_url}, "ModLoop Home"),
        $q->a({-href=>$self->queue_url}, "Current ModLoop queue"),
        $q->a({-href=>$self->help_url}, "Help"),
        $q->a({-href=>$self->download_url}, "Download"),
        $q->a({-href=>$self->contact_url}, "Contact")
#       $q->a({-href=>$self->news_url}, "News"),
        ];
}

sub get_project_menu {
    my $self = shift;
    my $version = $self->version_link;
    return <<MENU;
<p>&nbsp;</p>
<p>&nbsp;</p>
<p>&nbsp;</p>
<h4><small>Developer:</small></h4><p>Andras Fiser</p>
<h4><small>Acknowledgements:</small></h4>
<p>Ben Webb<br />
Ursula Pieper<br />
<br />
Andrej Sali</p>
<p><i>Version $version</i></p>
MENU
}

sub get_footer {
    my $self = shift;
    my $htmlroot = $self->htmlroot;
    return <<FOOTER;
<div id="address">
<center><a href="https://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;list_uids=11045621&amp;query_hl=2&amp;itool=pubmed_docsum">
<b>A. Fiser,  R.K.G. Do and A. Sali, Prot Sci, (2000) <i>9,</i> 1753-1773</b></a>
&nbsp;<a href="https://salilab.org/pdf/Fiser_ProteinSci_2000.pdf"><img src="$htmlroot/img/pdf.gif" alt="PDF" /></a><br />
<a href="https://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;list_uids=14668246&amp;query_hl=2&amp;itool=pubmed_docsum">
<b>A. Fiser, and A. Sali, Bioinformatics, (2003) <i>19,</i> 2500-01</b></a>
&nbsp;<a href="https://salilab.org/pdf/Fiser_ProteinSci_2000.pdf"><img src="$htmlroot/img/pdf.gif" alt="PDF" /></a></center>
</div>
FOOTER
}

sub get_index_page {
    my $self = shift;
    my $q = $self->cgi;
    my $greeting = <<GREETING;
<p>ModLoop is a web server for automated modeling of loops in protein
structures. The server relies on the loop modeling routine in MODELLER
that predicts the loop conformations by satisfaction of spatial restraints,
without relying on a database of known protein structures.
<br />&nbsp;</p>
GREETING
    return "<div id=\"resulttable\">\n" .
           $q->h2({-align=>"center"},
                  "ModLoop: Modeling of Loops in Protein Structures") .
           $q->start_form({-name=>"modloopform", -method=>"post",
                           -action=>$self->submit_url}) .
           $q->table(
               $q->Tr($q->td({-colspan=>2}, $greeting)) .
               $q->Tr($q->td($q->h3("General information",
                                    $self->help_link("general")))) .
               $q->Tr($q->td("Email address (optional)",
                             $self->help_link("email")),
                      $q->td($q->textfield({-name=>"email",
                                            -value=>$self->email,
                                            -class=>"wide",
                                            -size=>"5"}))) .
               $q->Tr($q->td("Modeller license key",
                             $self->help_link("modkey")), 
                      $q->td($q->textfield({-name=>"modkey",
                                            -value=>$self->modeller_key,
                                            -class=>"wide",
                                            -size=>"5"}))) .
               $q->Tr($q->td("Upload coordinate file",
                             $self->help_link("file"), $q->br),
                      $q->td($q->filefield({-name=>"pdb"}))) .
               $q->Tr($q->td($q->h3("Enter loop segments",
                                    $self->help_link("loop"))),
                      $q->td($q->textarea({-name=>"loops",
                                           -class=>"loopsegs",
                                           -rows=>"10", -cols=>"20"}))) .
               $q->Tr($q->td($q->h3("Name your model",
                                    $self->help_link("name"))),
                      $q->td($q->textfield({-name=>"name",
                                            -class=>"wide",
                                            -value=>"loop", -size=>"9"}))) .
               $q->Tr($q->td({-colspan=>"2"},
                             "<center>" .
                             $q->input({-type=>"submit", -value=>"Process"}) .
                             $q->input({-type=>"reset", -value=>"Reset"}) .
                             "</center><p>&nbsp;</p>"))) .
           $q->end_form .
           "</div>\n";
}

sub get_submit_parameter_help {
    my $self = shift;
    return [
        $self->parameter("name", "Job name", 1),
        $self->file_parameter("pdb", "PDB file to be refined"),
        $self->parameter("modkey", "MODELLER license key"),
        $self->parameter("loops", "Loops to be refined")
    ];
}

sub get_submit_page {
    my $self = shift;
    my $q = $self->cgi;

    my $user_pdb_name = $q->upload('pdb');              # uploaded file handle
    my $user_name     = $q->param('name')||"";          # user-provided job name
    my $email         = $q->param('email')||undef;      # user's e-mail
    my $modkey        = $q->param('modkey')||"";        # MODELLER key
    my $loops         = $q->param('loops')||"";         # selected loops

    check_optional_email($email);
    check_modeller_key($modkey);
    check_loop_selection($loops);
    check_pdb_name($user_pdb_name);

    my ($start_res, $start_id, $end_res, $end_id, $loop_data);
    ($loops, $start_res, $start_id, $end_res, $end_id, $loop_data) =
                parse_loop_selection($loops);


    ###################################
    ### read coordinates from file, and check loop residues

    my $user_pdb = read_pdb_file($user_pdb_name, $loops, $start_res,
                                 $start_id, $end_res, $end_id);

    my $job = $self->make_job($user_name);
    my $jobdir = $job->directory;

    ### write pdb input
    my $pdb_input = "$jobdir/input.pdb";
    open(INPDB, "> $pdb_input")
       or throw saliweb::frontend::InternalError("Cannot open $pdb_input: $!");
    print INPDB $user_pdb;
    close INPDB
       or throw saliweb::frontend::InternalError("Cannot close $pdb_input: $!");

    ### write loop selection
    my $loop_file = "$jobdir/loops.tsv";
    open(OUT, "> $loop_file")
       or throw saliweb::frontend::InternalError("Cannot open $loop_file: $!");
    print OUT join("\t", @$loop_data);
    close OUT
       or throw saliweb::frontend::InternalError("Cannot close $loop_file: $!");

    $job->submit($email);

    ## write subject details into a file and pop up an exit page
    my $loopout = "";
    for (my $j=0;$j<$loops;$j++) {
      $loopout .= $start_res->[$j].":".$start_id->[$j]."-".$end_res->[$j].
                  ":".$end_id->[$j]." ";
    }

    my $return=
      $q->h1("Job Submitted") .
      $q->hr .
      $q->p("Your job has been submitted to the server! " .
            "Your job ID is " . $job->name . ".") .
      $q->p("Results will be found at <a href=\"" .
            $job->results_url . "\">this link</a>.");
    if ($email) {
        $return.=$q->p("You will be notified at $email when job results " .
                       "are available.");
    }

    $return .=
      $q->p("You can check on your job at the " .
            "<a href=\"" . $self->queue_url .
            "\">ModLoop queue status page</a>.").
      $q->p("The following loop segment(s) will be optimized: $loopout in " .
            "protein: >$user_name< ").
      $q->p("using the method of Fiser et al. (Prot. Sci. (2000) 9,1753-1773)").
      $q->p("The estimated execution time is ~90 min, depending on the load.").
      $q->p("If you experience a problem or you do not receive the results " .
            "for more than 12 hours, please <a href=\"" .
            $self->contact_url . "\">contact us</a>.") .
      $q->p("Thank you for using our server and good luck in your research!").
      $q->p("Andras Fiser");

    return $return;
}

=item parse_loop_selection
Split out loop selection and check it
=cut
sub parse_loop_selection {
    my ($loops) = @_;

    $loops =~ tr/a-z/A-Z/;    # capitalize
    $loops =~ s/\s+//g;       # remove spaces
    $loops =~ s/::/: :/g;     # replace null chain IDs with a single space

    my @loop_data=split (/:/,$loops);

    # Make sure correct number of colons were given
    if (scalar(@loop_data) % 4 != 0) {
        throw saliweb::frontend::InputValidationError(
                  "Syntax error in loop selection: check to make sure you " .
                  "have colons in the correct place (there should be a " .
                  "multiple of 4 colons)");
    }

    my $total_res=0;
    my (@start_res, @start_id, @end_res, @end_id);
    $loops = 0;
    while ($loops*4+3 <= $#loop_data and $loop_data[$loops*4] ne "") {
        $start_res[$loops]=$loop_data[$loops*4];
        $start_id[$loops]=$loop_data[$loops*4+1];
        $end_res[$loops]=$loop_data[$loops*4+2];
        $end_id[$loops]=$loop_data[$loops*4+3];
        #all the selected residues
        $total_res += ($end_res[$loops] - $start_res[$loops] + 1);

        ################################
        # too long loops rejected
        if ((($end_res[$loops]-$start_res[$loops]) > 20)
            || ($start_id[$loops] ne $end_id[$loops])
            || (($end_res[$loops]-$start_res[$loops])<0)
            || ($start_res[$loops] eq "")
            || ($end_res[$loops] eq "")) {
 
            throw saliweb::frontend::InputValidationError(
                    "The loop selected is too long (>20 residues) or " .
                    "shorter than 1 residue or not selected properly " .
                    "(syntax problem?) ".
                    "starting position $start_res[$loops]:$start_id[$loops]," .
                    " ending position: $end_res[$loops]:$end_id[$loops]");
        }
        $loops++;
    }
    ################################
    # too many or no residues rejected
    if ($total_res > 20) {
        throw saliweb::frontend::InputValidationError(
                              "Too many loop residues have been selected ".
                              " (selected:$total_res > limit:20)!");
    }
    if ($total_res <= 0) {
        throw saliweb::frontend::InputValidationError(
                              "No loop residues selected!");
    }
    return ($loops, \@start_res, \@start_id, \@end_res, \@end_id, \@loop_data);
}

=item check_loop_selection
Check for loop selection
=cut
sub check_loop_selection {
    my ($loop) = @_;
    if ($loop eq "") {
        throw saliweb::frontend::InputValidationError(
                       "No loop segments were specified!");
    }
}

=item check_pdb_name
Check if a PDB name was specified
=cut
sub check_pdb_name {
    my ($pdb_name) = @_;
    if (!$pdb_name) {
        throw saliweb::frontend::InputValidationError(
                       "No coordinate file has been submitted!");
    }
}

=item make_residue_id
Format a chain and a residue number into a Modeller style residue:chain string
=cut
sub make_residue_id {
  my ($chain, $residue) = @_;
  $chain =~ s/ //g;
  $residue =~ s/ //g;
  return "$residue:$chain";
}

=item read_pdb_file
Read in uploaded PDB file, and check loop residues
=cut
sub read_pdb_file {
  my ($pdb, $loops, $start_res, $start_id, $end_res, $end_id) = @_;
  my @start_res=@$start_res;
  my @start_id=@$start_id;
  my @end_res=@$end_res;
  my @end_id=@$end_id;

  my $file_contents = "";
  my %residues;
  for (my $i = 0; $i < $loops; $i++) {
    my $resid = &make_residue_id($start_id[$i], $start_res[$i]);
    $residues{$resid} = 1;
    $resid = &make_residue_id($end_id[$i], $end_res[$i]);
    $residues{$resid} = 1;
  }

  if ($pdb) {
    while (<$pdb>) {
      if (/^ATOM.................(.)(....)/) {
        my $resid = &make_residue_id($1, $2);
        if (defined($residues{$resid})) {
          delete $residues{$resid};
        }
      }
      $file_contents .= $_;
    }
  }

  if (scalar(keys %residues) > 0) {
    throw saliweb::frontend::InputValidationError(
                "The following residues were not found in ATOM records in" .
                " the PDB file: " . join(", ", sort keys(%residues)) .
                ". Check that you specified the loop segments correctly, and" .
                " that you uploaded the correct PDB file.");
  } else {
    return $file_contents;
  }
}

sub get_download_page {
    return <<TEXT;
<h2>Running ModLoop locally</h2>

<p>The ModLoop protocol is part of Modeller, which can be downloaded from
<a href="https://salilab.org/modeller/">our website</a> and is free for
academic use. An example Modeller script for loop refinement can be found
<a href="https://salilab.org/modeller/9.17/manual/node36.html">in the Modeller
manual</a>. ModLoop simply builds 300 models with Modeller, and then returns
the single model with the lowest molpdf score.</p>

<p>The source code for this web service is also
<a href="https://github.com/salilab/modloop/">available at GitHub</a>.
</p>
TEXT
}

sub allow_file_download {
    my ($self, $file) = @_;
    return $file eq 'output.pdb' || $file eq 'failure.log'
           || $file eq 'loop.py';
}

sub get_results_page {
    my ($self, $job) = @_;
    my $q = $self->cgi;
    if (-f 'output.pdb') {
        return $self->display_ok_job($q, $job);
    } else {
        return $self->display_failed_job($q, $job);
    }
}

=item display_failed_job
Display the output model for a successful job
=cut
sub display_ok_job {
    my ($self, $q, $job) = @_;
    my $return= $q->p("Job '<b>" . $job->name . "</b>' has completed.");

    $return.= $q->p("<p><a href=\"" . $job->get_results_file_url("output.pdb") .
                    "\">Download output PDB</a>.</p>");
    $return.= $q->p("<p><a href=\"" . $job->get_results_file_url("loop.py") .
                    "\">Download MODELLER script file</a>.</p>");
    $return .= $job->get_results_available_time();
    return $return;
}

=item display_failed_job
Display the log file for a failed job
=cut
sub display_failed_job {
    my ($self, $q, $job) = @_;
    my $return= $q->p("Your ModLoop job '<b>" . $job->name .
                      "</b>' failed to produce any output models.");
    $return.=$q->p("This is usually caused by incorrect inputs " .
                   "(e.g. corrupt PDB file, incorrect loop selection).");
    $return.=$q->p("For a discussion of some common input errors, please see " .
                   "the <a href=\"" . $self->help_url .
                   "#errors\">help page</a>.");
    $return.= $q->p("For more information, you can " .
                    "<a href=\"" . $job->get_results_file_url("failure.log") .
                    "\">download the MODELLER log file</a>. " .
                    "If the problem is not clear from this log, " .
                    "please <a href=\"" .
                    $self->contact_url . "\">contact us</a> for " .
                    "further assistance.");
    return $return;
}

1;
