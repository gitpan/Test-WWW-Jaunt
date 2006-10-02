use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Test::WWW::Jaunt',
    AUTHOR              => 'Robert Krimen <rkrimen@gmail.com>',
    VERSION_FROM        => 'lib/Test/WWW/Jaunt.pm',
    ABSTRACT_FROM       => 'lib/Test/WWW/Jaunt.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
	'Carp' => 0,
	'CGI' => 0,
	'Test::WWW::Mechanize' => 0,
	'Test::HTML::Lint' => 0,
	'URI' => 0,
	'Path::Class' => 0,
	'LWP' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Test-WWW-Jaunt-*' },
);
