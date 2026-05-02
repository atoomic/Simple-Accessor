use strict;
use warnings;

use Test::More tests => 33;

# =============================================================
# Test accessor behavior with special Perl values and edge-case
# attribute names that exercise unusual but valid code paths:
#   - Reference values (hashref, arrayref, coderef, blessed, regex)
#   - Underscore-prefixed attributes (double-underscore hooks)
#   - Object independence (no cross-talk between instances)
#   - Builders returning references
#   - Hook interaction with reference values
# =============================================================

# --- Reference values: store and retrieve various ref types ---
{
    package RefStore;
    use Simple::Accessor qw{hash_val array_val code_val obj_val regex_val};

    package main;

    my $href  = { a => 1, b => 2 };
    my $aref  = [10, 20, 30];
    my $cref  = sub { 'hello' };
    my $obj   = bless { id => 42 }, 'SomeClass';
    my $regex = qr/^foo\d+$/;

    my $o = RefStore->new(
        hash_val  => $href,
        array_val => $aref,
        code_val  => $cref,
        obj_val   => $obj,
        regex_val => $regex,
    );

    is_deeply $o->hash_val,  $href,  'hashref round-trips through constructor';
    is_deeply $o->array_val, $aref,  'arrayref round-trips through constructor';
    is $o->code_val,  $cref,  'coderef round-trips through constructor';
    is $o->obj_val,   $obj,   'blessed ref round-trips through constructor';
    is $o->regex_val, $regex, 'regex ref round-trips through constructor';

    # verify the coderef is callable
    is $o->code_val->(), 'hello', 'stored coderef is callable';

    # update reference value via setter
    my $new_href = { x => 99 };
    $o->hash_val($new_href);
    is_deeply $o->hash_val, $new_href, 'hashref updated via setter';
}

# --- Builder returning a reference ---
{
    package RefBuilder;
    use Simple::Accessor qw{config items};

    my $config_calls = 0;

    sub _build_config {
        $config_calls++;
        return { debug => 0, verbose => 1 };
    }

    sub _build_items { [qw(alpha beta gamma)] }

    sub config_call_count { $config_calls }

    package main;

    my $o = RefBuilder->new();
    is_deeply $o->config, { debug => 0, verbose => 1 },
        'builder returning hashref works';
    is_deeply $o->items, [qw(alpha beta gamma)],
        'builder returning arrayref works';

    # builder fires only once (reference is stored)
    $o->config;
    is( RefBuilder->config_call_count(), 1,
        'builder returning ref fires only once' );
}

# --- Hooks receive and validate reference values ---
{
    package RefHooks;
    use Simple::Accessor qw{data};

    sub _validate_data {
        my ($self, $v) = @_;
        return ref $v eq 'HASH' ? 1 : 0;
    }

    sub _before_data {
        my ($self, $v) = @_;
        return 1;
    }

    package main;

    my $o = RefHooks->new();
    $o->data({ key => 'val' });
    is_deeply $o->data, { key => 'val' },
        'validate hook accepts hashref';

    $o->data([1, 2, 3]);
    is_deeply $o->data, { key => 'val' },
        'validate hook rejects non-hashref (arrayref), old value kept';

    $o->data('string');
    is_deeply $o->data, { key => 'val' },
        'validate hook rejects non-hashref (string), old value kept';
}

# --- After-hook rollback with reference values ---
{
    package RefRollback;
    use Simple::Accessor qw{payload};

    sub _after_payload {
        my ($self, $v) = @_;
        # reject arrayrefs, accept everything else
        return ref $v eq 'ARRAY' ? 0 : 1;
    }

    package main;

    my $original = { status => 'ok' };
    my $o = RefRollback->new(payload => $original);
    is_deeply $o->payload, $original, 'initial reference value set';

    $o->payload([1, 2, 3]);
    is_deeply $o->payload, $original,
        'after-hook rollback restores original reference on rejection';

    my $new_hash = { status => 'updated' };
    $o->payload($new_hash);
    is_deeply $o->payload, $new_hash,
        'after-hook allows non-arrayref reference';
}

# --- Underscore-prefixed attribute: double-underscore hooks ---
{
    package PrivateAttr;
    use Simple::Accessor qw{_data _count};

    my $validate_called = 0;

    # hook name: _build_ + _data = _build__data (double underscore)
    sub _build__data { 'default-data' }

    # hook name: _validate_ + _data = _validate__data
    sub _validate__data {
        my ($self, $v) = @_;
        $validate_called++;
        return length($v) > 0 ? 1 : 0;
    }

    sub _build__count { 0 }

    sub validate_call_count { $validate_called }

    package main;

    my $o = PrivateAttr->new();
    is $o->_data, 'default-data',
        'underscore-prefix attr: builder _build__data fires';
    is $o->_count, 0,
        'underscore-prefix attr: builder _build__count fires';

    $o->_data('new-value');
    is $o->_data, 'new-value',
        'underscore-prefix attr: setter works';
    is( PrivateAttr->validate_call_count(), 1,
        'underscore-prefix attr: _validate__data hook fires' );

    $o->_data('');
    is $o->_data, 'new-value',
        'underscore-prefix attr: _validate__data rejects empty string';
}

# --- Object independence: no cross-talk between instances ---
{
    package IndependentObj;
    use Simple::Accessor qw{name score};

    sub _build_score { 0 }

    package main;

    my $a = IndependentObj->new(name => 'Alice');
    my $b = IndependentObj->new(name => 'Bob');

    is $a->name, 'Alice', 'instance A has its own name';
    is $b->name, 'Bob',   'instance B has its own name';

    $a->score(100);
    is $a->score, 100, 'instance A score set to 100';
    is $b->score, 0,   'instance B score unaffected (builder default)';

    $b->score(200);
    is $a->score, 100, 'instance A score still 100 after B update';
    is $b->score, 200, 'instance B score updated to 200';

    # reference value independence: modifying one shouldn't affect the other
    my $a_data = { key => 'a' };
    my $b_data = { key => 'b' };
    $a->name($a_data);
    $b->name($b_data);
    $a_data->{key} = 'modified';
    is $a->name->{key}, 'modified',
        'instance A reflects mutation of stored reference';
    is $b->name->{key}, 'b',
        'instance B reference is independent from A';
}

# --- Overloaded object as attribute value ---
{
    package OverloadedVal;
    use overload
        '""'   => sub { "stringified:" . $_[0]->{val} },
        'bool' => sub { 1 },
        fallback => 1;

    sub new { bless { val => $_[1] }, $_[0] }

    package OverloadConsumer;
    use Simple::Accessor qw{tag};

    package main;

    my $ov = OverloadedVal->new('test');
    my $o = OverloadConsumer->new(tag => $ov);
    is ref($o->tag), 'OverloadedVal',
        'overloaded object stored as-is (not stringified)';
    is "${\$o->tag}", 'stringified:test',
        'overloaded stringification works on retrieved value';
}

# --- Builder returning blessed object ---
{
    package ObjBuilder;
    use Simple::Accessor qw{engine};

    sub _build_engine {
        return bless { type => 'v8' }, 'Engine';
    }

    package main;

    my $o = ObjBuilder->new();
    isa_ok $o->engine, 'Engine',
        'builder returning blessed ref preserves class';
    is $o->engine->{type}, 'v8',
        'builder-returned object has correct data';
}
