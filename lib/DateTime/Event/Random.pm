
package DateTime::Event::Random;

use strict;
# use DateTime;
use DateTime::Set;
# use DateTime::Span;
# use Params::Validate qw(:all);
use vars qw( $VERSION @ISA );
$VERSION = 0.01_01;

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

1;

__END__

=head1 NAME

DateTime::Event::Random - DateTime::Set extension for creating random datetimes.

=head1 SYNOPSIS

 use DateTime::Event::Random;

 # creates a set of random dates 
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

 @days = $rand->as_list;
 print "days ", 1 + $#days, "\n";
 # output: days 8
 #  - we expect a number near 6

 print join('; ', map{ $_->datetime } @days );
 # output: 2003-02-16T21:08:58; 2003-02-18T01:24:13; ...

=head1 DESCRIPTION

This module provides convenience methods that let you easily create
C<DateTime::Set> objects with random datetimes.

=head1 USAGE

=over 4

=item * new

Returns a C<DateTime::Set> object representing the
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

=item * new_cached

Returns a C<DateTime::Set> object representing the
set of random events.

Unbounded random sets are generated on demand, which
means that the datetime values would not be repeateable between iterations.

If a set is created with C<new_cached>, then once an event is I<seen>, 
it is cached, such that 
all sequences extracted from the set are equal.

  my $random_set = DateTime::Event::Random->new_cached;

Cached sets are slower and take more memory than sets generated
with the plain C<new> constructor. It should only be used if
you need unbounded sets that would be accessed many times and
that need repeatable results.

=head1 NOTES

The module does not allow for repetition of values.
That is, a function like C<next($dt)> will always
return a value I<bigger than> C<$dt>.
Each element in a set is different.

Although the datetime values are random,
the accessors (C<as_list>, C<iterator/next/previous>) always 
return sorted datetimes.

The module calculates all intervals in seconds, which may give
a 32-bit integer overflow if you ask for a density less than
about "1 occurence in each 30 years" - which is about a billion seconds.
This may change in a next version.

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

