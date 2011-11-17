package Data::Visitor::Lite;
use strict;
use warnings;
no warnings 'recursion';
use Carp qw/croak/;
use Data::Util qw/:check/;
use Scalar::Util qw/blessed refaddr/;
use List::MoreUtils qw/all/;

use constant AS_HASH_KEY => 1;
our $VERSION = '0.02_1';

our $REPLACER_GENERATOR = {
    # only blessed value
    '-object' => sub {
        my ($code) = shift;
        return sub {
            my $value = shift;
            return $value unless blessed $value;
            return $code->($value);
        };
    },
    # only blessed value and implements provided methods
    '-implements' => sub {
        my ( $args, $code ) = @_;
        return sub {
            my $value = shift;
            return $value unless blessed $value;
            return $value unless all { $value->can($_) } @$args;
            return $code->($value);
        };
    },
    # only blessed value and sub-class of provided package
    '-instance' => sub {
        my ( $args, $code ) = @_;
        return sub {
            my $value = shift;
            return $value unless Data::Util::is_instance( $value, $args );
            return $code->($value);
        };
    },
    # only hash key
    '-hashkey' => sub {
        my ($code) = @_;
        return sub {
            my ( $value, $as_hash_key ) = @_;
            return $value unless $as_hash_key;
            return $code->($value);
        };
    },
    # only all string with hash keys
    '-string' => sub {
        my ($code) = @_;
        return sub {
            my ( $value, $as_hash_key ) = @_;
            return $value unless Data::Util::is_string($value);
            return $code->($value);
        }
    },
    # list up other types
    &__other_types,
};

sub __other_types {
    my @types = qw/
        scalar_ref
        array_ref
        hash_ref
        code_ref
        glob_ref
        regex_ref
        invocant
        value
        number
        integer
    /;
    return map{__create_by_type($_)} @types;
}

sub __create_by_type {
    my $type = shift;
    return (
        "-$type" => sub {
            my ($code) = @_;
            my $checker = Data::Util->can("is_$type");
            return sub {
                my ( $value, $as_hash_key ) = @_;
                return $value if $as_hash_key;
                return $value unless $checker->($value);
                return $code->($value);
            }
        }
    );
}

sub new {
    my ( $class, @replacers ) = @_;
    return bless { replacer => __compose_replacers(@replacers) }, $class;
}

sub __compose_replacers {
    my (@replacers) = @_;
    my @codes = map { __compose_replacer($_) } @replacers;
    return sub {
        my ( $value, $as_hash_key ) = @_;
        for my $code (@codes) {
            $value = $code->( $value, $as_hash_key );
        }
        return $value;
    };
}

sub __compose_replacer {
    my ($replacer) = @_;
    return sub { $_[0] }
        unless defined $replacer;
    return $replacer
        unless ref $replacer;
    return $replacer
        if ref $replacer eq 'CODE';

    croak('replacer should not be hash ref')
        if ref $replacer eq 'HASH';

    my ( $type, $args, $code ) = @$replacer;
    my $generator = $REPLACER_GENERATOR->{$type} || sub {
        croak('undefined replacer type');
    };

    return $generator->( $args, $code );
}

sub visit {
    my ( $self, $target ) = @_;
    $self->{seen} = {};
    return $self->_visit($target);
}

sub _visit {
    my ( $self, $target ) = @_;
    goto \&_replace unless ref $target;
    goto \&_visit_array if ref $target eq 'ARRAY';
    goto \&_visit_hash  if ref $target eq 'HASH';
    goto \&_replace;
}

sub _replace {
    my ( $self, $value, $as_hash_key ) = @_;
    return $self->{replacer}->( $value, $as_hash_key );
}

sub _visit_array {
    my ( $self, $target ) = @_;
    my $addr = refaddr $target;
    return $self->{seen}{$addr}
        if defined $self->{seen}{$addr};
    my $new_array = $self->{seen}{$addr} = [];
    @$new_array = map { $self->_visit($_) } @$target;
    return $new_array;
}

sub _visit_hash {
    my ( $self, $target ) = @_;
    my $addr = refaddr $target;
    return $self->{seen}{$addr} if defined $self->{seen}{$addr};
    my $new_hash = $self->{seen}{$addr} = {};
    %$new_hash = map {
        $self->_replace( $_, AS_HASH_KEY ) => $self->_visit( $target->{$_} )
    } keys %$target;
    return $new_hash;
}

1;
__END__

=head1 NAME

Data::Visitor::Lite - an easy implementation of Data::Visitor::Callback

=head1 SYNOPSIS

    use Data::Visitor::Lite;
    my $visitor = Data::Visitor::Lite->new($replacer);

    my $value = $visitor->visit({ 
      # some structure
    });

=head1 DESCRIPTION

Data::Visitor::Lite is an easy implementation of Data::Visitor::Callback

=head1 new(@replacers)

this is a constructor of Data::Visitor::Lite.

    my $visitor = Data::Visitor::Lite->new(
        # '-implements' replacer type means only replace 
        #   when an object can implements provided methods
        [-implements => ['to_plain_object'] => sub {$_[0]->to_plain_object}],

        # '-isa' replace type means only replace 
        #   when an object is a sub-class of provided package,
        [-instance => 'Some::SuperClass' => sub{$_[0]->encode_to_utf8}]

        # '-number' replace type means only replace 
        [-value => sub{ $_[0]+1}]

    );

    my $value = $visitor->visit({ something });

=head1 AUTHOR

Daichi Hiroki E<lt>hirokidaichi {at} gmail.comE<gt>

=head1 SEE ALSO

L<Data::Visitor::Callback>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
