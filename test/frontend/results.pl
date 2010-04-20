#!/usr/bin/perl -w

use saliweb::Test;
use Test::More 'no_plan';
use Test::Exception;
use File::Temp qw(tempdir);

BEGIN {
    use_ok('modloop');
    use_ok('saliweb::frontend');
}

my $t = new saliweb::Test('modloop');

# Check results page

# Test allow_file_download
{
    my $self = $t->make_frontend();
    is($self->allow_file_download('bad.log'), '',
       "allow_file_download bad file");

    is($self->allow_file_download('output.pdb'), 1,
       "                    good file");
}

# Check display_ok_job
{
    my $frontend = $t->make_frontend();
    my $job = new saliweb::frontend::CompletedJob($frontend,
                        {name=>'testjob', passwd=>'foo', directory=>'/foo/bar',
                         archive_time=>'2009-01-01 08:45:00'});
    my $ret = $frontend->display_ok_job($frontend->{CGI}, $job); 
    like($ret, '/Job.*testjob.*has completed.*output\.pdb.*' .
               'Download output PDB/ms', 'display_ok_job');
}

# Check display_failed_job
{
    my $frontend = $t->make_frontend();
    my $job = new saliweb::frontend::CompletedJob($frontend,
                        {name=>'testjob', passwd=>'foo', directory=>'/foo/bar',
                         archive_time=>'2009-01-01 08:45:00'});
    my $ret = $frontend->display_failed_job($frontend->{CGI}, $job); 
    like($ret, '/Your ModLoop job.*testjob.*failed to produce any output.*' .
               'please see the.*#errors.*help page.*For more information, ' .
               'you can.*failure\.log.*download the MODELLER log file.*' .
               'contact us/ms',
         'display_failed_job');
}

# Check get_results_page
{
    my $frontend = $t->make_frontend();
    my $job = new saliweb::frontend::CompletedJob($frontend,
                        {name=>'testjob', passwd=>'foo', directory=>'/foo/bar',
                         archive_time=>'2009-01-01 08:45:00'});
    my $tmpdir = tempdir(CLEANUP=>1);
    ok(chdir($tmpdir), "chdir into tempdir");

    my $ret = $frontend->get_results_page($job);
    like($ret, '/Your ModLoop job.*testjob.*failed to produce any output/',
         'get_results_page (failed job)');

    ok(open(FH, "> output.pdb"), "Open output.pdb");
    ok(close(FH), "Close output.pdb");

    $ret = $frontend->get_results_page($job);
    like($ret, '/Job.*testjob.*has completed/',
         '                 (successful job)');

    chdir("/");
}
