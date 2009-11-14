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

# Check parse_loop_selection
{
    my ($loops, $start_res, $start_id, $end_res, $end_id, $loop_data) =
        modloop::parse_loop_selection('1::5::16:A:30:A:');
    is(scalar @$loop_data, 8, 'parse_loop_selection loop_data');
    is($loop_data->[0], '1');
    is($loop_data->[1], ' ');
    is($loop_data->[2], '5');
    is($loop_data->[3], ' ');
    is($loop_data->[4], '16');
    is($loop_data->[5], 'A');
    is($loop_data->[6], '30');
    is($loop_data->[7], 'A');
    is(scalar @$start_res, 2, '                     start_res');
    is($start_res->[0], '1');
    is($start_res->[1], '16');
    is(scalar @$start_id, 2, '                     start_id');
    is($start_id->[0], ' ');
    is($start_id->[1], 'A');
    is(scalar @$end_res, 2, '                     end_res');
    is($end_res->[0], '5');
    is($end_res->[1], '30');
    is(scalar @$end_id, 2, '                     end_id');
    is($end_id->[0], ' ');
    is($end_id->[1], 'A');
    is($loops, 2, '                     loops');

    throws_ok { modloop::parse_loop_selection('1::5::16:A:30:') }
              "saliweb::frontend::InputValidationError",
              '                     wrong number of colons';
    like($@, qr/Syntax error in loop selection/,
         '                     error message');

    throws_ok { modloop::parse_loop_selection('1::5::16:A:20:B:') }
              "saliweb::frontend::InputValidationError",
              '                     loop that spans chains';
    like($@, qr/not selected properly.*16:A,.*20:B/ms,
         '                     error message');

    throws_ok { modloop::parse_loop_selection('1::50::16:A:20:B:') }
              "saliweb::frontend::InputValidationError",
              '                     loop that is too long';
    like($@, qr/not selected properly.*1: ,.*50: /ms,
         '                     error message');

    throws_ok { modloop::parse_loop_selection('10::5::16:A:20:B:') }
              "saliweb::frontend::InputValidationError",
              '                     loop that is negative length';
    like($@, qr/not selected properly.*10: ,.*5: /ms,
         '                     error message');

    throws_ok { modloop::parse_loop_selection('1::10::20:A:31:A:') }
              "saliweb::frontend::InputValidationError",
              '                     too many residues';
    like($@, qr/Too many loop residues have been selected.*22 > limit:20/,
         '                     error message');
}
