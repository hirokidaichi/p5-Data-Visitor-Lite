package Data::Visitor::Lite;
use strict;
use warnings;
no warnings 'recursion';
use Carp qw/croak/;
use Scalar::Util qw/blessed refaddr/;
use List::MoreUtils qw/all/;

our $VERSION = '0.02';

our $REPLACER_GENERATOR = {
    '-implements' => sub {
        my ( $args, $code ) = @_;
        return sub {
            my $value = shift;
            return $value unless ref $value;
            return $value unless blessed $value;
            return $value unless all { $value->can($_) } @$args;
            return $code->($value);
        };
    },
    '-isa' => sub {
        my ( $args, $code ) = @_;
        return sub {
            my $value = shift;
            return $value unless ref $value;
            return $value unless blessed $value;
            return $value unless $value->isa($args);
            return $code->($value);
        };
    },
    '-plain' => sub {
        my ($code) = @_;
        return sub {
            my ($value) = shift;
            return $value if ref $value;
            return $value if blessed $value;
            return $code->($value);
        }
    },
};


sub new {
    my ( $class, @replacers ) = @_;
    return bless {
        replacer => __compose_replacers(@replacers)
    }, $class;
}

sub __compose_replacers {
    my (@replacers) = @_;
    my @codes = map { __compose_replacer($_) } @replacers;
    return sub {
        my ($value) = @_;
        for my $code (@codes) {
            $value = $code->($value);
        }
        return $value;
    };
}

sub __compose_replacer {
    my ( $replacer ) = @_;
    return sub { $_[0] }
        unless defined $replacer;
    return $replacer 
        unless ref $replacer;
    return $replacer 
        if ref $replacer eq 'CODE';

    croak('replacer should not be hash ref')
        if ref $replacer eq 'HASH';

    my ($type,$args,$code) = @$replacer;
    my $generator = $REPLACER_GENERATOR->{$type} || sub{
        croak('undefined replacer type');
    };

    return $generator->($args,$code);
}

sub visit {
    my ( $self ,$target ) = @_;
    $self->{seen} = {};
    return $self->_visit( $target );
}

sub _visit {
    my ( $self, $target ) = @_;
    goto \&replace unless ref $target;
    goto \&_visit_array if ref $target eq 'ARRAY';
    goto \&_visit_hash  if ref $target eq 'HASH';
    goto \&replace;
}

sub replace {
    my ( $self, $value ) = @_;
    return $self->{replacer}->($value);
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
    %$new_hash = map { $_ => $self->_visit( $target->{$_} ) } keys %$target;
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
        [-isa => 'Some::SuperClass' => sub{$_[0]->encode_to_utf8}]

        # '-plain' replace type means only replace 
        #   when an object is not a reference|blessed value 
        [-plain => sub{ $_[0]+1}]

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
