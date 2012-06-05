package Simple::Accessor;
use strict;
use warnings;

# ABSTRACT: a light and simple way to provide accessor in perl

=head1 NAME
Simple::Accessor - light and simple accessor

=head1 DESCRIPTION

Simple::Accessor provides a simple object layer without any dependency.
It can be used where other ORM could be considered too heavy.

=head1 Usage

    package MyClass;
    # that s all what you need ! no more line needed
    use Simple::Accessor qw{foo bar cherry apple};
    
    package main;    
    # you can now create object with these attributes    
    my $o = MyClass->new(bar => 42);
    is $o->bar(), 42;
    
    # you can also get / set any value
    $o->bar(51);
    is $o->bar(), 51;
    
    # you can provide your own init method that will be call by new
    sub initialize {
        my ($self, %opts) = @_;
        
        $self->foo(12345);
    }

    # you can use individual initializers
    sub _initialize_bar {
        # will be used if no value has been provided for bar
        1031
    }

    # you can even use a basic hook system
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
    
=head2 Implement your own logic


=head1 METHODS

=cut

sub import {
    my ( $class, @attr ) = @_;

    my $from = caller();

    _add_new($from);
    _add_accessors( to => $from, attributes => \@attr );
}

sub _add_new {
    my $class = shift;
    return unless $class;

    my $init = 'initialize';
    my $new  = $class . '::new';
    {
        no strict 'refs';
        *$new = sub {
            my ( $class, %opts ) = @_;

            my $self = bless {}, $class;

            # set values if attributes exist
            map {
                eval { $self->$_( $opts{$_} ) }
            } keys %opts;

            if ( defined &{ $class . '::' . $init } ) {
                return unless $self->$init(%opts);
            }

            return $self;
        };
    }
}

sub new {
    my ( $class, %opts ) = @_;

    my $self = bless {}, __PACKAGE__;

    $self->_init(%opts);

    return $self;
}

sub _add_accessors {
    my (%opts) = @_;

    return unless $opts{to};
    my @attributes = @{ $opts{attributes} };
    return unless @attributes;

    foreach my $att (@attributes) {
        my $accessor = $opts{to} . "::$att";

        # allow symbolic refs to typeglob
        no strict 'refs';
        *$accessor = sub {
            my ( $self, $v ) = @_;
            if ( defined $v ) {
                foreach (qw{before validate set after}) {
                    if ( $_ eq 'set' ) {
                        $self->{$att} = $v;
                        next;
                    }
                    my $sub = '_' . $_ . '_' . $att;
                    if ( defined &{ $opts{to} . '::' . $sub } ) {
                        return unless $self->$sub($v);
                    }
                }
            }
            elsif ( !defined $self->{$att} ) {

                # try to initialize the value
                my $sub = '_' . 'initialize' . '_' . $att;
                if ( defined &{ $opts{to} . '::' . $sub } ) {
                    $self->{$att} = $self->$sub();
                }
            }

            return $self->{$att};
        };
    }
    @attributes = ();
}

1;

__END__
