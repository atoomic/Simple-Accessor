#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

# build() and initialize() return values should NOT affect construction.
# Previously, `return unless $self->$init(%opts)` meant that a falsy
# return from build() would silently abort the constructor (new() returned
# undef).  This contradicts Perl OO convention — Moose and Moo both
# ignore BUILD's return value.

# --- build() returning 0 via setter ---
{
    package BuildReturnZero;
    use Simple::Accessor qw{count name};

    sub build {
        my ($self, %opts) = @_;
        $self->count(0);    # returns 0 — falsy
    }
}

{
    my $obj = BuildReturnZero->new(name => 'test');
    ok( defined $obj, 'new() succeeds when build() returns 0 via setter' );
    is( $obj->count, 0, 'count attribute is set to 0' );
    is( $obj->name, 'test', 'name attribute is set from constructor args' );
}

# --- build() returning empty string ---
{
    package BuildReturnEmpty;
    use Simple::Accessor qw{label};

    sub build {
        my ($self, %opts) = @_;
        $self->label("");    # returns "" — falsy
    }
}

{
    my $obj = BuildReturnEmpty->new();
    ok( defined $obj, 'new() succeeds when build() returns empty string' );
    is( $obj->label, "", 'label attribute is set to empty string' );
}

# --- build() returning undef explicitly ---
{
    package BuildReturnUndef;
    use Simple::Accessor qw{data};

    sub build {
        my ($self, %opts) = @_;
        $self->data('something');
        return undef;
    }
}

{
    my $obj = BuildReturnUndef->new();
    ok( defined $obj, 'new() succeeds when build() explicitly returns undef' );
    is( $obj->data, 'something', 'data attribute is set despite undef return' );
}

# --- initialize() (backward compat) also ignores return value ---
{
    package InitReturnZero;
    use Simple::Accessor qw{flag};

    sub initialize {
        my ($self, %opts) = @_;
        $self->flag(0);
    }
}

{
    my $obj = InitReturnZero->new();
    ok( defined $obj, 'new() succeeds when initialize() returns 0' );
    is( $obj->flag, 0, 'flag attribute is set to 0 via initialize()' );
}

# --- build() with truthy return (still works, regression check) ---
{
    package BuildTruthy;
    use Simple::Accessor qw{value};

    sub build {
        my ($self, %opts) = @_;
        $self->value(42);
    }
}

{
    my $obj = BuildTruthy->new();
    ok( defined $obj, 'new() succeeds when build() returns truthy' );
    is( $obj->value, 42, 'value attribute is set correctly' );
}

# --- _after_build still fires after build() ---
{
    package BuildWithAfter;
    use Simple::Accessor qw{x y};

    sub build {
        my ($self, %opts) = @_;
        $self->x(0);    # falsy return
    }

    sub _after_build {
        my ($self, %opts) = @_;
        $self->y( ($self->x // -1) + 1 );
    }
}

{
    my $obj = BuildWithAfter->new();
    ok( defined $obj, 'new() succeeds with falsy build() and _after_build' );
    is( $obj->x, 0, 'x set to 0 in build()' );
    is( $obj->y, 1, '_after_build fires and can read build()-set values' );
}

# --- build() that dies still propagates the exception ---
{
    package BuildDies;
    use Simple::Accessor qw{safe};

    sub build {
        my ($self, %opts) = @_;
        die "construction aborted\n";
    }
}

{
    my $obj = eval { BuildDies->new() };
    ok( !defined $obj, 'new() fails when build() throws' );
    like( $@, qr/construction aborted/, 'exception propagates from build()' );
}

done_testing;
