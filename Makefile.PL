require 5.008;
use threads (); # just to force breakage if threads are not available
use ExtUtils::MakeMaker;

WriteMakefile (
 NAME		=> "Thread::Queue::Monitored",
 ($[ >= 5.005) ?
 (AUTHOR	=> 'Elizabeth Mattijsen (liz@dijkmat.nl)',
  ABSTRACT	=> 'monitor a queue for specific content') : (),
 VERSION_FROM	=> 'lib/Thread/Queue/Monitored.pm',
 PREREQ_PM	=> {
                    'Thread::Queue' => 0,
                   },
);
