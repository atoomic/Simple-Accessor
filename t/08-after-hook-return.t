use strict;
use warnings;

use Test::More tests => 12;

# --- Test packages ---

# 1. _after_* hook that returns false
{
    package AfterReturnsFalse;
    use Simple::Accessor qw{color size};

    sub _after_color {
        my ($self, $v) = @_;
        # Side effect: sync size from color length
        $self->size(length($v)) if defined $v;
        return 0;  # false return should NOT affect the setter
    }
}

# 2. _after_* hook that returns undef
{
    package AfterReturnsUndef;
    use Simple::Accessor qw{name};

    sub _after_name {
        my ($self, $v) = @_;
        return undef;  # should be ignored
    }
}

# 3. _after_* hook that returns empty string
{
    package AfterReturnsEmpty;
    use Simple::Accessor qw{tag};

    sub _after_tag {
        my ($self, $v) = @_;
        return '';  # false-y, should be ignored
    }
}

# 4. _before_* and _validate_* should still gate the setter
{
    package BeforeStillGates;
    use Simple::Accessor qw{guarded};

    sub _before_guarded {
        my ($self, $v) = @_;
        return 0;  # reject all sets
    }
}

{
    package ValidateStillGates;
    use Simple::Accessor qw{checked};

    sub _validate_checked {
        my ($self, $v) = @_;
        return $v > 0 ? 1 : 0;
    }
}

# === _after_* returning false does NOT prevent the set ===

my $obj = AfterReturnsFalse->new();
$obj->color('red');
is $obj->color, 'red',
    '_after_* returning 0 does not prevent value from being set';

is $obj->size, 3,
    '_after_* side effect still executed (size set from color length)';

# Accessor return value should be the stored value, not the hook's return
my $ret = $obj->color('blue');
is $ret, 'blue',
    'accessor returns the stored value, not the _after_* return value';

is $obj->size, 4,
    '_after_* side effect updates on each set';

# === _after_* returning undef does NOT prevent the set ===

my $obj2 = AfterReturnsUndef->new();
$obj2->name('alice');
is $obj2->name, 'alice',
    '_after_* returning undef does not prevent value from being set';

my $ret2 = $obj2->name('bob');
is $ret2, 'bob',
    'accessor returns stored value when _after_* returns undef';

# === _after_* returning empty string does NOT prevent the set ===

my $obj3 = AfterReturnsEmpty->new();
$obj3->tag('important');
is $obj3->tag, 'important',
    '_after_* returning empty string does not prevent value from being set';

# === _before_* returning false STILL prevents the set ===

my $obj4 = BeforeStillGates->new();
$obj4->guarded(42);
is $obj4->guarded, undef,
    '_before_* returning false still prevents value from being set';

my $ret4 = $obj4->guarded(99);
ok !defined($ret4),
    '_before_* returning false makes accessor return undef';

# === _validate_* returning false STILL prevents the set ===

my $obj5 = ValidateStillGates->new();
$obj5->checked(10);
is $obj5->checked, 10,
    '_validate_* returning true allows the set';

$obj5->checked(-5);
is $obj5->checked, 10,
    '_validate_* returning false prevents the set (value unchanged)';

my $ret5 = $obj5->checked(-1);
ok !defined($ret5),
    '_validate_* returning false makes accessor return undef';
