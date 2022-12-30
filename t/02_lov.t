#!/usr/bin/perl
#
# 02_lov.t - test harness for the Batch Exec framework: list of values
#
use strict;

use Data::Dumper;
use Logfer qw/ :all /;
#use Log::Log4perl qw/ :easy /;
use Test::More tests => 38;

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
	ok($o1->lov("_register", "classA", "scalar"), "_register nohash");
	is($o1->lov("_default", "classC"), 4,	"_default invalid class");
	is($o1->lov("_lookup", "classA", "xx"),	"_lookup non-existant");
}


# -------- register --------
# 'class' => { 'key' => 'description', ... }
my %classA = ( 'aa' => 'desc aa', 'bb' => 'desc bb', 'cc' => 'desc cc' );
is($o1->lov("_register", "classA", \%classA), 3,	"_register A");

my %classB = ( 'dd' => 'desc dd', 'bb' => 'desc bb', 'cc' => 'desc cc' );
is($o1->lov("_register", "classB", \%classB), 3,	"_register B");

is($o1->lov("_register", "classA", \%classB), 4,	"merge A<B");
is($o1->lov("_register", "classB", \%classA), 4,	"merge B<A");

is_deeply($o1->{'_lov'}->{'classA'}, $o1->{'_lov'}->{'classB'},	"merge A=B");


# -------- lov --------
my @lovA = $o1->lov("_lov", "classA");
my @lovB = $o1->lov("_lov", "classB");
is(scalar(@lovA), 4,				"_lov size");
is_deeply(\@lovA, \@lovB,			"_lov match");


# -------- clear --------
is($o1->lov("_clear", "classB"), 4,		"_clear size");
ok(!exists($o1->{'_lov'}->{'classB'}),		"_clear classB DNE");
is(exists($o1->{'_lov'}->{'classA'}), 1,	"_clear classA exists");

is($o1->lov("_register", "classB", \%classB), 3,	"re_register B");


# -------- lookup --------
is($o1->lov("_lookup", "classA", "aa"), "desc aa",	"_lookup A aa");
is($o1->lov("_lookup", "classA", "bb"), "desc bb",	"_lookup A bb");
is($o1->lov("_lookup", "classA", "cc"), "desc cc",	"_lookup A cc");
is($o1->lov("_lookup", "classA", "dd"), "desc dd",	"_lookup A dd");


# -------- random --------
my $re_ww = qr/^\w\w$/;

ok($o1->Has('dn_start'),			"Has dn_start attribute");

like($o1->lov("_random", "classA", "dn_start"), $re_ww,	"_random A");
like($o1->dn_start, $re_ww,				"verify A random");

like($o1->lov("_random", "classB", "dn_start"), $re_ww,	"_random B");
like($o1->dn_start, $re_ww,				"verify B random");


# -------- default --------
my $old = $o1->dn_start;

is($o1->lov(qw/ _default classA dn_start aa /), $old,	"_default skip");
is($o1->dn_start, $old,					"verify A nochange");

is($o1->dn_start(undef), undef,				"reset attribute");
is($o1->dn_start, undef,				"check attribute");

is($o1->lov(qw/ _default classA dn_start aa /), "aa",	"_default set");
is($o1->dn_start, "aa",					"verify A changed");


# -------- set --------
is($o1->lov("_set", "classA", "dn_start", "cc"), "cc",	"_set A");
is($o1->dn_start, "cc",					"verify A set");

is($o1->lov("_set", "classB", "dn_start", "dd"), "dd",	"_set B");
is($o1->dn_start, "dd",					"verify B set");


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

