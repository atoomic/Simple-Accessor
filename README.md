[![Actions Status](https://github.com/atoomic/Simple-Accessor/actions/workflows/linux/badge.svg)](https://github.com/atoomic/Simple-Accessor/actions)
[![Actions Status](https://github.com/atoomic/Simple-Accessor/actions/workflows/macos/badge.svg)](https://github.com/atoomic/Simple-Accessor/actions)

# NAME
Simple::Accessor - very simple, light and powerful accessor

# SYNOPSIS

```perl
package Role::Color;
use Simple::Accessor qw{color};

sub _build_color { 'red' } # default color

package Car;

# that s all what you need ! no more line required
use Simple::Accessor qw{brand hp};

with 'Role::Color';

sub _build_hp { 2 }
sub _build_brand { 'unknown' }

package main;

my $c = Car->new( brand => 'zebra' );

is $c->brand, 'zebra';
is $c->color, 'red';
```

# DESCRIPTION

Simple::Accessor provides a simple object layer without any dependency.
It can be used where other ORM could be considered too heavy.
But it has also the main advantage to only need one single line of code.

It can be easily used in scripts...

# Usage

Create a package and just call Simple::Accessor.
The new method will be imported for you, and all accessors will be directly
accessible.

```perl
package MyClass;

# that s all what you need ! no more line required
use Simple::Accessor qw{foo bar cherry apple};
```

You can also split your attribute declarations across multiple `use` statements.
Attributes from all imports are merged and fully supported by the constructor,
strict constructor mode, and deterministic initialization ordering.

```perl
package MyClass;

use Simple::Accessor qw{foo bar};
use Simple::Accessor qw{cherry apple};

# all four attributes work in the constructor
my $o = MyClass->new(foo => 1, bar => 2, cherry => 3, apple => 4);
```

You can now call 'new' on your class, and create objects using these attributes

```perl
package main;
use MyClass;

my $o = MyClass->new()
    or MyClass->new(bar => 42)
    or MyClass->new(apple => 'fruit', cherry => 'fruit', banana => 'yummy');
```

You can get / set any value using the accessor

```
is $o->bar(), 42;
$o->bar(51);
is $o->bar(), 51;
```

You can provide your own init method that will be call by new with default args.
This is optional.

```perl
package MyClass;

sub build { # previously known as initialize
    my ($self, %opts) = @_;

    $self->foo(12345);
}
```

You can also control the object after or before its creation using

```perl
sub _before_build {
    my ($self, %opts) = @_;
    ...
}

sub _after_build {
    my ($self, %opts) = @_;
    ...
    bless $self, 'Basket';
}
```

You can also provide individual builders / initializers

```perl
sub _build_bar { # previously known as _initialize_bar
    # will be used if no value has been provided for bar
    1031;
}

sub _build_cherry {
    'red';
}
```

You can enable strict constructor mode to catch typos in attribute names:

```perl
package MyClass;
use Simple::Accessor qw{name age};

sub _strict_constructor { 1 }

package main;
MyClass->new(nmae => 'oops');
# dies: "MyClass->new(): unknown attribute(s): nmae"
```

This is opt-in and off by default for backward compatibility.

You can even use a very basic but useful hook system.
Any false value return by before or validate, will stop the setting process.
The after hooks include a re-entrancy guard: if an `_after_*` hook triggers
a setter that would re-enter the same attribute, the nested `_after_*` call
is skipped to prevent infinite recursion.

```perl
sub _before_foo {
    my ($self, $v) = @_;

    # do whatever you want with $v
    return 1 or 0;
}

sub _validate_foo {
    my ($self, $v) = @_;
    # invalid value ( will not be set )
    return 0 if ( $v == 42);
    # valid value
    return 1;
}

sub _after_cherry {
    my ($self) = @_;

    # use the set value for extra operations
    $self->apple($self->cherry());
}
```

# METHODS

None. The only public method provided is the classical import.

# CONTRIBUTE

You can contribute to this project on github https://github.com/atoomic/Simple-Accessor

# AI POLICY

This project uses AI tools to assist development. Humans review and approve every change before it is merged. See [AI\_POLICY.md](AI_POLICY.md) for details.
