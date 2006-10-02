package Test::WWW::Jaunt::Test;

use strict;
use warnings;

use Test::More;
use Test::WWW::Mechanize;
use Test::HTML::Lint();
use Test::Deep();
use URI;
use HTTP::Request::Common;
use Class::Accessor;
use Path::Class;
use Scalar::Util qw(blessed);
use Carp;
use base qw(Class::Accessor);

__PACKAGE__->mk_accessors(qw(lint mech basedir baseuri));

sub new {
	my $self = bless {}, shift;
	local %_ = @_;
	my $basedir = $_{basedir};
	$basedir = "." unless defined $basedir;
	$basedir = dir $basedir unless blessed $basedir;
	my $baseuri = $_{baseuri} or croak "need a baseuri";
	$baseuri = new URI($baseuri) unless blessed $baseuri;

	my $lint = new HTML::Lint( only_types => HTML::Lint::Error::STRUCTURE );
	my $mech = new Test::WWW::Mechanize stack_depth => 1;
	$self->lint($lint);
	$self->mech($mech);
	$self->basedir($basedir);
	$self->baseuri($baseuri);
	return $self;
}

sub reluri {
	my $self = shift;
	return new_abs URI(shift, $self->baseuri);
}

sub run {
	my $self = shift;
	$self = $self->new unless blessed $self;
	my $test = shift;
	no strict 'refs';
	local $_ = $test;
	s/.*\/(?:\d+-)?(.*)\.t$/$1/;
	tr/-/_/;
	$self->$_();
	return $self;
}

sub html_ok {
	my $self = shift;

	my $lint = $self->lint;
	my $mech = $self->mech;
	unless (Test::HTML::Lint::html_ok($lint, $mech->content, new URI($mech->uri)->path . " has valid html")) {
		my $basedir = $self->basedir;
		$mech->save_content($basedir->file("lint.html"));
		die $mech->uri ." does not have valid html";
	}
	for my $form ($mech->forms) {
		Test::Deep::cmp_deeply($form->enctype, Test::Deep::any("", "application/x-www-form-urlencoded",
			"multipart/form-data"),
			"valid enctype in form for " . new URI($form->action)->path);
	}
}

sub get_title_ok {
	my $self = shift;
	my ($url, $title, $message) = @_;

	my $mech = $self->mech;
	$mech->get_ok($url, $message || "get $url");
	$mech->title_is($title, "found title \"$title\"");
	$self->html_ok;
}

sub follow_link_title_ok {
	my $self = shift;
	my ($link, $title, $message) = @_;

	my $mech = $self->mech;
	$mech->follow_link_ok($link, $message);
	ref $title ?
		$mech->title_like($title, "found title \"$title\"") :
		$mech->title_is($title, "found title \"$title\"");
	$self->html_ok;
}

sub submit_form {
	my $self = shift;

	my $mech = $self->mech;
	$mech->submit_form(@_);
	$self->html_ok;
}

sub submit_form_upload {
	my $self = shift;

	my $mech = $self->mech;
	$mech->request(POST $mech->current_form->action, Content_Type => 'form-data', Content => shift);
	$self->html_ok;
}

1;
