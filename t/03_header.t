#!/usr/bin/perl
#
# 03_header.t - test harness for the Batch Exec framework: list of values
#
use strict;

use Data::Dumper;
use Logfer qw/ :all /;
#use Log::Log4perl qw/ :easy /;
use Test::More tests => 40;

BEGIN { use_ok('Batch::Exec') };


# -------- constants --------
use constant EXT => ".tmp";


# -------- global variables --------
my $log = get_logger(__FILE__);

my $cycle = 1;


# -------- subroutines --------
sub check_header {
	my $fno = shift;
	my $flag = shift;

	for my $obj (@_) {

		isa_ok($obj, "Batch::Exec",	"class check $cycle");

		my $leader = $obj->leader;
		my $prefix = $obj->prefix;

		is($obj->autoheader($flag), $flag,	"autoheader $cycle");

		isnt($leader, "",		"leader has value $cycle");

		open(my $fh, ">$fno") || $log->logdie("open($fno) failed");

		is($obj->header($fh), $flag,	"header write $cycle");

		ok(-f $fno,			"output file $cycle");

		printf $fh "dummy\ndummy\n";

		close($fh) || $log->logdie("close($fno) failed");

		my @lines = $obj->c2l("cat $fno");
#		$log->debug(sprintf "lines [%s]", Dumper(\@lines));
		my @match = ();
		my $auto = ($obj->autoheader) ? 1 : 0;
		my $lead = ($obj->autoheader) ? 2 : 0;

		@match = grep(/$prefix/, @lines);
		is(scalar(@match), $auto,	"matched prefix $cycle");

		@match = grep(/^$leader/, @lines);
		is(scalar(@match), $lead,	"matched leader $cycle");

		@match = grep(/timestamp/, @lines);
		is(scalar(@match), $auto,	"matched timestamp $cycle");

		@match = grep(/dummy/, @lines);
#		$log->debug(sprintf "match [%s]", Dumper(\@match));
		is(scalar(@match), 2,		"matched dummy $cycle");

		$cycle++;
	}
}


# -------- main --------
my $o1 = Batch::Exec->new;
my $o2 = Batch::Exec->new;


# -------- leader --------
is($o2->leader("REM"), "REM",	"leader override");
isnt($o1->leader, $o2->leader,	"leader mismatch");


# -------- header --------
my $fno = $o1->prefix . EXT;

check_header($fno, 1, $o1, $o2);
check_header($fno, 0, $o1, $o2);

unlink $fno;

is(-f $fno, undef,		"cleanup");

__END__

=head1 DESCRIPTION

03_header.t - test harness for the Batch Exec framework

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

