#!/usr/bin/perl
#
# 02_lov.t - test harness for the Batch Exec framework: list of values
#
use strict;

use Data::Dumper;
use Logfer qw/ :all /;
#use Log::Log4perl qw/ :easy /;
use Test::More tests => 56;

BEGIN { use_ok('Batch::Exec') };


# -------- constants --------
#use constant DN_TMP_UX => File::Spec->catfile("", "tmp");


# -------- global variables --------
my $log = get_logger(__FILE__);

my $cycle = 1;


# -------- main --------
my $o1 = Batch::Exec->new;
isa_ok($o1, "Batch::Exec",	"class check $cycle"); $cycle++;


# -------- invalid --------
SKIP: {
	skip "lov invalid args", 6;

	ok($o1->lov,				"invalid no args");
	ok($o1->lov("not enough"),		"too few args");
	ok($o1->lov(qw/invalid action hello world/),	"invalid action");
	ok($o1->lov("_register", "lov1", "scalar"), "_register nohash");
	is($o1->lov("_default", "classC"), 4,	"_default invalid class");
	is($o1->lov("_lookup", "lov1", "xx"),	"_lookup non-existant");
}


# -------- register --------
# 'class' => { 'key' => 'description', ... }
my %lov1 = ( 'aa' => 'desc aa', 'bb' => 'desc bb', 'cc' => 'desc cc' );
is($o1->lov("_register", "lov1", \%lov1), 3,	"_register $cycle"); $cycle++;

my %lov2 = ( 'dd' => 'desc dd', 'bb' => 'desc bb', 'cc' => 'desc cc' );
is($o1->lov("_register", "lov2", \%lov2), 3,	"_register $cycle");

is($o1->lov("_register", "lov1", \%lov2), 4,	"merge A<B");
is($o1->lov("_register", "lov2", \%lov1), 4,	"merge B<A");

is_deeply($o1->{'_lov'}->{'lov1'}, $o1->{'_lov'}->{'lov2'},	"merge A=B");


# -------- lov --------
my @lovA = $o1->lov("_lov", "lov1");
my @lovB = $o1->lov("_lov", "lov2");
is(scalar(@lovA), 4,				"_lov size");
is_deeply(\@lovA, \@lovB,			"_lov match");


# -------- clear --------
is($o1->lov("_clear", "classUndef"), 0,		"_clear unregistered");
is($o1->lov("_clear", "lov2"), 4,		"_clear size");
ok(!exists($o1->{'_lov'}->{'lov2'}),		"_clear lov2 DNE");
is(exists($o1->{'_lov'}->{'lov1'}), 1,	"_clear lov1 exists");

is($o1->lov("_register", "lov2", \%lov2), 3,	"re_register $cycle");

$cycle++;

# -------- lookup --------
is($o1->lov("_lookup", "lov1", "aa"), "desc aa",	"_lookup $cycle aa");
is($o1->lov("_lookup", "lov1", "bb"), "desc bb",	"_lookup $cycle bb");
is($o1->lov("_lookup", "lov1", "cc"), "desc cc",	"_lookup $cycle cc");
is($o1->lov("_lookup", "lov1", "dd"), "desc dd",	"_lookup $cycle dd");

$cycle++;


# -------- random --------
my $re_ww = qr/^\w\w$/;

ok($o1->Has('dn_start'),			"Has dn_start attribute");

like($o1->lov("_random", "lov1", $o1, "dn_start"), $re_ww,	"_random $cycle");
like($o1->dn_start, $re_ww,				"verify $cycle random");

$cycle++;

like($o1->lov("_random", "lov2", $o1, "dn_start"), $re_ww,	"_random $cycle");
like($o1->dn_start, $re_ww,				"verify $cycle random");


# -------- default --------
my $old = $o1->dn_start;

is($o1->lov(qw/ _default lov1 /, $o1, qw/ dn_start aa /), $old,	"_default skip");
is($o1->dn_start, $old,					"verify $cycle nochange");

