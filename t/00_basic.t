#!/usr/bin/perl
#
# 00_basic.t - test harness for the Batch Exec framework: basics
#
use strict;

use Data::Dumper;
use Logfer qw/ :all /;
#use Log::Log4perl qw/ :easy /;
use Test::More tests => 149;
use File::Basename;
use File::Spec;

BEGIN { use_ok('Batch::Exec') };


# -------- constants --------
use constant DN_TMP_UX => File::Spec->catfile("", "tmp");
use constant DN_TMP_MS => 'C:\Windows\Temp';
use constant DN_INVALID => '_$$$_';

use constant PFX_THIS => basename($0);


# -------- global variables --------
my $log = get_logger(__FILE__);

my $cycle = 1;


# -------- subroutines --------
sub make_a_file {
	my $dn = shift;
	my $pn = File::Spec->catfile($dn, PFX_THIS);

	my $suffix = "_file_$cycle";
	$pn =~ s/\.t/$suffix/;

	$log->debug("creating [$pn]");

	open(my $fh, ">$pn") || die("open($pn) failed");
	close($fh);

	$cycle++;

	return $pn;
}


# -------- main --------
my $obj1 = Batch::Exec->new;
isa_ok($obj1, "Batch::Exec",	"class check $cycle"); $cycle++;

my $obj2 = Batch::Exec->new(fatal => 0);
isa_ok($obj2, "Batch::Exec",	"class check $cycle"); $cycle++;


# -------- simple attributes --------
my @attr = $obj1->Attributes;
my $attrs = 18;
is(scalar(@attr), $attrs,	"class attributes");
is(shift @attr, "Batch::Exec",	"class okay");

for my $attr (@attr) {

	my $dfl = $obj1->$attr;

	my ($set, $type); if (defined $dfl && $dfl =~ /^[\-\d\.]+$/) {
		$set = -1.1;
		$type = "f`";
	} else {
		$set = "_dummy_";
		$type = "s";
	}

	is($obj1->$attr($set), $set,	"$attr set cycle $cycle");
	isnt($obj1->$attr, $dfl,	"$attr check");

	$log->debug(sprintf "attr [$attr]=%s", $obj1->$attr);

	if ($type eq "s") {
		my $ck = (defined $dfl) ? $dfl : "_null_";

		ok($obj1->$attr ne $ck,	"$attr string");
	} else {
		ok($obj1->$attr < 0,	"$attr number");
	}
	is($obj1->$attr($dfl), $dfl,	"$attr reset");

        $cycle++;
}


# -------- Has --------
SKIP: {
	skip "Has syntax", 1;

	is($obj1->Has, 1,		"object Has none");
}
for my $attr (@attr) {
	is($obj1->Has($attr), 1,	"object Has $attr");
}


# -------- Id --------
is($obj1->Id, 1,			"object identifier one");
is($obj2->Id, 2,			"object identifier two");


# -------- Inherit --------
is($obj1->Inherit($obj2), $attrs - 1,	"inherit same attribute count");


# ---- RO: platform-related -----
ok($obj1->on_cygwin >= 0, 		"on_cygwin any");
ok($obj1->on_linux >= 0, 		"on_linux any");
ok($obj1->on_windows >= 0, 		"on_windows any");
ok($obj1->on_wsl >= 0, 			"on_wsl any");

ok($obj1->like_unix >= 0, 		"like_unix any");
ok($obj1->like_windows >= 0, 		"like_windows any");
if ($obj1->on_wsl || $obj1->on_cygwin) {
	is($obj1->like_windows, $obj1->like_unix, 	"like unix and windows");
} else {
	isnt($obj1->like_windows, $obj1->like_unix, 	"unix unlike_windows");
}


# ---- ckdir, mkdir -----
my $dn_top = ($obj1->on_windows) ? DN_TMP_MS : DN_TMP_UX;
ok( $obj2->ckdir(DN_INVALID) != 0,	"ckdir does not exist");

ok( -d $dn_top,				"confirm top extant");
ok( $obj1->ckdir($dn_top) == 0,		"ckdir top extant");
ok( $obj2->mkdir($dn_top) == 0,		"mkdir top nonfatal");

my $dn_tmp = File::Spec->catdir($dn_top, PFX_THIS);
$dn_tmp =~ s/\.t/_dir/;
$log->debug("dn_tmp [$dn_tmp]");

ok(! -d $dn_tmp,			"mkdir new DNE");
ok( $obj2->ckdir($dn_top) == 0,		"ckdir new nonfatal");
ok( $obj1->mkdir($dn_tmp) == 0,		"mkdir new create");
ok( -d $dn_tmp,				"confirm new extant");
ok( $obj1->ckdir($dn_tmp) == 0,		"ckdir new extant");


