package Thread::Queue::Monitored;

# Make sure we inherit from threads::shared::queue
# Make sure we have version info for this module
# Make sure we do everything by the book from now on

@ISA = qw(Thread::Queue);
$VERSION = '0.02';
use strict;

# Make sure we have queues

use Thread::Queue (); # no need to pollute namespace

# Satisfy -require-

1;

#---------------------------------------------------------------------------
#  IN: 1 class to bless with
#      2 reference/name of subroutine doing the monitoring
#      3 value to consider end of monitoring action (default: undef)
# OUT: 1 instantiated object
#      2 (optional) thread object of monitoring thread

sub new {

# Obtain the parameters

    my ($class,$code,$exit) = @_;
    die "Must specify a subroutine to monitor the queue" unless $code;

# We we don't have a code reference yet
#  Make the name fully qualified
#  Make sure it's a code ref

    unless (ref($code)) {
        $code = caller().'::'.$code unless $code =~ m#::#;
        $code = \&{$code};
    }

# Obtain a standard queue object
# Allow for the automatic monitor routine selection
# Create a thread monitoring the queue
# Return the queue objects or both objects

    my $self = $class->SUPER::new;
    no strict 'refs';
    my $thread =
     threads->new( \&{$class.'::_monitor'},$self,wantarray,$code,$exit );
    return wantarray ? ($self,$thread) : $self;
} #new

#---------------------------------------------------------------------------
#  IN: 1 instantiated object (ignored)
# OUT: 1 dequeued value (not returned)

sub dequeue { die "You cannot dequeue on a monitored queue" }

#---------------------------------------------------------------------------
#  IN: 1 instantiated object (ignored)
# OUT: 1 dequeued value (not returned)

sub dequeue_nb { die "You cannot dequeue_nb on a monitored queue" }

#---------------------------------------------------------------------------

# Internal subroutines

#---------------------------------------------------------------------------
#  IN: 1 queue object to monitor
#      2 flag: to keep thread attached
#      3 code reference of monitoring routine
#      4 exit value

sub _monitor {

# Obtain the queue and the code reference to work with
# Make sure this thread disappears outside if we don't want to keep it

    my ($queue,$keep,$code,$exit) = @_;
    threads->self->detach unless $keep;

# Initialize the list with values to process
# While we're processing
#  Wait until we can get a lock on the queue
#  Wait until something happens on the queu
#  Obtain all values from the queue
#  Reset the queue

    my @value;
    while( 1 ) {
        {
         lock( @{$queue} );
         threads::shared::cond_wait @{$queue} until @{$queue};
         @value = @{$queue};
         @{$queue} = ();
        }

#  For all of the values just obtained
#   Return now if so indicated
#   Call the monitoring routine
	
        foreach (@value) {
	    return if $_ eq $exit;
            $code->( $_ );
        }
    }
} #_monitor

#---------------------------------------------------------------------------

__END__

=head1 NAME

Thread::Queue::Monitored - monitor a queue for specific content

=head1 SYNOPSIS

    use Thread::Queue::Monitored;
    my $q = Thread::Queue::Monitored->new( \&monitor );
    my ($q,$t) = Thread::Queue::Monitored->new( \&monitor,'exit' );
    $q->enqueue( "foo" );
    $q->enqueue( undef ); # exit value by default

    $t->join; # wait for monitor thread to end

    sub monitor {
      warn $_[0] if $_[0] =~ m/something wrong/;
    }

=head1 DESCRIPTION

                    *** A note of CAUTION ***

 This module only functions on Perl versions 5.8.0-RC3 and later.
 And then only when threads are enabled with -Dusethreads.  It is
 of no use with any version of Perl before 5.8.0-RC3 or without
 threads enabled.

                    *************************

A queue, as implemented by C<Thread::Queue::Monitored> is a thread-safe 
data structure that inherits from C<Thread::Queue>.  But unlike the
standard C<Thread::Queue>, it starts a single thread that monitors the
contents of the queue by taking new values off the queue as they become
available.

It can be used for simply logging actions that are placed on the queue. Or
only output warnings if a certain value is encountered.  Or whatever.

The action performed in the thread, is determined by a name or reference
to a subroutine.  This subroutine is called for every value obtained from
the queue.

Any number of threads can safely add elements to the end of the list.

=head1 CLASS METHODS

=head2 new

 $queue = Thread::Queue::Monitored->new( \&monitor );
 $queue = Thread::Queue::Monitored->new( \&monitor,'exit' );
 ($queue,$thread) = Thread::Queue::Monitored->new( \&monitor );
 ($queue,$thread) = Thread::Queue::Monitored->new( \&monitor,'exit' );

The C<new> function creates a new empty queue.  It returns the instantiated
Thread::Queue::Monitored object in scalar context: in that case, the monitoring
thread will be detached and will continue until the exit value is passed on
to the queue.  In list context, the thread object is also returned, which can
be used to wait for the thread to be really finished using the C<join()>
method.

The first input parameter is a name or reference to a subroutine that will
be called to check on each value that is added to the queue.  It B<must> be
specified.  The subroutine is to expect one parameter: the value to check.
It is free to do with that value what it wants.

The second (optional) input parameter is the value that will signal that the
monitoring of the thread should seize.  If it is not specified, the C<undef>
value is assumed.  To end monitoring the thread, L<enqueue> the same value.

=head1 OBJECT METHODS

=head2 enqueue

 $queue->enqueue( $value1,$value2 );
 $queue->enqueue( 'exit' ); # stop monitoring

The C<enqueue> method adds all specified parameters on to the end of the
queue.  The queue will grow as needed to accommodate the list.  If the
"exit" value is passed, then the monitoring thread will shut itself down.

=head1 CAVEATS

You cannot remove any values from the queue, as that is done by the monitoring
thread.  Therefore, the methods "dequeue" and "dequeue_nb" are disabled on
this object.

=head1 AUTHOR

Elizabeth Mattijsen, <liz@dijkmat.nl>.

Please report bugs to <perlbugs@dijkmat.nl>.

=head1 COPYRIGHT

Copyright (c) 2002 Elizabeth Mattijsen <liz@dijkmat.nl>. All rights
reserved.  This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<threads>, L<threads::shared>, L<Thread::Queue>.

=cut
