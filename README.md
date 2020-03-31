[![Actions Status](https://github.com/atoomic/Simple-Accessor/workflows/linux/badge.svg)](https://github.com/atoomic/Simple-Accessor/actions)
[![Actions Status](https://github.com/atoomic/Simple-Accessor/workflows/macos/badge.svg)](https://github.com/atoomic/Simple-Accessor/actions)

# NAME
Simple::Accessor - very simple, light and powerful accessor

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

You can even use a very basic but useful hook system.
Any false value return by before or validate, will stop the setting process.
Be careful with the after method, as there is no protection against infinite loop.

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
