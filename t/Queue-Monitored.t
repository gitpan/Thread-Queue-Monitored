BEGIN {				# Magic Perl CORE pragma
    if ($ENV{PERL_CORE}) {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
}

use strict;
use Test::More tests => 5;

BEGIN { use_ok('threads') }
BEGIN { use_ok('Thread::Queue::Monitored') }

my @list : shared;

my ($q,$t) = Thread::Queue::Monitored->new( \&monitor );
isa_ok( $q, 'Thread::Queue::Monitored', 'check object type' );

my $times = 1000;
$q->enqueue( $_ ) foreach 1..$times;
my $pending = $q->pending;
ok( $pending >= 0 and $pending <= $times, 'check number of values on queue' );

$q->enqueue( undef ); # stop monitoring
$t->join;

my $check = '';
$check .= $_ foreach 1..$times;
is( join('',@list), $check,		'check whether monitoring ok' );

sub monitor { push( @list,$_[0] ) }
