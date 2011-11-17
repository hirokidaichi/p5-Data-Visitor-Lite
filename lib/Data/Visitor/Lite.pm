package Data::Visitor::Lite;
use strict;
use warnings;
use Carp qw/croak/;
use Scalar::Util qw/blessed/;
use List::MoreUtils qw/all/;

our $VERSION = '0.01';

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
    my ( $self, $target ) = @_;

    return $self->replace($target) unless ref $target;
    return $self->_visit_array($target) if ref $target eq 'ARRAY';
    return $self->_visit_hash($target)  if ref $target eq 'HASH';

    return $self->replace($target);
}

sub replace {
    my ( $self, $value ) = @_;
    return $self->{replacer}->($value);
}
sub _visit_array {
    my ( $self, $target ) = @_;
    return [ map { $self->visit($_) } @$target ];
}

sub _visit_hash {
    my ( $self, $target ) = @_;
    return { map { $_ => $self->visit( $target->{$_} ) } keys %$target };
}

1;
__END__

=head1 NAME

Data::Visitor::Lite -

=head1 SYNOPSIS

  use Data::Visitor::Lite;

    my $visitor = Data::Visitor::Lite->new([
         'Hoge::Fuga'     => sub { } ,
         'Text::Template' => sub { } ,
          sub {}
    ]);

=head1 DESCRIPTION

Data::Visitor::Lite is

=head1 AUTHOR

Default Name E<lt>default {at} example.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
