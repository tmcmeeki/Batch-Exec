package Batch::Exec;

=head1 NAME

Batch::Exec.pm - Batch Executive Framework

=head1 AUTHOR

Copyright (C) 2021  B<Tom McMeekin> tmcmeeki@cpan.org

=head1 SYNOPSIS

  use Batch::Exec;


=head1 DESCRIPTION

A broad batch executive that facilitates sequencing of tasks on any platform.
The basic premise of the batch executive is to provide for temporal cohesion of
commodity shell-like processing, i.e. invocation of sub-shells, file-handling, 
output-processing and the like.  Perhaps most importantly it will tend to halt
processing if something goes wrong! 

Perl aleady has built-in "die/warn" functions, enhanced via the L<Carp> library.
However, the onus is on the developer to apply these consistently to ensure
the correct processing outcome for any tasks executed.
This module assumes control of these basic operations, such that the caller 
script can focus on its core functionality.

There are several key functions of a batch executive:

 1. Log everything that you do, so you can pin-point a fault.
 2. Fatal error handling: stop if something unexpected happens.
 3. Spawn child processes and account for their outputs.
 4. Provide platform-compatible path-naming for any child shells invoked.
 5. Create, track and remove current and aged temporary files.
 6. File-registration: open and close output files, and report on them.
 7. Convenient handling for directories and common file-formats.
 8. Fail-safe directory manipulation and filesystem privilege assignment.
 9. Common text handling functions, platform determination and behaviour.
10. Provide for basic integration to a scheduling facility.
11. Basic data validation via list-of-value lookup.

Such an executive relies on many extant Perl libraries to do much of its 
processing, but wraps consistent handling around their functions.
It also extends the use of these libraries for the most practical defaults
and processsing for all types of batch processing.

As such it simplifies the interface into many lower-level Perl libraries 
in order to make batch processing more reliable and traceable.

=head2 ATTRIBUTES

=over 4

=item OBJ->autoheader

Boolean controls the insertion of a descriptive header to an output file.

=item OBJ->cmd_os_version

The shell command used to determine the operating systems version.

=item OBJ->cmd_os_where

The shell command used to determine the location of an executable.

=item OBJ->dn_start

The starting directory of this process, which gets populated upon object instantiation.

=item OBJ->echo

Boolean controls the display of stdout for selected operations.

=item OBJ->fatal

Boolean controls the fatality of selected operations. A default applies.

=item OBJ->log

The logging object is embedded in this object, per L<Log::Log4perl>.

=item OBJ->pn_issue

The pathname of the OS distribution, generally known as /etc/issue in Linux.

=item OBJ->pn_release

The pathname of the OS release, generally kept under /proc for Linux.

=item OBJ->pn_version

The pathname of the OS version, generally kept under /proc for Linux.

=item OBJ->re_whitespace

The REGULAR expression representing a blank or whitespace string.

=item OBJ->stdfd

The maximum value of a standard file descriptor (i.e. defaults to stderr).

=item OBJ->wsl_active

This flag defaults to false, but will get updated to true if the wsl_dist() 

=item OBJ->wsl_env

Evaluates the shell variable WSL_DISTRO_NAME, which is available inside an
executing WSL instance.

=back

=cut

use strict;
use warnings;
use utf8;

# --- includes ---
use Carp qw(cluck confess);
use Data::Dumper;
use Hash::Merge;
use List::Util qw/ shuffle /;
#use Log::Log4perl qw/ get_logger /;
use Logfer qw/ :all /;
use Path::Tiny;
use Text::Unidecode;


# --- package constants ---
use constant CMD_OS_VERSION_WIN32 => "ver";
use constant CMD_OS_VERSION_UX => "uname";

use constant ENV_WSL_DIST => $ENV{'WSL_DISTRO_NAME'};	# inside WSL

use constant FD_MAX => 2;	# see is_stdio() function

#use constant PN_OS_ISSUE => File::Spec->catfile("", "etc", "issue");
use constant PN_OS_ISSUE => path("/etc/issue");
use constant PN_OS_RELEASE => path("/proc/version");
use constant PN_OS_VERSION => path("/proc/sys/kernel/osrelease");

use constant RE_WHITESPACE => '\s+';


# --- package globals ---
#our @EXPORT = qw();
#our @ISA = qw(Exporter);
our $AUTOLOAD;
our @ISA;
our $VERSION = sprintf "%d.%03d", q[_IDE_REVISION_] =~ /(\d+)/g;


