use strict;
use warnings;

use Test::More tests => 15;

# --- Test packages defined inline ---

# 1. _before_build lifecycle ordering
{
    package LifecycleOrder;
    use Simple::Accessor qw{name status};

    my @log;

    sub get_log { [@log] }
    sub reset_log { @log = () }

    sub _before_build {
        my ($self, %opts) = @_;
        push @log, 'before_build';
    }

    sub _before_name {
        my ($self, $v) = @_;
        push @log, 'before_name';
        return 1;
    }

    sub _before_status {
        my ($self, $v) = @_;
        push @log, 'before_status';
        return 1;
    }
}

# 2. Error propagation from accessors
{
    package StrictValidator;
    use Simple::Accessor qw{age};

    sub _validate_age {
        my ($self, $v) = @_;
        die "age must be positive" if $v < 0;
        return 1;
    }
}

# 3. Falsy builder values
{
    package FalsyBuilder;
    use Simple::Accessor qw{zero_val empty_str undef_val};

    my $zero_calls = 0;
    my $empty_calls = 0;
    my $undef_calls = 0;

    sub _build_zero_val  { $zero_calls++;  return 0 }
    sub _build_empty_str { $empty_calls++; return '' }
    sub _build_undef_val { $undef_calls++; return undef }

    sub zero_call_count  { $zero_calls }
    sub empty_call_count { $empty_calls }
    sub undef_call_count { $undef_calls }
}

# === Bug 1: _before_build fires BEFORE attributes are set ===

LifecycleOrder->reset_log();
my $obj = LifecycleOrder->new(name => 'test');
my $log = LifecycleOrder->get_log();

is $log->[0], 'before_build',
    '_before_build fires first (before attribute setters)';

ok grep({ $_ eq 'before_name' } @$log),
    '_before_name fires when setting name';

# _before_build should be before any _before_* accessor hooks
my $bb_idx = 0;
for my $i (0..$#$log) {
    $bb_idx = $i if $log->[$i] eq 'before_build';
}
my $bn_idx = 0;
for my $i (0..$#$log) {
    $bn_idx = $i if $log->[$i] eq 'before_name';
}
ok $bb_idx < $bn_idx,
    '_before_build index < _before_name index (correct ordering)';

# === Bug 2: Errors from accessors now propagate ===

my $strict = eval { StrictValidator->new(age => 5) };
ok $strict, 'valid age creates object';
is $strict->age, 5, 'age is set correctly';

eval { StrictValidator->new(age => -1) };
like $@, qr/age must be positive/,
    'validation error propagates from new() (not swallowed)';

# Unknown keys should be silently ignored (no accessor for them)
my $with_unknown = StrictValidator->new(age => 10, unknown_key => 'whatever');
ok $with_unknown, 'unknown keys in new() are silently ignored';
is $with_unknown->age, 10, 'known attributes still set correctly';

# === Bug 3: Falsy builders only fire once ===

my $fb = FalsyBuilder->new();

is $fb->zero_val, 0, 'builder returning 0 works';
$fb->zero_val;  # second access
is( FalsyBuilder->zero_call_count(), 1,
    'builder returning 0 is NOT called again on second access' );

is $fb->empty_str, '', 'builder returning empty string works';
$fb->empty_str;  # second access
is( FalsyBuilder->empty_call_count(), 1,
    'builder returning empty string is NOT called again on second access' );

# undef builder — with exists check, undef IS stored (key exists), so builder fires once
my $fb2 = FalsyBuilder->new();
$fb2->undef_val;
$fb2->undef_val;  # second access
is( FalsyBuilder->undef_call_count(), 1,
    'builder returning undef fires only once (key exists after first call)' );

# Verify 0 survives round-trip through new()
my $fb3 = FalsyBuilder->new();
is $fb3->zero_val, 0, 'zero_val is 0 after build';
is $fb3->zero_val, 0, 'zero_val stays 0 on subsequent access';
