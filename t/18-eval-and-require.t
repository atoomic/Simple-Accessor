use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More tests => 17;

# Test that mro is loaded at compile time (not per-call) and
# that with() uses block eval instead of string eval for require.

# --- mro loaded at compile time ---

# Simple hierarchy using SA attributes + inheritance
{
    package MroParent;
    use Simple::Accessor qw{alpha};
    sub _build_alpha { 'from_parent' }
}

{
    package MroChild;
    our @ISA = ('MroParent');
    use Simple::Accessor qw{beta};
    sub _build_beta { 'from_child' }
}

{
    my $obj = MroChild->new();
    is $obj->alpha, 'from_parent', 'inherited builder works (mro loaded at compile time)';
    is $obj->beta,  'from_child',  'own builder works';
}

# Constructor recognizes parent attrs via MRO
{
    my $obj = MroChild->new(alpha => 'set', beta => 'also_set');
    is $obj->alpha, 'set',      'parent attr set via child constructor';
    is $obj->beta,  'also_set', 'child attr set via constructor';
}

# --- block eval for role require ---

# Role loaded via with() (uses :: in name, exercises path conversion)
{
    package BlockEvalConsumer;
    use Simple::Accessor qw{own_attr};
    with 'Role::Age';
}

{
    my $obj = BlockEvalConsumer->new(age => 25, own_attr => 'test');
    is $obj->age,      25,     'role attr from with() works (block eval require)';
    is $obj->own_attr, 'test', 'own attr works alongside role';
}

# Role with nested :: namespace
{
    package Deep::Role::Example;
    use Simple::Accessor qw{depth};
    sub _build_depth { 3 }
}

{
    package DeepConsumer;
    use Simple::Accessor qw{surface};
    with 'Deep::Role::Example';
}

{
    my $obj = DeepConsumer->new();
    is $obj->depth,   3,     'deeply namespaced role loads correctly';
    is $obj->surface, undef, 'own attr defaults to undef';
}

# --- error handling in block eval ---

# Requiring a non-existent module should die with useful message
{
    package BadConsumer;
    use Simple::Accessor qw{x};

    eval { with('Nonexistent::Module::XYZ123') };
    ::like $@, qr/Can't locate/, 'non-existent module dies with require error';
}

# Invalid module name still caught by regex validation
{
    package BadName;
    use Simple::Accessor qw{y};

    eval { with('not a module!') };
    ::like $@, qr/Invalid module name/, 'invalid module name caught by validation';
}

# --- inline role (skip require) still works ---

{
    package InlineRole;
    use Simple::Accessor qw{inline_attr};
    sub _build_inline_attr { 'inline' }
}

{
    package InlineConsumer;
    use Simple::Accessor qw{z};
    with 'InlineRole';
}

{
    my $obj = InlineConsumer->new();
    is $obj->inline_attr, 'inline', 'inline role (no file) works without require';
    is $obj->z,           undef,    'own attr works with inline role';
}

# --- MRO with multiple inheritance ---

{
    package MroBase1;
    use Simple::Accessor qw{b1_attr};
    sub _build_b1_attr { 'base1' }
}

{
    package MroBase2;
    use Simple::Accessor qw{b2_attr};
    sub _build_b2_attr { 'base2' }
}

{
    package MroMulti;
    our @ISA = ('MroBase1', 'MroBase2');
    use Simple::Accessor qw{multi_attr};
}

{
    my $obj = MroMulti->new(b1_attr => 'a', b2_attr => 'b', multi_attr => 'c');
    is $obj->b1_attr,    'a', 'first parent attr via constructor';
    is $obj->b2_attr,    'b', 'second parent attr via constructor';
    is $obj->multi_attr, 'c', 'own attr via constructor';
}

# Builder from both parents fire correctly
{
    my $obj = MroMulti->new();
    is $obj->b1_attr, 'base1', 'first parent builder fires';
    is $obj->b2_attr, 'base2', 'second parent builder fires';
}