# --- package locals ---
my $_n_objects = 0;
my %_h_lov;			# global lists of values, see lov() method

my %_attribute = (	# _attributes are restricted; no direct get/set
	_id => undef,		# an identifier for this widget
	_inherent => [],	# genes that i'll pass on to my children
	_n_objects => \$_n_objects,
	_lov => \%_h_lov,	# class-level LoV register.
	log => get_logger("Batch::Exec"),
#	dump => undef,
	autoheader => 0,	# automatically put a header on any files
	cmd_os_version => undef,
	cmd_os_where => undef,
	dn_start => undef,	# default this value, may need it later!
	echo => 0,		# echo stdout for selected operations
	fatal => 1,		# controls whether failed checks "die"
	pn_issue => PN_OS_ISSUE,
	pn_release => PN_OS_RELEASE,
	pn_version => PN_OS_VERSION,
	re_whitespace => RE_WHITESPACE,
	stdfd => FD_MAX,
	wsl_active => 0,	# flag shows if WSL installed. see wsl_dist
	wsl_env => ENV_WSL_DIST,	# set only within WSL
);


# --- package methods ---
#INIT {
BEGIN {
	srand(time);	# see lov() method, action = _random
};


sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) or confess "$self is not an object";

	my $attr = $AUTOLOAD;
	$attr =~ s/.*://;   # strip fully−qualified portion

	confess "FATAL older attribute model"
		if (exists $self->{'_permitted'} || !exists $self->{'_have'});

	confess "FATAL no attribute [$attr] in class [$type]"
		unless (exists $self->{'_have'}->{$attr} && $self->{'_have'}->{$attr});
	if (@_) {
		return $self->{$attr} = shift;
	} else {
		return $self->{$attr};
	}
}

=head2 CLASS METHODS

=over 4

=item OBJ->Alive

Check status of object, i.e returns true if in destruction phase,
and false otherwise.

=cut

sub Alive {
	return 1
		if (${^GLOBAL_PHASE} ne 'DESTRUCT');

	return 0;
}

=item OBJ->Attributes

List the attributes applicable for this class.  Returns the list
of attributes preceded by the class name itself.

=cut

sub Attributes {
	my $self = shift;
	my $class = ref($self);

	my (@have, @hide); for my $attr (sort keys %{ $self->{'_have'} }) {

		if ($self->{'_have'}->{$attr}) {
			push @have, $attr;
		} else {
			push @hide, $attr;
		}
	}
	$self->log->info(sprintf "am [$class] have [%s] hide [%s]",
		join(', ', @have), join(', ', @hide));

	unshift @have, $class;

	return @have;
}


sub DESTROY {
	local($., $@, $!, $^E, $?);
	my $self = shift;

	#printf "DEBUG destroy object id [%s]\n", $self->{'_id'});

	$self->Id('del');
}

=item OBJ->Has(ATTRIBUTE)

Checks if the current object has the specified ATTRIBUTE.
Returns a BOOLEAN.

=cut

sub Has {
	my $self = shift;
	my $attr = shift;
	confess "SYNTAX Has(EXPR)" unless defined($attr);

	return 1 if exists($self->{'_have'}->{$attr});

	return 0;
}

=item OBJ->Id([EXPR])

EXPERIMENTAL Keep track of object identifiers. Returns the current object id.
If EXPR is passed it acts as an operator to "add" an object id (increment)
or "del" (decrement) an object id. Both these operations act on a counter
maintained at class-level.

=cut

sub Id {
	my $self = shift;
	my $op = shift;

	my $id; if (defined $op) {

		if ($op eq 'add') {

			$id = ++${ $self->{'_n_objects'} };

			$self->{'_id'} = $id;

		} elsif ($op eq 'del') {

			--${ $self->{'_n_objects'} };

		} else {
			confess("invalid operator [$op]");
		}
	}
	$id = $self->{'_id'};

	$self->log->trace("id [$id]");

	return $id;
}

=item OBJ->Inherit(OBJECT)

Pass parent genes between offspring, basically sets the attributes in the
current object from another object, based on the inherited attribute list.

=cut

sub Inherit {
	my $self = shift;
	my $sibling = shift;
	confess "FATAL you must specify an object from which to inherit"
		unless (defined($sibling) && ref($sibling) ne "");

#	my $class = ref($self);
	my @attr = @{ $self->{'_inherent'} };

	$self->log->debug(sprintf "attr [%s]", Dumper(\@attr));

	my $count = 0; for my $attr (@attr) {
		my $value = $sibling->$attr;

#		$self->log->debug("setting attr [$attr] to [$value]")

		$self->$attr($value);

		$count++;
	}
	$self->log->info("inherited $count attributes");

	return $count;
}