is($o1->dn_start(undef), undef,				"reset attribute");
is($o1->dn_start, undef,				"check attribute");

is($o1->lov(qw/ _default lov1 /, $o1, qw/ dn_start aa /), "aa",	"_default set");
is($o1->dn_start, "aa",					"verify $cycle changed");

$cycle++;


# -------- set --------
is($o1->lov("_set", "lov1", $o1, "dn_start", "cc"), "cc",	"_set $cycle");
is($o1->dn_start, "cc",					"verify $cycle set");

$cycle++;

is($o1->lov("_set", "lov2", $o1, "dn_start", "dd"), "dd",	"_set $cycle");
is($o1->dn_start, "dd",					"verify $cycle set");

$cycle++;


# -------- dummy object with embedded object --------
my $od1 = Dummy->new;

is($od1->obe->lov("_register", "lov2", \%lov2), 3,	"_register $cycle");

my @lov1 = $od1->obe->lov("_lov", "lov2");

$log->debug(sprintf "lov1 [%s]", Dumper(\@lov1));

is(scalar(@lov1), 3,				"_lov size $cycle");

is($od1->value1, undef,			"default undef value1");
is($od1->value2, undef,			"default undef value2");

isnt($od1->obe->lov("_random", "lov2", $od1, "value2"), "",	"_random $cycle");
like($od1->value2, qr/\w\w/,		"random value2");

isnt($od1->obe->lov("_default", "lov2", $od1, "value1", "bb"), "",	"_default $cycle");
is($od1->value1, "bb",			"default value1");

SKIP: {
	skip "invalid attribute", 2;

	isnt($od1->obe->lov("_random", "lov2", $od1, "value3"), "",	"_random $cycle");
	isnt($od1->obe->lov("_default", "lov2", $od1, "value1", "aa"), "",	"_default $cycle");
}

$cycle++;


# -------- second object with same lov --------
my $od2 = Dummy->new;
my @lov2 = $o1->lov("_lov", "lov2");
@lov1 = $o1->lov("_lov", "lov2");
is_deeply(\@lov1, \@lov2, 		"lov match");

is($od2->value2, undef,			"default undef object2");

isnt($od2->obe->lov("_random", "lov2", $od2, "value2"), "",	"_random $cycle");
like($od2->value2, qr/\w\w/,		"random value2");

isnt($od2->obe->lov("_default", "lov2", $od2, "value2", "dd"), "",	"_default $cycle");
like($od2->value2, qr/\w\w/,		"default value2");

is($od2->obe->lov("_set", "lov2", $od2, "value2", "dd"), "dd",	"_set $cycle");

$cycle++;


# -------- dummy class with embedded object --------
package Dummy;

our $AUTOLOAD;
our $count = 0;

sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) or $log->logdie("$self is not an object");

	my $attr = $AUTOLOAD; $attr =~ s/.*://;

	$log->logdie(sprintf "invalid attribute [$attr] on class [%s]", ref($self)) unless exists($self->{$attr});

	if (@_) {
		return $self->{$attr} = shift;
	} else {
		return $self->{$attr};
	}
}

sub DESTROY {
	my $self = shift;

	$log->debug(sprintf "destroying [%d]", $self->id);
}

sub new {
	my ($class) = shift;
	my $self = {};
	bless ($self, $class);

	$self->{'obe'} = Batch::Exec->new();
	$self->{'id'} = ++$count;
	$self->{'value1'} = undef;
	$self->{'value2'} = undef;

	return $self;
}


__END__

=head1 DESCRIPTION

02_lov.t - test harness for the Batch Exec framework

=head1 VERSION

_IDE_REVISION_

=head1 AUTHOR

B<Tom McMeekin> tmcmeeki@cpan.org

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation; either version 2 of the License,
or any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

=head1 SEE ALSO

L<perl>, L<Batch::Exec>.

=cut

