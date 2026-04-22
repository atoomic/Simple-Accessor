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

for my $name (@reserved) {
    my $pkg = "Reserved_" . ($name =~ s/\W/_/gr);
    my $code = qq{
        package $pkg;
        use Simple::Accessor ('$name');
        1;
    };
    eval $code;
    like $@, qr/conflicts with a Simple::Accessor lifecycle method/,
        "attribute '$name' is rejected as reserved";
}

# Non-reserved names still work fine
{
    package Normal::Attrs;
    use Simple::Accessor qw{building initialized before_build};
    # These are NOT reserved — they're close but distinct.
}

my $obj = Normal::Attrs->new(
    building     => 'yes',
    initialized  => 1,
    before_build => 'ok',
);

is $obj->building,     'yes', 'near-reserved name "building" works';
is $obj->initialized,  1,     'near-reserved name "initialized" works';
is $obj->before_build, 'ok',  'near-reserved name "before_build" works (no leading _)';

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
