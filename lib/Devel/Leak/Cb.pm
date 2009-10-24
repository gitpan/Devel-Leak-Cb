package Devel::Leak::Cb;

use 5.008008;
use common::sense;
m{
use strict;
use warnings;
}x;
=head1 NAME

Devel::Leak::Cb - Detect leaked callbacks

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Devel::Leak::Cb;
    
    AnyEvent->timer( cb => cb {
        ...
    });
    
    # If $ENV{DEBUG_CB} is true and callback not destroyed till END, the you'll be noticed

=head1 DESCRIPTION

By default, cb { .. } will be rewritten as sub { .. } using L<Devel::Declare> and will give no additional cost at runtime

When C<$ENV{DEBUG_CB}> will be set, then all cb {} declarations will be counted, and if some of them will not be destroyed till the END stage, you'll be warned

=head1 EXPORT

Exports a single function: cb {}, which would be rewritten as sub {} when C<$ENV{DEBUG_CB}> is not in effect

If C<DEBUG_CB> > 1 and L<Devel::FindRef> is installed, then output will include reference tree of leaked callbacks

=head1 FUNCTIONS

=head2 cb {}

=cut

use Devel::Declare ();
use Scalar::Util 'weaken';

BEGIN {
	if ($ENV{DEBUG_CB}) {
		my $debug = $ENV{DEBUG_CB};
		*DEBUG = sub () { $debug };
	} else {
		*DEBUG = sub () { 0 };
	}
}

BEGIN {
	if (DEBUG){
		eval { require Sub::Identify; Sub::Identify->import('sub_fullname'); 1 } or *sub_fullname = sub { return };
		eval { require Devel::Refcount; Devel::Refcount->import('refcount'); 1 } or *refcount = sub { 1 };
		DEBUG > 1 and eval { require Devel::FindRef; *findref = \&Devel::FindRef::track;   1 } or *findref  = sub { "No Devel::FindRef installed\n" };
	}
}

our $SUBNAME = 'cb';
our %DEF;

sub import{
	my $class = shift;
	my $caller = caller;
	if (DEBUG) {
		no strict 'refs';
		*{$caller.'::'.$SUBNAME } = \&cb;
		*COUNT = sub {
			for (keys %DEF) {
				$DEF{$_}[1] or next;
				my $name = sub_fullname($DEF{$_}[1]);
				warn "Leaked: $_ ".($name ? $name : 'ANON')." (refs:".refcount($DEF{$_}[1]).") defined at $DEF{$_}[0]\n".(DEBUG > 1 ? findref($DEF{$_}[1]) : '' );
			}
		};
		return;
	} else {
		Devel::Declare->setup_for(
			$caller,
			{ $SUBNAME => { const => \&parse } }
		);
		{
			no strict 'refs';
			*{$caller.'::'.$SUBNAME } = sub() {1 };
		}
		*COUNT = sub {};
	}
}


sub cb (&) {
	$DEF{int $_[0]} = [ join(' line ',(caller())[1,2]), $_[0] ];weaken($DEF{int $_[0]}[1]);
	return bless shift,'__cb__';
};

sub __cb__::DESTROY {
	delete($DEF{int $_[0]});
};

sub parse {
	my $offset = $_[1];
	$offset += Devel::Declare::toke_move_past_token($offset);
	$offset += Devel::Declare::toke_skipspace($offset);
	my $linestr = Devel::Declare::get_linestr();
	substr($linestr,$offset,0) = '&& sub';
	Devel::Declare::set_linestr($linestr);
	return;
}

END {
	COUNT();
}

=head1 AUTHOR

Mons Anderson, C<< <mons at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-devel-leak-cb at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Devel-Leak-Cb>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Devel::Leak::Cb

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Devel-Leak-Cb>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Mons Anderson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Devel::Leak::Cb
