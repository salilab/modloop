#!/usr/bin/perl -w

use saliweb::Test;
use Test::More 'no_plan';
use Test::Exception;

BEGIN {
    use_ok('modloop');
}

my $t = new saliweb::Test('modloop');

# Check job submission

# Test check_loop_selection
{
    modloop::check_loop_selection("anything");

    throws_ok { modloop::check_loop_selection("") }
              saliweb::frontend::InputValidationError,
              "check_loop_selection, empty loop";
    like($@, qr/No loop segments were specified/, 
         "                      exception message");
}

# Test check_pdb_name
{
    modloop::check_pdb_name("anything");

    throws_ok { modloop::check_pdb_name("") }
              saliweb::frontend::InputValidationError,
              "check_pdb_name, no file";
    like($@, qr/No coordinate file/,
         "                exception message");
}

# Test make_residue_id
{
    is(modloop::make_residue_id('A', '54'), '54:A', 'make_residue_id');
    is(modloop::make_residue_id(' b ', ' 35 '), '35:b',
       '                (whitespace)');
}
