#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

# Test that exceptions thrown inside hooks and builders propagate correctly
# to the caller, rather than being swallowed or mangled.

# === Setup: classes with hooks/builders that die ===

{
    package ErrBuilder;
    use Simple::Accessor qw{name broken};

    sub _build_broken {
        die "builder kaboom\n";
    }
}

{
    package ErrBefore;
    use Simple::Accessor qw{guarded};

    sub _before_guarded {
        my ($self, $v) = @_;
        die "before hook kaboom\n" if $v && $v eq 'boom';
        return 1;
    }
}

{
    package ErrValidate;
    use Simple::Accessor qw{checked};

    sub _validate_checked {
        my ($self, $v) = @_;
        die "validate hook kaboom\n" if $v && $v eq 'boom';
        return 1;
    }
}

{
    package ErrAfter;
    use Simple::Accessor qw{tracked};

    sub _after_tracked {
        my ($self) = @_;
        die "after hook kaboom\n";
    }
}

{
    package ErrBuild;
    use Simple::Accessor qw{x};

    sub build {
        my ($self, %opts) = @_;
        die "build() kaboom\n";
    }
}

{
    package ErrInitialize;
    use Simple::Accessor qw{x};

    sub initialize {
        my ($self, %opts) = @_;
        die "initialize() kaboom\n";
    }
}

{
    package ErrBeforeBuild;
    use Simple::Accessor qw{x};

    sub _before_build {
        my ($self, %opts) = @_;
        die "_before_build kaboom\n";
    }
}

{
    package ErrAfterBuild;
    use Simple::Accessor qw{x};

    sub _after_build {
        my ($self, %opts) = @_;
        die "_after_build kaboom\n";
    }
}

# === Test: _build_* exception propagates through lazy getter ===

{
    my $obj = ErrBuilder->new(name => 'test');
    ok $obj, 'object created without triggering lazy builder';

    is $obj->name, 'test', 'normal attr works';

    eval { $obj->broken };
    like $@, qr/builder kaboom/, '_build_* exception propagates through getter';
}

# === Test: _before_* exception propagates through setter ===

{
    my $obj = ErrBefore->new();
    ok $obj, 'ErrBefore object created';

    $obj->guarded('safe');
    is $obj->guarded, 'safe', '_before_* allows normal values';

    eval { $obj->guarded('boom') };
    like $@, qr/before hook kaboom/, '_before_* exception propagates through setter';
    is $obj->guarded, 'safe', 'value unchanged after _before_* dies';
}

# === Test: _validate_* exception propagates through setter ===

{
    my $obj = ErrValidate->new();
    ok $obj, 'ErrValidate object created';

    $obj->checked('safe');
    is $obj->checked, 'safe', '_validate_* allows normal values';

    eval { $obj->checked('boom') };
    like $@, qr/validate hook kaboom/, '_validate_* exception propagates through setter';
    is $obj->checked, 'safe', 'value unchanged after _validate_* dies';
}

# === Test: _after_* exception propagates (value already set) ===

{
    my $obj = ErrAfter->new();
    ok $obj, 'ErrAfter object created';

    eval { $obj->tracked('hello') };
    like $@, qr/after hook kaboom/, '_after_* exception propagates through setter';
    # The value WAS set before _after_* ran, and since we died (not returned false),
    # there's no rollback — the die bypasses the rollback logic
    is $obj->tracked, 'hello', 'value persists when _after_* dies (no rollback on exception)';
}

# === Test: _before_* exception in constructor propagates ===

{
    my $obj = ErrBefore->new(guarded => 'safe');
    ok $obj, 'constructor with safe _before_* value works';

    eval { ErrBefore->new(guarded => 'boom') };
    like $@, qr/before hook kaboom/, '_before_* exception propagates through constructor';
}

# === Test: _validate_* exception in constructor propagates ===

{
    eval { ErrValidate->new(checked => 'boom') };
    like $@, qr/validate hook kaboom/, '_validate_* exception propagates through constructor';
}

# === Test: build() exception propagates through new() ===

{
    eval { ErrBuild->new() };
    like $@, qr/build\(\) kaboom/, 'build() exception propagates through new()';
}

# === Test: initialize() exception propagates through new() ===

{
    eval { ErrInitialize->new() };
    like $@, qr/initialize\(\) kaboom/, 'initialize() exception propagates through new()';
}

# === Test: _before_build exception propagates through new() ===

{
    eval { ErrBeforeBuild->new() };
    like $@, qr/_before_build kaboom/, '_before_build exception propagates through new()';
}

# === Test: _after_build exception propagates through new() ===

{
    eval { ErrAfterBuild->new(x => 1) };
    like $@, qr/_after_build kaboom/, '_after_build exception propagates through new()';
}

# === Test: with() on nonexistent module propagates require error ===

{
    package WithBadModule;
    use Simple::Accessor qw{a};

    package main;
    eval { WithBadModule::with('Nonexistent::Module::That::Does::Not::Exist') };
    like $@, qr/Can't locate/, 'with() on missing module propagates require error';
}

# === Test: builder die does not corrupt object state ===

{
    my $obj = ErrBuilder->new(name => 'intact');

    eval { $obj->broken };  # dies
    is $obj->name, 'intact', 'other attrs intact after builder dies';

    # The failed builder should not cache a value
    eval { $obj->broken };  # should die again, not return stale state
    like $@, qr/builder kaboom/, 'builder dies again on retry (no stale cache)';
}

# === Test: exception in setter leaves no partial guard state ===

{
    my $obj = ErrAfter->new();

    eval { $obj->tracked('first') };  # dies in _after_*
    # guard state should be cleaned up by local()
    eval { $obj->tracked('second') };  # should still trigger _after_*, not skip it
    like $@, qr/after hook kaboom/, 're-entrancy guard cleaned up after exception (local)';
}

done_testing;
