#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Test::WWW::Jaunt' );
}

diag( "Testing Test::WWW::Jaunt $Test::WWW::Jaunt::VERSION, Perl $], $^X" );