sub new {
	my ($class) = shift;
	my %args = @_;	# parameters passed via a hash structure

	my $self = {};			# for base-class
	my %attr = ('_have' => { map{$_ => ($_ =~ /^_/) ? 0 : 1 } keys(%_attribute) }, %_attribute);

	bless ($self, $class);

	map { push @{$self->{'_inherent'}}, $_ if ($attr{"_have"}->{$_}) } keys %{ $attr{"_have"} };

	while (my ($attr, $dfl) = each %attr) { 

		unless (exists $self->{$attr} || $attr eq '_have') {
			$self->{$attr} = $dfl;
			$self->{'_have'}->{$attr} = $attr{'_have'}->{$attr};
		}
	}
	$self->Id('add');

	# ---- assign some defaults ----
	my $tpn = Path::Tiny->new($0); $self->dn_start($tpn->cwd);

	while (my ($method, $value) = each %args) {

		confess "SYNTAX new(, ...) value not specified"
			unless (defined $value);

		$self->log->debug("method [self->$method($value)]");

		$self->$method($value);
	}
	# ___ additional class initialisation here ___
	#
	my $cv = ($self->on_windows) ? CMD_OS_VERSION_WIN32 : CMD_OS_VERSION_UX;

	$self->cmd_os_version($cv);

	my $cw = ($self->on_windows) ? "where" : "which";

	$self->cmd_os_where($cw);

	return $self;
}

=back

=head2 OBJECT METHODS

=over 4

=item OBJ->chmod(PERMS, PATH, ...)

Apply the file permissions specificed to the path(s).

=cut

sub chmod {
	my $self = shift;
	my $perms = shift;
	confess "SYNTAX chmod(PERMS, PATH, ...)" unless (@_);

	my @dne;	# a list of paths which do not exist
	my @fail;	# a list of paths for which chmod did not work

	my $count = 0; for my $pn (@_) {

		unless (-e $pn) {
			push @dne, $pn;
			next;
		}

		if (path($pn)->chmod($perms)) {
			$count++;
		} else {
			push @fail, $pn;
		}
	}

	if (@dne) {
		my $pns = join(', ', @dne);

		$self->log->logwarn("pathname(s) do not exist: $pns");
	}

	if (@fail) {
		my $pns = join(', ', @fail);

		$self->log->logwarn("chmod($perms) failed on the following path(s): $pns");
	}

	return $count;
}

=item OBJ->ckdir(DIR)

Checks the existence of the directory specfied by DIR.

=cut

sub ckdir {
	my $self = shift;
	my $dn = shift;
	confess "SYNTAX ckdir(DIR)" unless defined ($dn);

	return 0 if ($self->is_rx($dn));

	return $self->cough("directory [$dn] not accessible");
}

=item OBJ->c2a(EXPR, [BOOLEAN])

Execute the command passed and return output in an array, optionally stripping
blank tokens (if the boolean flagged passed is true).

=cut

sub c2a {	# execute the command passed and return output in an array
	my $self = shift;
	my $cmd = shift;
	my $strip = shift;	# flag to remove empty bits

	$strip = 0 unless (defined $strip);

	$self->log->info("executing [$cmd]")
		if ($self->{'echo'});

	my $output = unidecode(readpipe($cmd));

	$self->log->trace("output [$output]");

	$output =~ s/\x00//g;	# e.g. 00000800  20 20 20 20  20 27 44  0  65  0 66  0  61  0 75  0        'D e f a u 

	my @tokens = split(/[\s\n]+/m, $output);

#	$self->log->trace(sprintf "tokens [%s]", Dumper(\@tokens));

	if (@tokens) {
		$self->log->info(sprintf "command returned %d tokens", scalar(@tokens))
			if ($self->{'echo'});
	} else {
		$self->log->logwarn("WARNING command returned no output");
	}

	my @output; if ($strip) {

		map {
			push @output, $_ if (length($_));
		} @tokens;
	} else {
		@output = @tokens;
	}
	$self->log->trace(sprintf "output [%s]", Dumper(\@output));

	return @output;
}

=item OBJ->cough(EXPR)

