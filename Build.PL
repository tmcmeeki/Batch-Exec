# EXPERIMENTAL for cpan
# ref. https://metacpan.org/pod/Module::Build
# can call like this:
# perl Build.PL --install_base=~
# ./Build
# ./Build test
# ./Build install
# ./Build distmeta
# ./Build disttest
# ./Build dist

use Module::Build;
#use Module::Build::Compat;
#use Data::Dumper;

my $revision = sprintf "%d.%03d", q[$Revision: 1.1 $] =~ /(\d+)/g;

my $build = new Module::Build (
#	all_from => 'lib\Batch\Exec.pm',
	all_from => 'lib/Batch/Exec.pm',
	configure_requires => { 'Module::Build' => 0.42 },
#	create_makefile_pl => 'small',
#	create_makefile_pl => 'traditional',
	create_license => 1,
#	abstract_from => 'lib\Batch\Exec.pm',
	abstract_from => 'lib/Batch/Exec.pm',
#	dist_abstract => '___change_me___',
#	author_from => 'lib\Batch\Exec.pm',
#	dist_author => 'TMCMEEKI <tmcmeeki@cpan.org>',
#	dist_version_from => 'IDE_VERSION',
	dist_version => $revision,
	install_path => {
		'txt' => 'tmp',
	},
	license => 'perl',
	module_name => 'Batch::Exec',
	requires => {
		'Carp' => 0,
		'Data::Dumper' => 0,
		'Hash::Merge' => 0,
		'List::Util' => 0,
#		'Log::Log4perl' => 0,
		'Logfer' => 0,
		'Path::Tiny' => 0,
		'Text::Unidecode' => 0,
	},
#	sign => 1,
	txt_files => {
		'Batch-Exec_audit.txt' => 'tmp/dummy.txt'
	},
	requires_external_bin => 'pxwsh',
#	run_build_pl => \@tx,
#	write_makefile => undef,
);
$build->add_build_element('txt');
#$build->create_license;

#Module::Build::Compat->create_makefile_pl('small');
#Module::Build::Compat->run_build_pl(args => \@ARGV);
#Module::Build::Compat->write_makefile();

my $action = $build->current_action;

if ($action eq 'install') {
	$build->do_system(qw/ echo sudo apt-get install powershell /);
} else {
	print "skipping action [$action]\n";
}

$build->create_build_script;

