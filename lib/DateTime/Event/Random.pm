
package DateTime::Event::Random;

use strict;
use DateTime::Set;
use vars qw( $VERSION @ISA );
use Carp;

BEGIN {
    $VERSION = 0.01_03;
}

sub new_cached {
    my $class = shift;
    my %args = @_;   # the parameters are validated by DT::Set

    my $density = 24*60*60;  # default = 1 day
    $density = ( delete $args{nanoseconds} ) / 1E9 if exists $args{nanoseconds}; 
    $density = ( delete $args{seconds} ) if exists $args{seconds};
    $density = ( delete $args{minutes} ) * 60 if exists $args{minutes};
    $density = ( delete $args{hours} ) * 60*60 if exists $args{hours};
    $density = ( delete $args{days} ) * 24*60*60 if exists $args{days};
    $density = ( delete $args{weeks} ) * 7*24*60*60 if exists $args{weeks};
    $density = ( delete $args{months} ) * 365.24/12*24*60*60 if exists $args{months};
    $density = ( delete $args{years} ) * 365.24*24*60*60 if exists $args{years};

    my $set = DateTime::Set->empty_set;

    my $get_cached = 
                sub {
                    my $dt = $_[0];
                    my $prev = $set->previous( $dt );
                    my $next = $set->next( $dt );
                    return ( $prev, $next ) if defined $prev && defined $next;
                    my $last = $set->iterator->next;
                    my ( $sec, $nano );
                    do {
                        ( $sec, $nano ) = _log( $density );
                        if ( defined $last )
                        {
                            $last = $last->clone->subtract( seconds => $sec, nanoseconds => $nano );
                        }
                        else
                        {
                            $last = $dt->clone->subtract( seconds => $sec, nanoseconds => $nano );
                        }
                        $set = $set->union( $last );
                    } while $last >= $dt;

                    $last = $set->iterator->previous;
                    do {
                        ( $sec, $nano ) = _log( $density );
                        if ( defined $last )
                        {
                            $last = $last->clone->add( seconds => $sec, nanoseconds => $nano );
                        }
                        else
                        {
                            $last = $dt->clone->add( seconds => $sec, nanoseconds => $nano );
                        }

                        $set = $set->union( $last );
                    } while $last <= $dt;

                    $prev = $set->previous( $dt );
                    $next = $set->next( $dt );

                    return ( $prev, $next );
                };

    my $cached_set = DateTime::Set->from_recurrence(
        next => sub {
                    my ( undef, $next ) = &$get_cached( $_[0] );
                    return $next;
                 },
        previous => sub {
                    my ( $previous, undef ) = &$get_cached( $_[0] );
                    return $previous;
                 },
        %args,
    );
    return $cached_set;

}

sub new {
    my $class = shift;
    my %args = @_;   # the parameters are validated by DT::Set

    my $density = 24*60*60;  # default = 1 day
    $density = ( delete $args{nanoseconds} ) / 1E9 if exists $args{nanoseconds}; 
    $density = ( delete $args{seconds} ) if exists $args{seconds};
    $density = ( delete $args{minutes} ) * 60 if exists $args{minutes};
    $density = ( delete $args{hours} ) * 60*60 if exists $args{hours};
    $density = ( delete $args{days} ) * 24*60*60 if exists $args{days};
    $density = ( delete $args{weeks} ) * 7*24*60*60 if exists $args{weeks};
    $density = ( delete $args{months} ) * 365.24/12*24*60*60 if exists $args{months};
    $density = ( delete $args{years} ) * 365.24*24*60*60 if exists $args{years};

    my $set = DateTime::Set->from_recurrence(
        next => sub {
                    my ( $sec, $nano ) = _log( $density );
                    return $_[0]->add(
                        seconds => $sec,
                        nanoseconds => $nano,
                    );
                 },
        previous => sub {
                    my ( $sec, $nano ) = _log( $density );
                    return $_[0]->subtract(
                        seconds => $sec,
                        nanoseconds => $nano,
                    );
                 },
        %args,
    );
    return $set;
}

sub _log {
    # this is a density function that approximates to 
    # the "duration" in seconds between two random dates.
    # $_[0] is the target average duration, in seconds.
    my $tmp = log( 1 - rand ) * ( - $_[0] );
    # the result is split into "seconds" and "nanoseconds"
    return ( int( $tmp ), int( 1E9 * ( $tmp - int( $tmp ) ) ) ); 
}

