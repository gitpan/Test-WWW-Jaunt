package Test::WWW::Jaunt::Step;

use strict;

use Test::More;
use CGI();
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(jaunt originaldescription description buglist isbroken maybebroken test));

sub parse($) {
	my $step = shift;

	my ($description, $test);
	if (ref $step eq "CODE") {
		($description, $test) = ("" + $step, $step);
	}
	elsif (ref $step eq "ARRAY") {
		($description, $test) = @$step;
	}
	elsif ($step =~ m/^http/) {
		($description, $test) = ($step, $step);
	}
	else {
		die "Don't understand step ($step)";
	}

	my $originaldescription = $description;
	my ($bugdescription, $humandescription) = $description =~ m/^\s*(bug(?:\s*[\!\?]?\d+)+\s*:)?\s*(.*)$/i;
	my @buglist;
	if ($bugdescription) {
		my ($buglist) = $bugdescription =~ m/^\s*bug\s*(.*)\s*:\s*$/;
		@buglist = split m/\s+/, $buglist;
	}
	my ($isbroken, $maybebroken);
	my $brokenflag = $humandescription =~ s/^([\!\?])//;
	$brokenflag = $1;
	$isbroken = $brokenflag && $brokenflag eq "!";
	$maybebroken = $brokenflag && $brokenflag eq "?";
	$isbroken ||= grep { m/^!/ } @buglist;
	$maybebroken ||= grep { m/^\?/ } @buglist;

	return ($originaldescription, $humandescription, \@buglist, $isbroken, $maybebroken, $test);
}

sub new {
	my $self = bless {}, shift;
	my $jaunt = shift;
	my $step = shift;
	
	my ($originaldescription, $description, $buglist, $isbroken, $maybebroken, $test) = parse $step;
	$self->jaunt($jaunt);
	$self->originaldescription($originaldescription);
	$self->description($description);
	$self->buglist($buglist);
	$self->isbroken($isbroken);
	$self->maybebroken($maybebroken);
	$self->test($test);

	return $self;
}

sub bugcount {
	my $self = shift;
	return scalar @{ $self->{buglist} };
}

sub run {
	my $self = shift;
	my $test = $self->test;
	if (ref $test eq "CODE") {
		$test->($self);
	}
	elsif (! $test) {
			$self->jaunt->render(CGI::p("This test has not been written:"), CGI::h2($self->description));
	}
	elsif ($test =~ m/^http/) {
		$self->jaunt->redirect($test);
	}
	else {
		$self->jaunt->render(CGI::h2("Don't know how to handle test ($test)."));
	}
}

sub sketchbug {
	my $self = shift;
	my $bug = shift;

	my $brokenflag = $bug =~ s/^([\!\?])//;
	$brokenflag = $1;
	my $isbroken = $brokenflag && $brokenflag eq "!";
	my $maybebroken = $brokenflag && $brokenflag eq "?";

	my $class = "notbroken";
	if ($isbroken) { $class = "isbroken" }
	elsif ($maybebroken) { $class = "maybebroken" }

	return CGI::a({ -class => $class, -target => "_top",
		-href => "https://www.photobird.com:8801/bugs/show_bug.cgi?id=$bug" }, $bug);
}

sub sketchlineitem {
	my $self = shift;
	my $stepnumber = shift;
	my $descriptionclass = "notbroken";
	if ($self->isbroken) { $descriptionclass = "isbroken" }
	elsif ($self->maybebroken) { $descriptionclass = "maybebroken" }
	my $test = $self->test;
	
	return CGI::td([
		CGI::a({ -target => "_top", -href => "?frame=&testjaunt=&step=$stepnumber"}, $stepnumber),
		($test ? CGI::a({ -class => $descriptionclass, -target => "_top",
		-href => "?bottom=&testjaunt=&step=$stepnumber"}, $self->description) :
			$self->description),
		join(" ", map { $self->sketchbug($_) } @{ $self->buglist }),
	]);
}

sub beginproctor {
	my $self = shift;
	$self->jaunt->render("<pre>");
	Test::More->builder->reset;
	Test::More->builder->output(\*STDOUT);
	Test::More->builder->failure_output(\*STDOUT);
	Test::More->builder->todo_output(\*STDOUT);
	my $plan = shift;
	plan tests => $plan if defined $plan;
}

sub endproctor {
	my $self = shift;
	$self->jaunt->render("</pre>")
}

sub render {
	my $self = shift;
	return $self->jaunt->render(@_);
}

sub redirect {
	my $self = shift;
	return $self->jaunt->redirect(@_);
}

1;
