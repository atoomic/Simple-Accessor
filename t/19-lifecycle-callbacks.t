use strict;
use warnings;

use Test::More tests => 22;

# ===================================================================
# Test edge cases for lifecycle callbacks: _before_build, build(),
# initialize(), and _after_build.  Individual behaviors are tested
# elsewhere; this file focuses on interactions and subtle contracts
# that aren't covered by the other test files.
# ===================================================================

# --- _before_build return value is ignored (unlike _before_* hooks) ---
{
    package BeforeBuildReturnFalse;
    use Simple::Accessor qw{name};

    sub _before_build {
        my ($self, %opts) = @_;
        return 0;  # false -- should be ignored
    }
}

{
    my $obj = BeforeBuildReturnFalse->new(name => 'alice');
    ok $obj, '_before_build returning false does NOT abort construction';
    is $obj->name, 'alice', 'attribute set despite false _before_build return';
}

# --- _before_build receives unknown args (not filtered by strict ctor) ---
{
    package BeforeBuildReceivesAll;
    use Simple::Accessor qw{x};

    my %captured;
    sub _before_build {
        my ($self, %opts) = @_;
        %captured = %opts;
    }
    sub _strict_constructor { 1 }

    sub captured { \%captured }
}

{
    # strict constructor dies on unknown keys, but _before_build fires first
    eval { BeforeBuildReceivesAll->new(x => 1, unknown => 'val') };
    like $@, qr/unknown attribute/, 'strict constructor still rejects unknown attrs';
    is ${ BeforeBuildReceivesAll->captured() }{unknown}, 'val',
        '_before_build received the unknown key before strict ctor check';
    is ${ BeforeBuildReceivesAll->captured() }{x}, 1,
        '_before_build received the known key too';
}

# --- _before_build can set attributes via accessor ---
{
    package BeforeBuildSetsAttr;
    use Simple::Accessor qw{priority label};

    sub _before_build {
        my ($self, %opts) = @_;
        $self->priority('low');  # set via accessor
    }
}

{
    # constructor arg overwrites _before_build value
    my $obj = BeforeBuildSetsAttr->new(priority => 'high', label => 'test');
    is $obj->priority, 'high',
        'constructor arg overwrites value set by _before_build';
    is $obj->label, 'test', 'other attr set normally';

    # without constructor arg, _before_build value survives
    my $obj2 = BeforeBuildSetsAttr->new(label => 'other');
    is $obj2->priority, 'low',
        '_before_build value preserved when no constructor arg given';
}

# --- _after_build can read attributes set by constructor ---
{
    package AfterBuildReadsAttrs;
    use Simple::Accessor qw{first last_name full};

    sub _after_build {
        my ($self, %opts) = @_;
        $self->full($self->first . ' ' . $self->last_name)
            if defined $self->first && defined $self->last_name;
    }
}

{
    my $obj = AfterBuildReadsAttrs->new(first => 'Jane', last_name => 'Doe');
    is $obj->full, 'Jane Doe',
        '_after_build can read and combine attrs set by constructor';
}

# --- _after_build triggers accessor hooks normally ---
{
    package AfterBuildWithHooks;
    use Simple::Accessor qw{status log_entry};

    my @hook_log;
    sub _after_build {
        my ($self, %opts) = @_;
        $self->status('ready');  # triggers _before_status, _validate_status
    }

    sub _validate_status {
        my ($self, $v) = @_;
        push @hook_log, "validate:$v";
        return 1;
    }

    sub _after_status {
        my ($self, $v) = @_;
        push @hook_log, "after:$v";
        return 1;
    }

    sub hook_log { [@hook_log] }
}

{
    @{ AfterBuildWithHooks->hook_log() } = ();
    my $obj = AfterBuildWithHooks->new();
    is $obj->status, 'ready', '_after_build set status via accessor';
    my $log = AfterBuildWithHooks->hook_log();
    ok( (grep { $_ eq 'validate:ready' } @$log),
        '_validate_status fired during _after_build' );
    ok( (grep { $_ eq 'after:ready' } @$log),
        '_after_status fired during _after_build' );
}

# --- build() callback triggers accessor hooks ---
{
    package BuildWithHooks;
    use Simple::Accessor qw{score};

    my @build_hook_log;
    sub build {
        my ($self, %opts) = @_;
        $self->score(100);  # triggers hooks
        return 1;
    }

    sub _validate_score {
        my ($self, $v) = @_;
        push @build_hook_log, "validate:$v";
        return $v <= 100 ? 1 : 0;
    }

    sub build_hook_log { [@build_hook_log] }
}

{
    @{ BuildWithHooks->build_hook_log() } = ();
    my $obj = BuildWithHooks->new();
    is $obj->score, 100, 'build() set score via accessor';
    my $log = BuildWithHooks->build_hook_log();
    ok( (grep { $_ eq 'validate:100' } @$log),
        '_validate_score fired during build()' );
}

# --- Exception in _before_build propagates ---
{
    package BeforeBuildDies;
    use Simple::Accessor qw{val};

    sub _before_build {
        die "before_build error\n";
    }
}

{
    my $obj = eval { BeforeBuildDies->new(val => 1) };
    is $obj, undef, 'exception in _before_build prevents object creation';
    is $@, "before_build error\n", 'exception message propagates from _before_build';
}

# --- Exception in build() propagates ---
{
    package BuildDies;
    use Simple::Accessor qw{val};

    sub build {
        die "build error\n";
    }
}

{
    my $obj = eval { BuildDies->new(val => 1) };
    is $obj, undef, 'exception in build() prevents object creation';
    is $@, "build error\n", 'exception message propagates from build()';
}

# --- Exception in _after_build propagates ---
{
    package AfterBuildDies;
    use Simple::Accessor qw{val};

    sub _after_build {
        die "after_build error\n";
    }
}

{
    my $obj = eval { AfterBuildDies->new(val => 1) };
    is $obj, undef, 'exception in _after_build prevents object creation';
    is $@, "after_build error\n", 'exception message propagates from _after_build';
}

# --- _after_build return value is ignored ---
{
    package AfterBuildReturnFalse;
    use Simple::Accessor qw{data};

    sub _after_build {
        my ($self, %opts) = @_;
        return 0;  # false -- should be ignored
    }
}

{
    my $obj = AfterBuildReturnFalse->new(data => 'value');
    ok $obj, '_after_build returning false does NOT abort construction';
    is $obj->data, 'value', 'attribute preserved despite false _after_build return';
}
