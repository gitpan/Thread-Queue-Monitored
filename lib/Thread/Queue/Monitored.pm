package Thread::Queue::Monitored;

# Make sure we inherit from Thread::Queue
# Make sure we have version info for this module
# Make sure we do everything by the book from now on

our @ISA : unique = qw(Thread::Queue);
our $VERSION : unique = '0.06';
use strict;

# Make sure we have queues

use Thread::Queue (); # no need to pollute namespace

# Allow for self referencing within monitoring thread

my $SELF;

# Satisfy -require-

1;

#---------------------------------------------------------------------------
#  IN: 1 class to bless with
#      2 reference/name of subroutine doing the monitoring
#      3 value to consider end of monitoring action (default: undef)
# OUT: 1 instantiated object
#      2 (optional) thread object of monitoring thread

sub new {

# Obtain the class
# Obtain the parameter hash reference
# Obtain local copy of code to execute
# Die now if nothing specified

    my $class = shift;
    my $param = shift;
    my $monitor = $param->{'monitor'};
    die "Must specify a subroutine to monitor the queue" unless $monitor;

# Create the namespace
# If we don't have a code reference yet, make it one

    my $namespace = caller().'::';
    $monitor = _makecoderef( $namespace,$monitor ) unless ref($monitor);

# Obtain local copy of the pre subroutine reference
# If we have one but it isn't a code reference yet, make it one
# Obtain local copy of the post subroutine reference
# If we have one but it isn't a code reference yet, make it one

    my $pre = $param->{'pre'};
    $pre = _makecoderef( $namespace,$pre ) if $pre and !ref($pre);
    my $post = $param->{'post'};
    $post = _makecoderef( $namespace,$post ) if $post and !ref($post);

# Obtain a standard queue object, either reblessed from the hash or new

    my $self = $param->{'queue'} ?
     bless $param->{'queue'},$class : $class->SUPER::new;

# Allow for the automatic monitor routine selection
# Create a thread monitoring the queue
# Return the queue objects or both objects

    no strict 'refs';
    my $thread = threads->new(
     \&{$class.'::_monitor'},
     $self,
     wantarray,
     $monitor,
     $param->{'exit'},	# don't care if not available: then undef = exit value
     $post,
     $pre,
     @_
    );
    return wantarray ? ($self,$thread) : $self;
} #new

#---------------------------------------------------------------------------
#  IN: 1 class (ignored)
# OUT: 1 instantiated queue object

sub self { $SELF } #self

#---------------------------------------------------------------------------
#  IN: 1 instantiated object (ignored)
# OUT: 1 dequeued value (not returned)

sub dequeue { _die() }

#---------------------------------------------------------------------------
#  IN: 1 instantiated object (ignored)
# OUT: 1 dequeued value (not returned)

sub dequeue_dontwait { _die() }

#---------------------------------------------------------------------------
#  IN: 1 instantiated object (ignored)
# OUT: 1 dequeued value (not returned)

sub dequeue_nb { _die() }

#---------------------------------------------------------------------------
#  IN: 1 instantiated object (ignored)
# OUT: 1 dequeued value (not returned)

sub dequeue_keep { _die() }

#---------------------------------------------------------------------------

# Internal subroutines

#---------------------------------------------------------------------------
#  IN: 1 instantiated object (ignored)

sub _die {

# Obtain the name of the caller
# Die with the name of the caller

    (my $caller = (caller(1))[3]) =~ s#^.*::##;
    die "You cannot '$caller' on a monitored queue";
} #_die

#---------------------------------------------------------------------------
#  IN: 1 namespace prefix
#      2 subroutine name
# OUT: 1 code reference

sub _makecoderef {

# Obtain namespace and subroutine name
# Prefix namespace if not fully qualified
# Return the code reference

    my ($namespace,$code) = @_;
    $code = $namespace.$code unless $code =~ m#::#;
    \&{$code};
} #_makecoderef

#---------------------------------------------------------------------------
#  IN: 1 queue object to monitor
#      2 flag: to keep thread attached
#      3 code reference of monitoring routine
#      4 exit value
#      5 code reference of preparing routine (if available)
#      6..N parameters passed to creation routine

sub _monitor {

# Obtain the queue object
# Make sure this thread disappears outside if we don't want to keep it
# Obtain the monitor code reference
# Obtain the exit value

    my $queue = $SELF = shift;
    threads->self->detach unless shift;
    my $monitor = shift;
    my $exit = shift;

# Obtain the post subroutine reference or create an empty one
# Obtain the preparation subroutine reference
# Execute the preparation routine if there is one

    my $post = shift || sub {};
    my $pre = shift;
    $pre->( @_ ) if $pre;

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
#   If there is a defined exit value
#    Return now with result of post() if so indicated
#   Elsif found value is not defined (so same as exit value)
#    Return now with result of post()
#   Call the monitoring routine
	
        foreach (@value) {
            if (defined( $exit )) {
                return $post->( @_ ) if $_ eq $exit;
            } elsif(!defined( $_ )) {
                return $post->( @_ );
            }
            $monitor->( $_ );
        }
    }
} #_monitor

