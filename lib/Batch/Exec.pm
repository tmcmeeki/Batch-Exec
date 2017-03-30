package Batch::Exec;
# $Header: /home/tomby/src/perl/RCS/zzz_template_class.pm,v 1.11 2015/09/25 21:10:51 tomby Exp $
#
# Batch::Exec - Batch executive framework: common routines and error handling
#
# History:
# $Log$

=head1 NAME

Batch::Exec - Batch executive framework: common routines and error handling

=head1 AUTHOR

Copyright (C) 2017  B<Tom McMeekin> E<lt>tmcmeeki@cpan.orgE<gt>

=head1 SYNOPSIS

  use Batch::Exec;
  blah blah blah

=head1 DESCRIPTION

___detailed_class_description_here___

=over 4

=item OBJ->attribute1

tba

=item OBJ->method1

tba

=back

=cut

use 5.010000;
use strict;
use warnings;

# --- includes ---
use Carp qw(cluck confess);     # only use stack backtrace within class
use Data::Dumper;
use Cwd;
use Batch::Log qw/ :all /;

use vars qw/ @EXPORT $VERSION /;


# --- package constants ---

#use constant PN_TEMP => File::Spec->catfile($ENV{'HOME'}, "tmp");


# --- package globals ---
$VERSION = sprintf "%d.%03d", q$Revision: 1.11 $ =~ /(\d+)/g;
our $AUTOLOAD;


# --- package locals ---
my $_n_objects = 0;     # counter of objects created.

my %attribute = (
	_n_objects => \$_n_objects,
	_id => undef,
	_log => get_logger("Batch::Exec"),
	_dn_start => cwd,       # default this value, may need it later!
	autoheader => 0,        # automatically put a header on tempfiles
	echo => 0,              # echo stdout from execute
	fatal => 1,             # controls whether failed checks "die"
	retry => 1,		# default retry count
);


#INIT { };


sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) or confess "$self is not an object";

	my $name = $AUTOLOAD;
	$name =~ s/.*://;   # strip fully−qualified portion

	unless (exists $self->{_permitted}->{$name} ) {
		confess "no attribute [$name] in class [$type]";
	}

	if (@_) {
		return $self->{$name} = shift;
	} else {
		return $self->{$name};
	}
}
sub new {
	my ($class) = shift;
	#my $self = $class->SUPER::new(@_);
	my $self = { _permitted => \%attribute, %attribute };

	$self->{_id} = ++ ${ $self->{_n_objects} };

	bless ($self, $class);

	my %args = @_;	# start processing any parameters passed
	my ($method,$value);
	while (($method, $value) = each %args) {

		confess "SYNTAX new(method => value, ...) value not specified"
			unless (defined $value);

		$self->_log->debug("method [self->$method($value)]");

		$self->$method($value);
	}

	$self->{'_oft'} = File::Touch->new;

	return $self;
}