The central fatal method which issues a warning or error message.
This is called for many routines in this class and subclass to check if
program termination is warranted, based on the B<fatal> attribute.

=cut

sub cough {
	my $self = shift;
	my $msg = shift;

	$self->log->logconfess("FATAL $msg")
		if ($self->fatal);

	$self->log->logwarn("WARNING $msg");

	return -1;
}

=item OBJ->crlf(EXPR)

Strip CR from the EXPR passed; useful for converting DOS text records.

=cut

sub crlf { #	remove the CR from DOS CRLF (end-of-line string)
	my $self = shift;
	my $str = shift;
	confess "SYNTAX crlf(EXPR)" unless (defined $str);

	my $len1 = length($str);

	$str =~ s/\n*\r//g;

	my $len2 = length($str);

	$self->log->trace("string truncated [$str]") unless ($len1 == $len2);

	return $str;
}

=item OBJ->delete(PATH)

Delete a file or directory.

=cut

sub delete {
	my $self = shift;
	my $pn = shift;
	confess "SYNTAX delete(EXPR)" unless defined ($pn);

	if (-d $pn) {

		return $self->rmdir($pn);

	} elsif (-f $pn) {

		$self->log->info("removing file [$pn]")
			if (Alive() && $self->{'echo'});

		unlink($pn) || $self->cough("unlink($pn) failed");
	}

	return ($self->cough("could not remove file [$pn]"))
		if (-f $pn);

	return 0;
}

=item OBJ->dump(EXPR, ...)

A wrapper for Data::Dumper to flatten the output, which may be a scalar,
structure, or attribute.  If the latter, this will make a self-referencial call.
For scalars, the string is inspected for printf-style arguments and if so
all remaining arguments to this method are passed into it.  Otherwise any
additional parameters to this are assumed to be descriptive and will be
prepended to the resultant string.

=cut

sub dump {
	my $self = shift;
	confess "SYNTAX dump(EXPR)" unless (@_);
	my $thing = shift;
	my $desc = (@_) ? join(' ', @_, "") : "";
	my $pad = ", ";

	my $strip = 1;

	my $nice; if ($self->Has($thing)) {

		no strict 'refs';

		my $value = $self->$thing;

		$self->log->trace("thing [$thing] value [$value]");

		my $dump = Data::Dumper->new($value);

		$dump->Indent(0);
		$dump->Pad($pad);
		$dump->Terse(1);

		my $data = $dump->Dump;
		$data =~ s/,//;

		$nice = sprintf "${desc}attribute $thing [%s]", $data;

	} else {
		my $ref = ref($thing);

		$self->log->trace("thing [$thing] ref [$ref]");

		if ($ref eq '') {
			if ($thing =~ /%/) {	# assume printf mask
				$nice = sprintf $thing, @_;
			} else {
				$nice = sprintf "%sscalar [%s]", $desc, $thing;
			}
		} elsif ($ref eq 'ARRAY') {

			my $dump = Data::Dumper->new($thing);

			$dump->Indent(0);
			$dump->Pad($pad);
			$dump->Terse(1);

			my $data = $dump->Dump;
			$data =~ s/,//;

			$nice = sprintf "%s%s [%s]", $desc, lc($ref), $data;

		} elsif ($ref eq 'HASH') {

			my $dump = Data::Dumper->new([$thing]);

			$dump->Sortkeys(1);
			$dump->Terse(1);

			my $data = $dump->Dump;
			$data =~ s/\n/ /gm;
			$data =~ s/\s+/ /g;

			$nice = sprintf "%s%s $data", $desc, lc($ref);
		} else {
			my $dump = Data::Dumper->new([$thing]);

			$dump->Sortkeys(1);
			$dump->Terse(1);

			my $data = $dump->Dump;
			$data =~ s/\n$//m;
			$data =~ s/^bless/object/;

			$nice = sprintf "%s%s %s", $desc, $ref, $data;

			$strip = 0;
		}
	}
	if ($strip) {
		$nice =~ s/([\[\{])\s+/$1/; # lead space: [ 'foo'   or  { 'bar'
		$nice =~ s/\s+([\]\}])$/$1/; # trail space: 'foo' ] or  'bar' }
	}
#	$self->log->debug($nice);

	return $nice;
}

=item OBJ->godir(DIR)

Checks the existence of the specfied B<DIR> and change to it.

=cut

