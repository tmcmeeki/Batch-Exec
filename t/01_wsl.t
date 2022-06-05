#!/usr/bin/perl
#
# 01_wsl.t - test harness for the Batch Exec framework: WSL
#
use strict;

use Data::Dumper;
use Logfer qw/ :all /;
#use Log::Log4perl qw/ :easy /;
use Test::More tests => 11;
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

my $obj2 = Batch::Exec->new('echo' => 1);;
isa_ok($obj2, "Batch::Exec",	"class check $cycle"); $cycle++;


# -------- cmd2array --------
ok(scalar( $obj1->cmd2array("dir")) >= 2,	"cmd2array returned data");

ok(scalar( $obj2->cmd2array("dir")) >= 2,	"cmd2array returned data");


# -------- where --------
for my $exec (qw/ find perl /) {

	my @where = $obj2->where($exec);

	$log->debug(sprintf "where [%s]", Dumper(\@where));

	ok(scalar(@where) >= 1,		"where $exec");
}

# -------- os_version --------
my @issue = $obj2->os_version;

ok(scalar(@issue),				"os_version not null");

if ($obj1->on_cygwin) {

	like($issue[0], qr/^CYGWIN_NT/,		"os_version on_cygwin");

} elsif ($obj1->on_wsl) {

	isnt($issue[0], $obj1->null,		"os_version on_wsl");

} elsif ($obj1->on_windows) {

	like($issue[0], qr/Windows/,		"os_version on_windows");
} else {
	isnt($issue[0], $obj1->null,		"os_version other");
#	contrived("os_version");
}


# -------- wsl_distro --------
if ($obj1->on_cygwin) {
	ok(defined($obj1->wsl_distro),	"wsl_distro defined on_cygwin");

	ok(defined($obj2->wsl_distro),	"wsl_distro echoed on_cygwin");

} elsif ($obj1->on_wsl) {
	ok(defined($obj1->wsl_distro),	"wsl_distro defined on_wsl");

	ok(defined($obj2->wsl_distro),	"wsl_distro echoed on_wsl");

} elsif ($obj1->on_linux) {
	ok(!defined($obj1->wsl_distro),	"wsl_distro defined on_linux");

	ok(defined($obj2->wsl_distro),	"wsl_distro echoed on_linux");

} elsif ($obj1->on_windows) {
	ok(defined($obj1->wsl_distro),	"wsl_distro defined on_windows");

	ok(defined($obj2->wsl_distro),	"wsl_distro echoed on_windows");

} else {
	ok(defined($obj1->wsl_distro),	"wsl_distro defined other");

	ok(defined($obj2->wsl_distro),	"wsl_distro echoed other");
}

my $dist = $obj1->wsl_distro;

$log->debug(sprintf "dist [%s]", defined($dist) ? $dist : $obj1->null);

__END__

=head1 DESCRIPTION

01_wsl.t - test harness for the Batch Exec framework

=head1 VERSION

___EUMM_VERSION___

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

