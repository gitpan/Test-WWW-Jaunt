package Test::WWW::Jaunt;

use warnings;
use strict;

=head1 NAME

Test::WWW::Jaunt - A CGI-based testing platform.

=head1 VERSION

Version 0.01_03

=cut

our $VERSION = '0.01_03';

=head1 SYNOPSIS

    use Test::WWW::Jaunt;

=head1 EXPORT

=cut

use Test::WWW::Jaunt::Step;
use CGI qw(a b p br Tr td start_html hr end_html li ul ol base th *table);
use base qw(Class::Accessor);
use Carp;
__PACKAGE__->mk_accessors(qw(query inrender sentheader suppressheader tester));

=head1 FUNCTIONS

=cut

sub mkteststep ($$;$) {
	my $module = shift;
        my $test = shift;
        my $name = shift;
        my $method = lc $test;
	$name = $method unless defined $name;
	$name =~ s/\*$/$method/;
        $method =~ s/\.t$//;
        no strict 'refs';
        return [ $name, sub {
                my $self = shift;
                $self->beginproctor;
                eval {  
                        $module = $module->run($method);
                };
                carp $@ if $@;
                $self->endproctor;
		$self->render($module->mech->response->content) if $module->mech->response;
        } ];
}

sub new {
	my $self = bless {}, shift;
	local %_ = @_;
	$self->{step} = [ map { new Test::WWW::Jaunt::Step($self, $_) } @{ $_{step} || [ $self->STEP ] } ];
	$self->{table} = [ $self->TABLE ];
	$self->tester($_{tester}) or croak "need tester";
	$self->clear;
	return $self;
}

sub reluri { shift->tester->reluri(@_) }

sub dbh { shift->tester->dbh(@_) }

sub home {
	my $self = shift;
	return;
	$self->render(
		a({ -href => "?home=" }, "home"), br,
		a({ -href => "?databasepeek=" }, "peek in the database"), br,
		a({ -href => "?testjaunt=" }, "take a test jaunt"), br,
	);
}

sub databasepeek {
	my $self = shift;
	if (my $table = $self->query->param("table")) {
		my $sth = $self->dbh->prepare(<<_END_);
SELECT * FROM $table
_END_
		$sth->execute;
		$self->render(CGI::table({ border => 1, cellspacing => 0, cellpadding => 4 }));
		$self->render(Tr(th($sth->{NAME})));
		while(my $row = $sth->fetchrow_arrayref) {
			$self->render(Tr(td($row)));
			
		}
		$self->render(CGI::end_table);
	}
	else {

                $self->render(CGI::table({ border => 1, cellspacing => 0, cellpadding => 4 }));
                for my $table ($self->table) {
			my $count = $self->dbh->selectrow_arrayref(<<_END_, undef)->[0];
SELECT count(*) FROM $table
_END_
			$self->render(Tr(td([
				$count,
				a({ href => "?databasepeek=&table=$table" }, "$table"),
			])));
		}
		$self->render(CGI::end_table);
	}
}

sub testjaunt {
	my $self = shift;
	my $query = $self->query;
	my $stepnumber = $query->param("step");
	my $step;
	$step = $self->step($stepnumber) if defined $stepnumber;

	if (defined $query->param("top")) {
		for (my $stepnumber = 1; $stepnumber <= $self->stepcount; $stepnumber++) {
			$self->render(a({ -href => "?frame=&testjaunt=&step=$stepnumber"}, $stepnumber), " ");	
		}
		$self->render(br);
		my ($previous, $next);
		$previous = $stepnumber - 1 if length $stepnumber;
		$next = length $stepnumber ? $stepnumber + 1 : 1;
		$previous = defined $previous && $previous >= 1 ?
			a({ -href => "?frame=&testjaunt=&step=$previous" }, "Previous") : "Previous";
		$next = defined $next && $next <= $self->stepcount ?
			a({ -href => "?frame=&testjaunt=&step=$next" }, "Next") : "Next";
		$self->render("$previous $next");
		if ($step) {
			$self->render(" | ");
			my $test = $step->test;
			my $description = $step->description;

			if ($test =~ m/^http/) {
				$self->render(
					b($description),
					" [" . a({ -href => $test }, $test) . "]"
				);
			}
			else {
				$self->render(b($description));
			}

			if ($step->isbroken) {
				$self->render(" | ", CGI::span({ -class => 'isbroken' }, "broken"));
			}
			elsif ($step->maybebroken) {
				$self->render(" | ", CGI::span({ -class => 'maybebroken' }, "maybe broken"));
			}
			elsif (! $test) {
			}
			$self->render(" | bug ") if ($step->bugcount);
			for my $bug (@{ $step->buglist }) {
				$self->render($step->sketchbug($bug));
			}
			
		}
	}
	elsif (defined $query->param("bottom")) {
		$self->suppressheader(1);
		if (ref $step) {
			$step->run;
		}
		else {
			$self->renderstepguide(1);
		}
	}
	elsif (defined $query->param("frame")) {
		$self->{sentheader} = 1;
		print $query->header, <<_END_,
<html>
<frameset rows="12,90">
<frame src="?testjaunt=&step=$stepnumber&top=" name="top">
<frame src="?testjaunt=&step=$stepnumber&bottom=" name="bottom">
</frameset>
</html>
_END_
	}
	else {
		$self->renderstepguide;
	}
}

