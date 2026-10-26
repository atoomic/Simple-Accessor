#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib";

# Attribute names that shadow constructor lifecycle methods must be rejected
# at import time.  Without this guard, an attribute named 'build' silently
# replaces the lifecycle method, causing the constructor to malfunction.

my @reserved = qw(
    new with build initialize
    _before_build _after_build _strict_constructor
);

my $pkg_counter = 0;

sub try_import {
    my (@attrs) = @_;

    my $pkg = "Reserved::Pkg" . ++$pkg_counter;
    my $list = join ' ', @attrs;
    eval qq{
        package $pkg;
        use Simple::Accessor qw{$list};
        1;
    };

    return ( $pkg, $@ );
}

for my $name (@reserved) {
    my ( undef, $err ) = try_import($name);
    like $err, qr/conflicts with a Simple::Accessor lifecycle method/,
        "attribute '$name' is rejected as reserved";
}

# The per-attribute hook / builder name families are reserved too: an
# attribute named '_build_foo' would shadow the lazy builder for 'foo'.
my @hook_names = qw(
    _build_foo _initialize_foo _before_foo _validate_foo _after_foo
);

for my $name (@hook_names) {
    my ( undef, $err ) = try_import($name);
    like $err, qr/conflicts with a Simple::Accessor hook\/builder name/,
        "attribute '$name' is rejected as a hook/builder name";
}

# Non-reserved names still work fine
{
    package Normal::Attrs;
    use Simple::Accessor qw{building initialized before_build build_foo};
    # These are NOT reserved — they're close but distinct.
}

my $obj = Normal::Attrs->new(
    building     => 'yes',
    initialized  => 1,
    before_build => 'ok',
    build_foo    => 'fine',
);

is $obj->building,     'yes', 'near-reserved name "building" works';
is $obj->initialized,  1,     'near-reserved name "initialized" works';
is $obj->before_build, 'ok',  'near-reserved name "before_build" works (no leading _)';
is $obj->build_foo,    'fine', 'near-reserved name "build_foo" works (no leading _)';

# Reserved check applies even when mixed with valid attrs
eval q{
    package Mixed::Reserved;
    use Simple::Accessor qw{foo build bar};
    1;
};
like $@, qr/conflicts with a Simple::Accessor lifecycle method/,
    "reserved name in a mixed list is still rejected";

# Verify the valid attrs before the reserved one were NOT installed
ok !Mixed::Reserved->can('foo'),
    "attrs before the reserved name are not partially installed";

done_testing;