sub godir {
	my $self = shift;
	my $dn = (@_) ? shift : $self->dn_start;

	$self->is_rx($dn) || return($self->cough("invalid directory [$dn]"));

	chdir($dn) || return($self->cough("chdir($dn) failed"));

	$self->pwd;

	return 0;
}

=item OBJ->extant(PATH, [TYPE])

Checks if the file specified by PATH exists. Subject to fatal processing.
The TYPE parameter defaults to 'd' for directory, but can be overridden to 'f'.

=cut

sub extant {
	my $self = shift;
	my $pn = shift;
	my $type = shift; $type = 'd' unless defined($type);
	confess "SYNTAX extant(EXPR)" unless defined ($pn);

	my $rv; if ($type eq 'd') {

		$rv = (-d $pn);

	} elsif ($type eq 'e') {

		$rv = (-e $pn);

	} elsif ($type eq 'f') {

		$rv = (-f $pn);

	} else {

		$self->cough("invalid type [$type]");
	}
	return 1 if ($rv);

	$self->cough("does not exist [$pn]");

	return 0;	# reverse polarity
}

=item OBJ->is_rwx(PATH, [TYPE])

Check if the filesystem entry PATH is readable, writable and executable.

=cut

sub is_rwx { 
	my $self = shift;
	my $pn = shift;
	my $type = shift;

	return 1
		if ($self->is_rx($pn) && -w $pn);

	return 0;
}

=item OBJ->is_rx(PATH, [TYPE])

Check if the filesystem entry PATH is readable and executable.

=cut

sub is_rx { 
	my $self = shift;
	my $pn = shift;
	my $type = shift;
	confess "SYNTAX is_rx(PATH)" unless (defined $pn);

	return 1
		if ($self->extant($pn, $type) && -r $pn && -x $pn);

	return 0;
}

=item OBJ->is_stdio(FILEHANDLE)

Returns TRUE if the FILEHANDLE passed maps to one of the standard
file descriptors, i.e. 0 = stdin, 1 = stdout, 2 = stderr.
Returns FALSE otherwise.

=cut

sub is_stdio {	# is a standard file descriptor, e.g. 0, 1, 2
	my $self = shift;
	my $fh = shift;
	confess "SYNTAX is_stdio(FILEHANDLE)" unless defined($fh);

	my $fno = fileno($fh);

	return -1 unless defined($fno);	# take a failsafe approach

	$self->log->trace("fileno [$fno]");

	return 0 if ($fno > $self->stdfd);

	return 1;
}

=item OBJ->like_unix

Read-only method advises if the current platform is Unix-like, including Linux.

=cut

sub like_unix {
	my $self = shift;

	return 1
		if ($self->on_linux || $self->on_cygwin);

	# ref. http://alma.ch/perl/perloses.htm

	for (qw/ aix bsdos dec_osf dgux dynix freebsd hpux irix linux macos
		netbsd openbsd sco solaris sunos svr4 ultrix unicos /) {

		my $re_os = qr/$_/i;

		return 1 if ($^O =~ $re_os);
	}
	return 0;
}

=item OBJ->like_windows

Read-only method advises if the current platform is associated with a Windows
or Windows-like OS, incl. WSL or Cygwin.

=cut

sub like_windows {
	my $self = shift;

	return 1
		if ($self->on_windows || $self->on_cygwin);

	return 1
		if ($self->on_wsl);

	return 0;
}

=item OBJ->lov(ACTION, CLASS, ...)

Register, query or set a list of values (LoV) identifiable by CLASS.
Many LoVs can be maintained via this method, which operates globally within
the class.

Actions, addtional parameters and effects are tabled below:

  _clear    (none)	remove the LoV for the specified class if it exists.
  _default  ATTR, VALUE	set attribute to value if not already set.
  _lookup   KEY		lookup the description for the key.
  _lov	    (none)	provide the available keys for this class.
  _random   ATTR	set attribute to a random value.
  _register HASHREF	register a new class of key/value pairs.
  _set	    ATTR, VALUE	set attribute to value.

Return values vary as follows:

  _clear, _register the number of keys in the class (before, or after).
  _default	    the current or revised attribute value.
  _lookup	    the corresponding description for the key.
  _lov		    a sorted array of keys.
  _random, _set	    the revised attribute value.

Note that the _register action if called twice for the same class will
attempt a hash merge to provide the union of the dataset. Redefinition of
the class can be achieved with a prerequisite _clear action.

=cut

