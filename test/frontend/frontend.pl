#!/usr/bin/perl -w

use saliweb::Test;
use Test::More 'no_plan';

BEGIN {
    use_ok('modloop');
}

my $t = new saliweb::Test('modloop');

# Test get_start_html_parameters
{
    my $self = $t->make_frontend();
    my %param = $self->get_start_html_parameters("test");
    like($param{-style}->{-src}->[-1], qr/modloop\.css/);
}

# Test get_page_is_responsive
{
    my $self = $t->make_frontend();
    my $r = $self->get_page_is_responsive();
    is($r, 1, 'responsive');
}

# Test get_navigation_links
{
    my $self = $t->make_frontend();
    my $links = $self->get_navigation_links();
    isa_ok($links, 'ARRAY', 'navigation links');
    like($links->[0], qr#<a href="http://modbase/top/">ModLoop Home</a>#,
         'Index link');
    like($links->[1],
         qr#<a href="http://modbase/top/queue.cgi">Current ModLoop queue</a>#,
         'Queue link');
}

# Test get_project_menu
{
    my $self = $t->make_frontend();
    my $txt = $self->get_project_menu();
    like($txt, qr/Developer.*Acknowledgements.*Version testversion/ms,
         'get_project_menu');
}

# Test get_footer
{
    my $self = $t->make_frontend();
    my $txt = $self->get_footer();
    like($txt, qr/A\. Fiser.*Prot Sci.*A\. Fiser.*Bioinformatics/ms,
         'get_footer');
}

# Test get_download_page
{
    my $self = $t->make_frontend();
    my $txt = $self->get_download_page();
    like($txt, qr/source code for this web service is also/ms,
         'get_download_page');
}

# Test get_index_page
{
    my $self = $t->make_frontend();
    my $txt = $self->get_index_page();
    like($txt, qr/ModLoop is a web server/ms,
         'get_index_page');
}

# Test get_index_page
{
    my $self = $t->make_frontend();
    my $help = $self->get_submit_parameter_help();
    isa_ok($help, 'ARRAY', 'get_submit_parameter_help links');
    is(scalar(@$help), 4, 'get_submit_parameter_help length');
}
