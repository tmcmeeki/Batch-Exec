#!/usr/bin/perl
#
# 01_platform.t - test harness for the Batch Exec framework: OS and platform
#
use strict;

use Data::Dumper;
use Logfer qw/ :all /;
#use Log::Log4perl qw/ :easy /;
use Test::More tests => 13;
use File::Basename;
use File::Spec;

BEGIN { use_ok('Batch::Exec') };


# -------- constants --------
#use constant DN_TMP_UX => File::Spec->catfile("", "tmp");


# -------- global variables --------
my $log = get_logger(__FILE__);

my $cycle = 1;


# -------- subroutines --------
sub contrived {	# execute a dummy (contrived test)
	my $msg = shift;

	is(1, 1,		"$msg test contrived");
}


# -------- main --------
my $obj1 = Batch::Exec->new;
isa_ok($obj1, "Batch::Exec",	"class check $cycle"); $cycle++;

my $obj2 = Batch::Exec->new('echo' => 1);
isa_ok($obj2, "Batch::Exec",	"class check $cycle"); $cycle++;


# -------- c2a --------
ok(scalar( $obj1->c2a("dir")) >= 2,	"c2a returned data");

ok(scalar( $obj2->c2a("dir")) >= 2,	"c2a returned data");


# -------- where --------
for my $exec (qw/ find perl /) {

	my @where = $obj2->where($exec);

	$log->debug(sprintf "where [%s]", Dumper(\@where));

	ok(scalar(@where) >= 1,		"where $exec");
}

# -------- os_version --------
my @issue = $obj2->os_version;

ok(scalar(@issue),			"os_version has value");

if ($obj1->on_cygwin) {

	like($issue[0], qr/^CYGWIN_NT/,	"os_version on_cygwin");

} elsif ($obj1->on_wsl) {

	isnt($issue[0], "",		"os_version on_wsl");

} elsif ($obj1->on_windows) {

	like($issue[0], qr/Windows/,	"os_version on_windows");
} else {
	isnt($issue[0], "",		"os_version other");
#	contrived("os_version");
}


# -------- whoami --------
isnt($obj1->whoami, "",			"whoami");


# -------- wsl_dist & wsl_active --------
# need to run wsl_dist to get an updated view of "wsl_active"
my $dist = $obj1->wsl_dist;

$log->debug(sprintf "dist [%s]", defined($dist) ? $dist : "EMPTY");

my $wsl_active = $obj1->wsl_active;

ok($wsl_active >= 0,			"wsl_active any");


# -------- wsl_dist --------
if ($obj1->on_cygwin) {

	if ($wsl_active) {
		ok(defined($obj1->wsl_dist),	"wsl_dist defined on_cygwin");
		ok(defined($obj2->wsl_dist),	"wsl_dist echoed on_cygwin");
	} else {
		ok(!defined($obj1->wsl_dist),	"wsl_dist undefined on_cygwin");
		ok(!defined($obj2->wsl_dist),	"wsl_dist echoed on_cygwin");
	}

} elsif ($obj1->on_wsl) {

	if ($wsl_active) {
		ok(defined($obj1->wsl_dist),	"wsl_dist defined on_wsl");
		ok(defined($obj2->wsl_dist),	"wsl_dist echoed on_wsl");
	} else {
		ok(!defined($obj1->wsl_dist),	"wsl_dist undefined on_wsl");
		ok(!defined($obj2->wsl_dist),	"wsl_dist echoed on_wsl");
	}

} elsif ($obj1->on_linux) {

	ok(!defined($obj1->wsl_dist),	"wsl_dist defined on_linux");
	ok(!defined($obj2->wsl_dist),	"wsl_dist echoed on_linux");

} elsif ($obj1->on_windows) {

	if ($wsl_active) {
		ok(defined($obj1->wsl_dist),	"wsl_dist defined on_windows");
		ok(defined($obj2->wsl_dist),	"wsl_dist echoed on_windows");
	} else {
		ok(!defined($obj1->wsl_dist),	"wsl_dist undefined on_windows");
		ok(!defined($obj2->wsl_dist),	"wsl_dist echoed on_windows");
	}

} else {
	ok(!defined($obj1->wsl_dist),	"wsl_dist undefined other");
	ok(!defined($obj2->wsl_dist),	"wsl_dist echoed other");
}


__END__

=head1 DESCRIPTION

01_platform.t - test harness for the Batch Exec framework

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