sub lov {
	my $self = shift;
	my $action = shift;
	my $class = shift;
	my $s_msg = "SYNTAX lov(ACTION, CLASS%s)";
	confess sprintf($s_msg, "") unless (defined($class) && defined($action));
	$self->log->trace("action [$action] class [$class]");

	my $lov = $self->{'_lov'};
	my @lov;

	my $exists = 0; if (exists $lov->{$class}) {

		$exists = 1;
		@lov = sort keys %{ $lov->{$class} };

		$self->log->trace($self->dump(\@lov, '@lov'));
	}

	# actions which require no further parameters

	if ($action eq '_clear' || $action eq '_lov') {

		if ($action eq '_lov') {

			$self->cough("no such LoV exists [$class]")
				unless($exists);

			return @lov;
		}
		delete $lov->{$class};

		return scalar(@lov);
	}

	# registration needs a class hash (key / values)

	if ($action eq '_register') {

		my $rh = shift; $self->cough("must pass a hashref")
			unless (defined($rh) && ref($rh) eq 'HASH');

		if (exists $lov->{$class}) {

			$self->log->info("merging $class");

			my $ohm = Hash::Merge->new;

			my %c = %{ $ohm->merge($lov->{$class}, $rh) };

			$lov->{$class} = { %c };
		} else {
			$self->log->info("registering $class");

			$lov->{$class} = { %$rh };
		}
		$self->log->trace($self->dump($lov->{$class}));

		return scalar(keys %{ $lov->{$class} });
	}
	
	# query actions needing a key to be specified

	my $missing = sprintf "does not exist in $class LoV %s", $self->dump(\@lov);
	if ($action eq '_lookup') {

		my $key = shift;

		confess(sprintf $s_msg, ", KEY") unless defined($key);

		$self->cough("key [$key] $missing")
			unless exists $lov->{$class}->{$key};

		return $lov->{$class}->{$key};
	}

	# actions needing an attribute to be specified

	my $attr = shift;
	confess(sprintf $s_msg, ", ATTRIBUTE") unless defined($attr);

	$self->cough("class does not have an attribute named [$attr]")
		unless ($self->Has($attr));

	no strict 'refs';

	if ($action eq '_random') {

		my @mix = shuffle(@lov);

		my $value = shift @mix;

		$self->log->info("randomising attribute [$attr] to [$value]");

		return $self->$attr($value);
	}
	
	# actions needing a value to be specified
	my $value = shift;
	confess(sprintf $s_msg, ", ATTRIBUTE, VALUE") unless defined($value);

	$self->cough("value [$value] $missing")
		unless exists $lov->{$class}->{$value};

	if ($action eq '_default') {

		if (defined $self->$attr) {

			$self->log->info("skipping attribute default for [$attr]");
			return $self->$attr;
		}
		$self->log->info("defaulting attribute [$attr] to [$value]");

		return $self->$attr($value);
	}

	if ($action eq '_set') {

		$self->log->info("setting [$attr] to [$value]");

		return $self->$attr($value);
	}
	$self->cough("invalid action [$action]");

	return undef;
}

=item OBJ->mkdir(DIR)

Checks the existence of the specfied B<DIR> and if it does
not exist, then create it.

=cut

sub mkdir {
	my $self = shift;
	my $dn = shift;

	return 0 if (-d $dn);

	my $op = Path::Tiny->new($dn);

	$self->log->info("creating directory [$dn]");

	$op->mkpath($dn) || $self->cough("mkpath($dn) failed");

	return ($self->cough("could not create directory [$dn]"))
		unless (-d $dn);

	return 0;
}

=item OBJ->mkexec(PATH, ...)

Enable all executable bits on the file privileges of the path(s) specified.

=cut

sub mkexec {
	my $self = shift;

	return $self->chmod("a+x", @_);
}