sub renderstepguide {
	my $self = shift;
	my $tableonly = ! shift;
	if ($tableonly) {
	 	$self->render(p("Start the jaunt on the ", a({ -href => "?testjaunt=&frame=&step=1" },
			"first step") . " or choose a different step below."));
		$self->render(CGI::div({ style => "padding:4pt;border:1px solid black;float:right" },
			"legend",
			ul({ -style => "list-style:none;margin-left:-1em" },
				li({ -class => "notbroken" }, "fine"),
				li({ -class => "isbroken" }, "is broken"),
				li({ -class => "maybebroken" }, "maybe broken"),
				li({ -class => "" }, "incomplete"),
				
			)));
	}
	$self->render(CGI::start_table);
	for (my $stepnumber = 1; $stepnumber <= $self->stepcount; $stepnumber++) {
		my $step = $self->step($stepnumber);
		$self->render(Tr($step->sketchlineitem($stepnumber)));
	}
	$self->render(end_table);
}

sub clear {
	my $self = shift;
	$self->suppressheader(0);
	$self->sentheader(0);
	$self->inrender(0);
}

sub handle {
	my $self = shift;
	my $query = shift;
	$query = new CGI unless $query;
	$self->query($query);
	$self->clear;
	if	(defined $query->param("home"))		{ $self->home }
	elsif	(defined $query->param("databasepeek"))	{ $self->databasepeek }
	elsif	(defined $query->param("testjaunt"))	{ $self->testjaunt }
	else						{ $self->home }
	$self->renderfooter if $self->inrender;
}

sub renderheader {
	my $self = shift;
	print $self->query->header, start_html({ -style => { code => <<_END_ } });
a:link { 
	text-decoration: none; 
	color: blue
}

a:visited { 
	text-decoration: none; 
	color: blue
}

a:hover, a:active { 
	text-decoration: underline; 
}

.notbroken {
	color: blue
}

.isbroken, a.isbroken {
	color: red
}

.maybebroken, a.maybebroken {
	color: orange
}

.incomplete, a.incomplete {
	text-decoration: strike-through
}

BODY, TD {
	font-family: Verdana, Arial, Helvetica, sans-serif;
	font-size: 11pt
}
_END_
	return if $self->suppressheader;
	print base({ -target => "_top"});
	print CGI::div({ style => "float:left;" },
		join " | ",
		a({ -href => "?home=" }, "home"),
		a({ -href => "?databasepeek=" }, "peek in the database"),
		a({ -href => "?testjaunt=" }, "take a test jaunt"),
	);
	print CGI::div({ style => "float:right;" }, __PACKAGE__ . " $VERSION");
	print CGI::div({ style => "clear:both;" });
	print hr;
}

sub renderfooter {
	my $self = shift;
	print end_html;
}

sub redirect {
	my $self = shift;
	$self->sentheader(1);
	$self->query->redirect(@_);
}

sub render {
	my $self = shift;
	unless($self->sentheader) {
		$self->inrender(1);
		$self->sentheader(1);
		$self->renderheader;
	}
	print @_ if @_;
}

sub step {
	my $self = shift;
	return $self->stepcount unless my $index = shift;
	return $self->{step}->[$index - 1];
}

sub stepcount {
	my $self = shift;
	return scalar @{ $self->{step} };
}

sub table {
	my $self = shift;
	return @{ $self->{table} }
}
=head1 AUTHOR

Robert Krimen, C<< <robertkrimen at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-test-www-jaunt at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-WWW-Jaunt>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::WWW::Jaunt

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-WWW-Jaunt>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-WWW-Jaunt>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-WWW-Jaunt>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-WWW-Jaunt>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2006 Robert Krimen, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Test::WWW::Jaunt