# ---- godir, pwd -----
my $dn_cwd = $obj1->pwd;
isnt($dn_cwd, "",			"pwd default");
ok( $obj1->godir($dn_top) == 0,		"godir ok");
ok( $obj2->godir(DN_INVALID) != 0,	"godir warn");
ok( $obj1->godir == 0,			"godir null");
is( $obj1->pwd, $dn_cwd,		"pwd returned");


# ---- extant ----
is($obj2->extant(DN_INVALID), 0,	"extant invalid nonfatal");
is($obj2->extant($dn_top), 1,	"extant top");
is($obj2->extant($dn_tmp), 1,	"extant tmp");

my $fn_tmp1 = make_a_file($dn_tmp);
is($obj1->extant($fn_tmp1, 'f'), 1,	"extant new file cycle=$cycle"); $cycle++;

my $fn_tmp2 = make_a_file($dn_tmp);
is($obj1->extant($fn_tmp2, 'f'), 1,	"extant new file cycle=$cycle"); $cycle++;


# ----- delete -----
my @delete = ($fn_tmp1, $fn_tmp2);

my $fc = 0; for (@delete) { $fc++ if (-f $_); }

is($fc, 2, 				"before delete $cycle"); $cycle++;

$fc = 0; for (@delete) {

	is($obj2->delete($_), 0, 	"delete file $cycle"); $cycle++;

	$fc++ if (-f $_);
}
is($fc, 0, 				"after delete $cycle"); $cycle++;


# ----- dump -----
like($obj1->dump("xxx"), qr{scalar.+xxx},		"dump scalar");
like($obj1->dump("xxx", "yyy"), qr{yyy.+scalar.+xxx},	"dump scalar extra");

like($obj1->dump($obj1), qr{bless},			"dump object");
like($obj1->dump($obj1, "yyy"), qr{yyy.+\sobject},	"dump object extra");

$obj1->dn_start([qw/ hello world /]);
like($obj1->dump("dn_start"), qr{dn_sta.+hel.+world},	"dump attr");
like($obj1->dump("dn_start", "yyy"), qr{yyy.+dn.+hel},	"dump attr extra");

is($obj1->dump("mask %s %d %.2f", qw/ a 1.0 1.0 /), "mask a 1 1.00",	"dump sprintf");

like($obj1->dump([qw/ foo bar /]), qr{foo.+bar},	"dump arrayref");
like($obj1->dump([qw/ foo bar /], "yyy"), qr{yyy.+foo},	"dump arrayref extra");

my %dump = ('foo' => 'bar', 'bar' => 'foo', 'hello' => 'world', 'world' => 'hello');
like($obj1->dump(\%dump), qr{ba.+fo.+ba.+he.+wo.+he},	"dump hashref");
like($obj1->dump(\%dump, "yyy"), qr{yyy.+ba.+fo.+ba},	"dump hashref extra");


# ----- prefix -----
is($obj1->prefix, "00_basic",		"prefix");


# ----- rmdir -----
ok( $obj1->rmdir($dn_tmp) == 0,		"rmdir ok");
isnt( -d $dn_tmp, 0,			"rmdir check");
ok( $obj2->rmdir(DN_INVALID) < 0,	"rmdir warn");


# ----- operating system paths -----
ok(defined($obj1->pn_issue),		"pn_issue defined");
ok(length($obj1->pn_issue) > 5,		"pn_issue string");

ok(defined($obj1->pn_release),		"pn_release defined");
ok(length($obj1->pn_release) > 5,	"pn_release string");

ok(defined($obj1->pn_version),		"pn_version defined");
ok(length($obj1->pn_version) > 5,	"pn_version string");


#-------- powershell --------
if ($obj1->like_windows) {

	like($obj1->powershell, qr/powershell/,		"powershell cmd like_windows");
	like($obj1->powershell("foo"), qr/ByPass.+File\sfoo/,	"powershell file like_windows");
} else {
	like($obj1->powershell, qr/pwsh/,		"powershell cmd other");
	like($obj1->powershell("bar"), qr/File\sbar/,	"powershell file other");
}


# ----- this -----
is($obj1->this, "00_basic.t",		"this");


#-------- winuser --------
if ($obj1->like_windows) {

	like($obj1->winuser, qr/\w+/,	"winuser like_windows");
} else {
	is($obj1->winuser, undef,	"winuser other");
}

#$log->debug(sprintf "obj1 [%s]", Dumper($obj1));

__END__

=head1 DESCRIPTION

00_basic.t - test harness for the Batch Exec framework

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