=item OBJ->mkro(PATH, ...

Disable all writable bits on the file permissions of the path(s) specified.

=cut

sub mkro {
	my $self = shift;

	my $perms = "a-w";

	return $self->chmod($perms, @_);
}

=item OBJ->mkwrite(PATH, ...)

Enable user writable bits on the file privileges of the path(s) specified.

=cut

sub mkwrite {
	my $self = shift;

	return $self->chmod("u+w", @_);
}

=item OBJ->on_cygwin

Read-only method advises if the current platform is associated with 
the hybrid B<Cygwin> platform, which has specific handling around storage
which abstracts the B<Windows> drive assignment paradigm.  Used internally
but may be useful outside this module.

=cut

sub on_cygwin {	# read-only method!
	my $self = shift;

	return 1	# flag for the cygwin hybrid platform
		if ($^O =~ /cygwin/i);

	return 0;
}

=item OBJ->on_linux

Read-only method advises if the current platform is Linux.

=cut

sub on_linux {	# read-only method!
	my $self = shift;
	
	return 1	# flag for the Linux platforms
		if ($^O =~ /linux/i);

	return 0;
}

=item OBJ->on_windows

Read-only method advises if the current platform is MS Windows. 

=cut

sub on_windows {	# read-only method!
	my $self = shift;

	return 1	# flag for the windows platform
		if ($^O =~ /mswin/i);

	return 0;
}

=item OBJ->on_wsl

Read-only method advises if the current platform is WSL.

=cut

sub on_wsl {	# read-only method!
	my $self = shift;

	return 0	# need to check if actually on WSL
		unless ($self->on_linux);

	return 1 if ($self->wsl_env);

	my $pn; if (-f $self->pn_release) {

		$pn = $self->pn_release;

	} elsif (-f $self->pn_version) {

		$pn = $self->pn_version;
	} else {
		$self->cough("unable to determine platform [$^O]");
	}

	open(my $fh, "<$pn") || $self->cough("open($pn) failed");

	my $f_wsl = 0; while (<$fh>) {

		$f_wsl = 1
			if ($_ =~ /microsoft/i);
	}
	close($fh);

	$self->log->trace("pn [$pn] f_wsl [$f_wsl]");

	return $f_wsl;	# flag for the WLS hybrid platform
}

=item OBJ->os_version

Attempt to ascertain the operating system version.  This may involve polling
the unix release file.  This routine is non-fatal. Returns an array of tokens
containing an OS-specific list of version tokens.  WSL-friendly.

=cut

sub os_version {
	my $self = shift;

	my $cmd; if ($self->on_wsl) {

		$cmd = "cat " . $self->pn_issue;

	} else {

		$cmd = $self->cmd_os_version;
	}

	my @lines;

	if ($self->wsl_env) {

		$self->log->info("retrieving WSL distro from environment");

		push @lines, $self->wsl_env;
	} else {

		$self->log->info("retrieving WSL distro from filesystem");

		@lines = $self->c2a($cmd, 1);
	}

	push @lines, ""
		unless (@lines);

	shift @lines if ($self->on_windows);

	$self->log->trace(sprintf "lines [%s]", Dumper(\@lines));

	return @lines;
}

=item OBJ->powershell([PATHNAME])

Return a shell-exit command string to launch the MS Powershell command
interpreter, optionally passing a pathname for the script file.

=cut

sub powershell {
	my $self = shift;

	my $cmd = ($self->like_windows) ? "powershell.exe" : "pwsh";

	my $parms; if (@_) {

		$parms = ($self->like_windows) ? "-ExecutionPolicy ByPass" : "";

		$parms .= "-File " . shift;

	} else {
		$parms = "-Command";
	}
	$cmd .= " $parms";

	$self->log->debug("cmd [$cmd]");

	return $cmd;
}

=item OBJ->pwd

Coughs current directory (done implicitly by the B<godir> method).

=cut

sub pwd {
	my $self = shift;
	
	my $pwd = Path::Tiny->cwd;

	$self->log->info("now in directory [$pwd]");

	return $pwd;
}

=item OBJ->rmdir(DIR)

Checks the existence of the specfied F<DIR> and if it does
not exist, then create it.

=cut

sub rmdir {
	my $self = shift;
	my $dn = shift;
	confess "SYNTAX rmdir(DIR)" unless defined ($dn);

	return( $self->cough("directory does not exist [$dn]"))
		unless (-d $dn);

	$self->log->info("pruning directory [$dn]")
		if (Alive() && $self->{'echo'});

	path($dn)->remove_tree({ safe => 0})
		|| $self->cough("remove_tree($dn) failed");

	return ($self->cough("could not prune directory [$dn]"))
		if (-d $dn);

	return 0;
}

=item OBJ->trim(EXPR, REGEXP)

Trim the specified regexp from start and end of passed string.

=cut

sub trim {
	my $self = shift;
	my $str = shift;
	my $re = shift;
	confess "SYNTAX trim(EXPR, REGEXP)" unless (defined $re && defined $str);
	$self->log->trace("BEF str [$str] re [$re]");

	$str =~ s/^$re//;	# prune leading regexp
	$str =~ s/$re$//;	# prune trailing regexp

	$self->log->trace("AFT str [$str]");

	return $str;
}

=item OBJ->trim_ws(EXPR)

Trim trailing and leading whitespace in string passed.

=cut

sub trim_ws {
	my $self = shift;
	my $str = shift;
	confess "SYNTAX trim_ws(EXPR)" unless (defined $str);

	return $self->trim($str, $self->re_whitespace);
}

=item OBJ->where(EXPR)

Try to find the executable identified by EXPR in the shell execution path

=cut

sub where {
	my $self = shift;
	my $exec = shift;
	confess "SYNTAX where(EXPR)" unless (defined $exec);

	my $cmd = join(' ', $self->cmd_os_where, $exec);

	return $self->c2a($cmd, 1);
}

=item OBJ->whoami

Returns the name of the current user, and returns it.  On Windows platforms
this will just make a call to the B<winuser> method, otherwise a PERL-native
method is used.

=cut

sub whoami {
	my $self = shift;

	my $whoami; if ($self->on_windows) {

		$whoami = $self->winuser;
	} else {
		$whoami = getpwuid($<);
	}
	$self->log->debug("whoami [$whoami]");

	return $whoami;
}

=item OBJ->winuser

Returns the name of the current Windows user (Windows-like platforms only).
This makes a call to Powershell.
If that is not possible or returns no value then returns undef.
See also B<whoami>.

=cut

sub winuser {
	my $self = shift;

	$self->echo(1);	# debugging
	my $cmd; if ($self->like_windows) {

		$cmd = $self->powershell . '$env:UserName';
	}
	if (defined $cmd) {
		my @result = $self->c2a($cmd);

		$self->log->logwarn("[$cmd] produced no result")
			unless (scalar @result);

		$self->log->debug(sprintf "result [%s]", Dumper(\@result));

		return $result[0] if (@result);
	}

	return undef;
}

=item OBJ->wsl_dist

Attempt to determine the WSL distribution (if appropriate).  Windows and WSL
friendly, but will return undef on other platforms.  Non-fatal.

=cut

sub wsl_dist {
	my $self = shift;

	unless ($self->like_windows) {

		$self->log->logwarn("WSL not applicable to this platform");

		return undef;
	}

	if ($self->on_wsl) {	# internal to WSL it cannot access "wsl" cmd

		my @dist = $self->os_version;

		$self->wsl_active(1);

		return $dist[0]
			unless ($dist[0] eq "");
	}
# ---- WSL version 2 ----
# wsl --status
# Default Distribution: Ubuntu
# Default Version: 2

	my @wls = $self->c2a("wsl --status", 1);

	if (@wls) {

		if ($wls[0] eq 'Default' && $wls[1] eq 'Distribution:') {

			my $dist = $wls[2];

			$self->log->info(sprintf "WSL distro is [%s]", $dist)
				if ($self->{'echo'});

			$self->wsl_active(1);

			return $dist;
# WSL2 with no distro installed
# wsl --status
#
# Copyright (c) Microsoft Corporation. All rights reserved.
# 
# Usage: wsl.exe [Argument]
# 
# Arguments:
		} elsif ($wls[0] eq 'Copyright' && $wls[7] eq 'Usage:') {

			$self->log->info("WSL available but no distribution")
				if ($self->{'echo'});


		} elsif ($wls[1] eq 'Invalid' && $wls[6] eq 'Invalid') {
# ---- WSL version 1 ----
# wsl --status
#
# Invalid command line option: --status
#
# Usage: wsl.exe [option] ...
			$self->log->info("trying alternative WSL method")
				if ($self->{'echo'});

			@wls = $self->c2a("wslconfig /l", 1);
# wslconfig /l
# 
# Windows Subsystem for Linux Distributions:
# 
# Ubuntu-20.04 (Default)

			if (@wls && $wls[2] eq 'Subsystem' && $wls[6] eq '(Default)') {

				$self->wsl_active(1);
	
				return $wls[5];
			}
		}
	}
	$self->log->info("WSL distribution unable to be determined")
		if ($self->{'echo'});

	return undef;
}

1;

__END__

=back

=head1 VERSION

_IDE_REVISION_

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation; either version 3 of the License,
or any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 SEE ALSO

L<perl>, L<Carp>, L<Data::Dumper>, L<Log::Log4perl>,
L<Hash::Merge>,
L<List::Util>,
L<Path::Tiny>,
L<Text::Unidecode>.

=cut