sub datetime {
    my $class = shift;
    carp "Missing class name in call to ".__PACKAGE__."->datetime()"
        unless defined $class;
    my %args = @_;
    my %span_args;
    my $span;
    if ( exists $args{span} )
    {
        $span = delete $args{span};
    }
    else
    {
        for ( qw( start end before after ) )
        {
            $span_args{ $_ } = delete $args{ $_ } if exists $args{ $_ };
        }
        $span = DateTime::Span->from_datetimes( %span_args )
            if ( keys %span_args );
    } 

    if ( ! defined $span ||
         ( $span->start->is_infinite && 
           $span->end->is_infinite ) )
    {
        my $dt = DateTime->now( %args );
        $dt->add( months => ( 0.5 - rand ) * 1E6 );
        $dt->add( days => ( 0.5 - rand ) * 31 );
        $dt->add( seconds => ( 0.5 - rand ) * 24*60*60 );
        $dt->add( nanoseconds => ( 0.5 - rand ) * 1E9 );
        return $dt;
    }

    return undef unless defined $span->start;

    if ( $span->start->is_infinite )
    {
        my $dt = $span->end;
        $dt->add( months => ( - rand ) * 1E6 );
        $dt->add( days => ( - rand ) * 31 );
        $dt->add( seconds => ( - rand ) * 24*60*60 );
        $dt->add( nanoseconds => ( - rand ) * 1E9 );
        return $dt;
    }

    if ( $span->end->is_infinite )
    {
        my $dt = $span->start;
        $dt->add( months => ( rand ) * 1E6 );
        $dt->add( days => ( rand ) * 31 );
        $dt->add( seconds => ( rand ) * 24*60*60 );
        $dt->add( nanoseconds => ( rand ) * 1E9 );
        return $dt;
    }

    my $dt1 = $span->start;
    my $dt2 = $span->end;
    my %deltas = $dt2->subtract_datetime( $dt1 )->deltas;
    # find out the most significant delta
    if ( $deltas{months} ) {
        $deltas{months}++;
        $deltas{days} = 31;
        $deltas{minutes} = 24*60;
        $deltas{seconds} = 60;
        $deltas{nanoseconds} = 1E9;
    }
    elsif ( $deltas{days} ) {
        $deltas{days}++;
        $deltas{minutes} = 24*60;
        $deltas{seconds} = 60;
        $deltas{nanoseconds} = 1E9;
    }
    elsif ( $deltas{minutes} ) {
        $deltas{minutes}++;
        $deltas{seconds} = 60;
        $deltas{nanoseconds} = 1E9;
    }
    elsif ( $deltas{seconds} ) {
        $deltas{seconds}++;
        $deltas{nanoseconds} = 1E9;
    }
    else {
        $deltas{nanoseconds}++;
    }

    my %duration;
    my $dt;
    while (1) {
        %duration = ();
        for ( keys %deltas ) {
            $duration{ $_ } = int( rand() * $deltas{ $_ } ) 
                if $deltas{ $_ };
        }
        $dt = $dt1->clone->add( %duration );
        return $dt if $span->contains( $dt );

        %duration = ();
        for ( keys %deltas ) {
            $duration{ $_ } = int( rand() * $deltas{ $_ } )
                if $deltas{ $_ };
        }
        $dt = $dt2->clone->subtract( %duration );
        return $dt if $span->contains( $dt );
    }
}

sub duration {
    my $class = shift;
    carp "Missing class name in call to ".__PACKAGE__."->duration()"
        unless defined $class;
    my $dur;
    if ( @_ ) {
        if ( $_[0] eq 'duration' ) {
            $dur = $_[1];
        }
        else
        {
            $dur = DateTime::Duration->new( @_ );
        }
    }
    if ( $dur ) {
        my $dt1 = DateTime->now();
        my $dt2 = $dt1 + $dur;
        my $dt3 = $class->datetime( start => $dt1, before => $dt2 );
        return $dt3 - $dt1;
    }
    return DateTime->now() - $class->datetime();
}

1;

__END__

=head1 NAME

DateTime::Event::Random - DateTime extension for creating random datetimes.


=head1 SYNOPSIS

 use DateTime::Event::Random;

 # creates a DateTime::Set of random dates 
 # with an average density of 4 months, 
 # that is, 3 events per year, with a span 
 # of 2 years
 my $rand = DateTime::Event::Random->new(
     months => 4,
     start => DateTime->new( year => 2003 ),
     end =>   DateTime->new( year => 2005 ),
 ); 

 print "next is ", $rand->next( DateTime->today )->datetime, "\n";
 # output: next is 2004-02-29T22:00:51

 my $count = $rand->count;
 print "days $count \n";
 # output: days 8  -- should be a number near 6

 my @days = $rand->as_list;
 print join('; ', map{ $_->datetime } @days ) . "\n";
 # output: 2003-02-16T21:08:58; 2003-02-18T01:24:13; ...


 # Create a DateTime
 $dt = DateTime::Event::Random->datetime( after => DateTime->now );


 # Create a DateTime::Duration
 $dur = DateTime::Event::Random->duration( days => 15 );