# --- public methods ---
sub ckdir {
	my $self = shift;
	my $dn = shift;
	confess "SYNTAX: ckdir(EXPR)" unless defined ($dn);

	return 0 if ($self->ckdir_rx($dn));

	return $self->cough("directory [$dn] does not exist");
}
sub clean { 	# delete all temp files 
	my $self = shift;
	my $count = 0;

	$self->_log->debug(sprintf "tmpdir [%s] _id [%s] _tmpfile [%s]", $self->tmpdir, $self->_id, Dumper($self->_tmpfile))
		if (${^GLOBAL_PHASE} ne 'DESTRUCT');

	return $count
		unless (defined $self->_tmpfile);

	while (my $pn = pop @{ $self->_tmpfile }) {

		next unless (-e $pn); # may have already been deleted elsewhere so check if it actually exists

		if ($self->delete($pn)) {

			push @{ $self->_tmpfile }, $pn;

		} else {

			$count++;
		}
	}
	$self->_log->info("$count temporary entries cleaned out")
		if (${^GLOBAL_PHASE} ne 'DESTRUCT');

	return $count;
}
sub cough {
	my $self = shift;
	my $msg = shift;

	$self->_log->logdie("FATAL $msg")
		if ($self->fatal);

	$self->_log->logwarn("WARNING $msg");

	return 1;
}
sub ckdir_rx { 
	my $self = shift;
	my $dn = shift;

	return 1
		if (defined($dn) && $dn ne "" && -d $dn && -r $dn && -x $dn);

	return 0;
}
sub ckdir_rwx { 
	my $self = shift;
	my $dn = shift;

	return 1
		if ($self->ckdir_rx($dn) && -w $dn);

	return 0;
}
sub delete {	# delete a file or directory
	my $self = shift;
	my $pn = shift;
	confess "SYNTAX: delete(EXPR)" unless defined ($pn);

	if (-d $pn) {

		return $self->rmdir($pn);

	} elsif (-f $pn) {

		$self->_log->info("removing file [$pn]")
			if (${^GLOBAL_PHASE} ne 'DESTRUCT');

		unlink($pn) || $self->cough("unlink($pn) failed");
	}

	return ($self->cough("could not remove file [$pn]"))
		if (-f $pn);

	return 0;
}
sub execute {
	my $self = shift;
	my $c_retry = shift;
	my $ra_stdout = shift;	# optional; will hold command stdout
	my $command = join(" ", @_);
	my $c_exec;
	my ($retval, $stdout);

	$self->_log->info("about to execute [$command]");

	$self->{'retry'} = 1 if (not defined $self->{'retry'});

	$self->_log->debug("retry [$retry] command [$command]");

	for ($c_exec = 0; $c_exec < $self->{'retry; $c_exec++) {

		$self->_log->debug("c_exec [$c_exec] retry [$retry]");

		$stdout = readpipe($command);
		$retval = $?;

		last unless ($retval);
	}

	$self->_log->info("command output:");

	for (split(/\n+/, $stdout)) {

		$self->_log->info("stdout: $_")
			if ($self->{'echo'});

		push @$ra_stdout, $_
			if (defined $ra_stdout);
	}

	return( $self->cough("command [$command] failed after $retry retries"))
		if ($retval ne 0);

	return 0;
}
sub godir {
	my $self = shift;
	my $dn = (@_) ? shift : $self->_dn_start;
#	confess "SYNTAX: godir(EXPR)" unless defined ($dn);

	$self->ckdir_rx($dn) || return($self->cough("invalid directory [$dn]"));

	chdir($dn) || return($self->cough("chdir($dn) failed"));

	$self->pwd;

	return 0;
}
sub mkdir {
	my $self = shift;
	my $dn = shift;

	return 0 if (-d $dn);

	$self->_log->info("creating directory [$dn]");

	mkpath($dn) || $self->cough("mkpath($dn) failed");

	return ($self->cough("could not create directory [$dn]"))
		unless (-d $dn);

	return 0;
}
sub pwd {
	my $self = shift;
	
	my $pwd = cwd;

	$self->_log->info("now in directory [$pwd]");

	return $pwd;
}
sub rmdir {
	my $self = shift;
	my $dn = shift;
	confess "SYNTAX: rmdir(EXPR)" unless defined ($dn);

	return( $self->cough("directory does not exist [$dn]"))
		unless (-d $dn);

	$self->_log->info("pruning directory [$dn]");

	rmtree($dn) || $self->cough("rmtree($dn) failed");

	return ($self->cough("could not prune directory [$dn]"))
		if (-d $dn);

	return 0;
}
DESTROY {
	my $self = shift;

	$self->clean unless ($self->retain);

	$self->purge unless ($self->retain);

	-- ${ $self->{_n_objects} };
}

1;

__END__

=head1 VERSION

$Revision: 1.11 $

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

L<perl>.

=cut