#---------------------------------------------------------------------------

__END__

=head1 NAME

Thread::Queue::Monitored - monitor a queue for specific content

=head1 SYNOPSIS

    use Thread::Queue::Monitored;
    my ($q,$t) = Thread::Queue::Monitored->new(
     {
      monitor => sub { print "monitoring value $_[0]\n" }, # is a must
      pre => sub { print "prepare monitoring\n" },         # optional
      post => sub { print "stop monitoring\n" },           # optional
      queue => $queue, # use existing queue, create new if not specified
      exit => 'exit',  # default to undef
     }
    );

    $q->enqueue( "foo" );
    $q->enqueue( undef ); # exit value by default

    @post = $t->join; # optional, wait for monitor thread to end

    $queue = Thread::Queue::Monitored->self; # "pre", "do", "post" only

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

 ($queue,$thread) = Thread::Queue::Monitored->new(
  {
   pre => \&pre,
   monitor => 'monitor',
   post => 'module::done',
   queue => $queue, # use existing queue, create new if not specified
   exit => 'exit',  # default to undef
  }
 );


The C<new> function creates a monitoring function on an existing or on an new
(empty) queue.  It returns the instantiated Thread::Queue::Monitored object
in scalar context: in that case, the monitoring thread will be detached and
will continue until the exit value is passed on to the queue.  In list
context, the thread object is also returned, which can be used to wait for
the thread to be really finished using the C<join()> method.

The first input parameter is a reference to a hash that should at least
contain the "monitor" key with a subroutine reference.

The other input parameters are optional.  If specified, they are passed to the
the "pre" routine which is executed once when the monitoring is started.

The following field B<must> be specified in the hash reference:

=over 2

=item do

 monitor => 'monitor_the_queue',	# assume caller's namespace

or:

 monitor => 'Package::monitor_the_queue',

or:

 monitor => \&SomeOther::monitor_the_queue,

or:

 monitor => sub {print "anonymous sub monitoring the queue\n"},

The "monitor" field specifies the subroutine to be executed for each value
that is removed from the queue.  It must be specified as either the name of
a subroutine or as a reference to a (anonymous) subroutine.

The specified subroutine should expect the following parameter to be passed:

 1  value obtain from the queue

What the subroutine does with the value, is entirely up to the developer.

=back

The following fields are B<optional> in the hash reference:

=over 2

=item pre

 pre => 'prepare_monitoring',		# assume caller's namespace

or:

 pre => 'Package::prepare_monitoring',

or:

 pre => \&SomeOther::prepare_monitoring,

or:

 pre => sub {print "anonymous sub preparing the monitoring\n"},

The "pre" field specifies the subroutine to be executed once when the
monitoring of the queue is started.  It must be specified as either the
name of a subroutine or as a reference to a (anonymous) subroutine.

The specified subroutine should expect the following parameters to be passed:

 1..N  any parameters that were passed with the call to L<new>.

=item post

 post => 'stop_monitoring',		# assume caller's namespace

or:

 post => 'Package::stop_monitoring',

or:

 post => \&SomeOther::stop_monitoring,

or:

 post => sub {print "anonymous sub when stopping the monitoring\n"},

The "post" field specifies the subroutine to be executed once when the
monitoring of the queue is stopped.  It must be specified as either the
name of a subroutine or as a reference to a (anonymous) subroutine.

The specified subroutine should expect the following parameters to be passed:

 1..N  any parameters that were passed with the call to L<new>.

Any values returned by the "post" routine, can be obtained with the C<join>
method on the thread object.

=item queue

 queue => $queue,  # create new one if not specified

The "queue" field specifies the Thread::Queue object that should be monitored.
A new L<Thread::Queue> object will be created if it is not specified.

=item exit

 exit => 'exit',   # default to undef

The "exit" field specifies the value that will cause the monitoring thread
to seize monitoring.  The "undef" value will be assumed if it is not specified.
This value should be L<enqueue>d to have the monitoring thread stop.

=back

=head2 self

 $queue = Thread::Queue::Monitored->self; # only "pre", "do" and "post"

The class method "self" returns the object for which this thread is
monitoring.  It is available within the "pre", "do" and "post" subroutine
only.

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