=head1 DESCRIPTION

This module provides convenience methods that let you easily create
C<DateTime::Set> objects with random datetimes.

It also provides functions for building random C<DateTime> and 
C<DateTime::Duration> objects.


=head1 USAGE

=over 4

=item * new

Creates a C<DateTime::Set> object representing the
set of random events.

  my $random_set = DateTime::Event::Random->new;

The set members occur at an average of once a day, forever.

You may give I<density> parameters to change this:

  my $two_daily_set = DateTime::Event::Random->new( days => 2 );

  my $three_weekly_set = DateTime::Event::Random->new( weeks => 3 );

If I<span> parameters are given, then the set is limited to the span:

 my $rand = DateTime::Event::Random->new(
     months => 4,
     start => DateTime->new( year => 2003 ),
     end =>   DateTime->new( year => 2005 ),
 );

Note that the random values are generated on demand, 
which means that values may not be repeateable between iterations.
See the C<new_cached> constructor for a solution.

=item * new_cached

Creates a C<DateTime::Set> object representing the
set of random events.

  my $random_set = DateTime::Event::Random->new_cached;

If a set is created with C<new_cached>, then once an value is I<seen>,
it is cached, such that all sequences extracted from the set are equal.

Cached sets are slower and take more memory than sets generated
with the plain C<new> constructor. They should only be used if
you need unbounded sets that would be accessed many times and
when you need repeatable results.


=item * datetime

Returns a random C<DateTime> object. 

    $dt = DateTime::Event::Random->datetime;

If a C<span> is specified, then the returned value will be within the span:

    $dt = DateTime::Event::Random->datetime( span => $span );

    $dt = DateTime::Event::Random->datetime( after => DateTime->now );


=item * duration

Returns a random C<DateTime::Duration> object.

    $dur = DateTime::Event::Random->duration;

If a C<duration> is specified, then the returned value will be within the
duration:

    $dur = DateTime::Event::Random->duration( duration => $dur );

    $dur = DateTime::Event::Random->duration( days => 15 );


=head1 NOTES

The C<DateTime::Set> module does not allow for repetition of values.
That is, a function like C<next($dt)> will always
return a value I<bigger than> C<$dt>.
Each element in a set is different.

Although the datetime values in the C<DateTime::Set> are random,
the accessors (C<as_list>, C<iterator/next/previous>) always 
return I<sorted> datetimes.

The I<set> functions calculate all intervals in seconds, which may give
a 32-bit integer overflow if you ask for a density less than
about "1 occurence in each 30 years" - which is about a billion seconds.
This may change in a next version.


=head1 COOKBOOK


=head2 Make a random sunday

  use DateTime::Event::Random;

  my $dt = DateTime::Event::Random->datetime;
  $dt->truncate( to => week );
  $dt->add( days => 6 );

  print "datetime " . $dt->datetime . "\n";
  print "weekday " .  $dt->day_of_week . "\n";


=head2 Make a random friday-13th

  use DateTime::Event::Random;
  use DateTime::Event::Recurrence;

  my $friday = DateTime::Event::Recurrence->monthly( days => 13 );
  my $day_13 = DateTime::Event::Recurrence->weekly( days => 6 ); 
  my $friday_13 = $friday->intersection( $day_13 );

  my $dt = $friday_13->next( DateTime::Event::Random->datetime );

  print "datetime " .  $dt->datetime . "\n";
  print "weekday " .   $dt->day_of_week . "\n";
  print "month day " . $dt->day . "\n";


=head2 Make a random datetime, today

  use DateTime::Event::Random;

  my $dt = DateTime->today + DateTime::Event::Random->duration( days => 1 );

  print "datetime " .  $dt->datetime . "\n";


=head1 AUTHOR

Flavio Soibelmann Glock
fglock@pucrs.br


=head1 COPYRIGHT

Copyright (c) 2003 Flavio Soibelmann Glock.  
All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

The full text of the license can be found in the LICENSE file included
with this module.


=head1 SEE ALSO

datetime@perl.org mailing list

DateTime Web page at http://datetime.perl.org/

DateTime - date and time :)

DateTime::Set - for recurrence-set accessors docs.

=cut

