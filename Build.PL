use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Test::WWW::Jaunt',
    license             => 'perl',
    dist_author         => 'Robert Krimen <robertkrimen@gmail.com>',
    dist_version_from   => 'lib/Test/WWW/Jaunt.pm',
    build_requires => {
        'Test::More' => 0,
	'Carp' => 0,
	'CGI' => 0,
	'Test::WWW::Mechanize' => 0,
	'Test::HTML::Lint' => 0,
	'URI' => 0,
	'Path::Class' => 0,
	'LWP' => 0,
    },
    add_to_cleanup      => [ 'Test-WWW-Jaunt-*' ],
);

$builder->create_build_script();
