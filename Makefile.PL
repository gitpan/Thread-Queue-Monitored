require 5.008;

# do we have threads or forks??
my $module;
BEGIN {
    $module=  "Thread::Queue::Monitored";

    require Config;
    Config->import;

    if ( !$Config{useithreads} ) {

        eval { require forks };
        if ($@) {
            print <<"TEXT";
$module requires a version of perl that has threads enabled or
which has the forks.pm module installed.
TEXT
            exit 0;
        }
    }
} #BEGIN

# set up stuff
use ExtUtils::MakeMaker;
use File::Copy qw( mv );

# set version and dependency info
eval "use Devel::Required";

# initializations
my $lib_tree=   'Thread/Queue';
my @postfix=    qw( blead maint );
my $required=   '5.014';
my $auto_maint= ( $] < $required ) || 0;
my $maint=      $ENV{AUTO_SELECT_MAINT_OR_BLEAD} ? $auto_maint : 0;

# do we have an override?
if (@ARGV) {
    my ($type)= @ARGV;
    if ( $type eq 'maint' ) {
        $maint= 1;
    }

    elsif ( $type eq 'blead' ) {
        $maint= 0;
    }

    else {
        die "Don't understand '$type' to force version to test / install";
    }

    print STDERR "Forcing to use the '$type' version of the code\n";
}

# sorry, we can't help you
if ( $auto_maint and !$maint ) {
    print STDERR <<"SORRY";

This distribution requires at least Perl $required to be installed.  Since this
is an older distribution, with a history spanning almost a decade, it is also
available inside this distribution as a previous incarnation, which is actively
maintained as well.

You can install that version of this distribution by running this $0
with the additional "maint" parameter, like so:

 $^X $0 maint

Or you can provide an automatic selection behavior, which would automatically
select and install the right version of this distribution for the version of
Perl provided, by setting the AUTO_SELECT_MAINT_OR_BLEAD environment variable
to a true value.  On Unix-like systems like so:

 AUTO_SELECT_MAINT_OR_BLEAD=1 $^X $0

Thank you for your attention.

SORRY

    my $line= __LINE__ + 3;
    eval <<"CODE" or die $@;
#line $line $0
require $required;
CODE
}

# create shortcuts
my $this= $postfix[$maint];
my $that= $postfix[ !$maint ];

# make sure empty directories exist, 'make dist' doesn't include them
mkdir 'lib_blead';
mkdir 'lib_blead/Thread';
mkdir 'lib_blead/Thread/Queue';
mkdir 't_blead';

# need to move files into place
if ( my @files= glob( "lib_$this/$lib_tree/*" ) ) {
    print STDERR "Moving $this files into position\n";

    # move current files away
    mv "MANIFEST", "MANIFEST_$that";
    mv "lib/$lib_tree/$_", "lib_$that/$lib_tree/${_}_$that"
      foreach
        map { m#/([^/\.]+\.pm)$# }
        glob( "lib/$lib_tree/*" );
    mv "t/$_", "t_$that/${_}_$that"
      foreach
        map { m#/([^/\.]+\.t)$# }
        glob( "t/*" );

    # put files into place
    mv "MANIFEST_$this", "MANIFEST";
    mv "lib_$this/$lib_tree/${_}_$this", "lib/$lib_tree/$_"
      foreach
        map { m#/([^/\.]+\.pm)_$this$# }
        @files;
    mv "t_$this/${_}_$this", "t/$_"
      foreach
        map { m#/([^/]+\.t)_$this$# }
        glob( "t_$this/*" );

    # make sure we will copy to blib
    unlink "pm_to_blib";
}

# right files already there
else {
    print STDERR "Files for $this already in position\n";
}

# set up prerequisites
my @prereq_pm= (
  'Thread::Queue' => 0,
);
push @prereq_pm, (
  'Test::More'    => 0.88,
) if !$maint;

# set up
WriteMakefile (
 NAME         => $module,
 AUTHOR       => 'Elizabeth Mattijsen (liz@dijkmat.nl)',
 ABSTRACT     => 'monitor a queue for specific content',
 VERSION_FROM => 'lib/Thread/Queue/Monitored.pm',
 LICENSE      => 'perl',
 PREREQ_PM    => { @prereq_pm },
);

