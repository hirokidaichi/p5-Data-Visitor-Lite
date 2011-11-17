use strict;
use warnings;
use Data::Dump qw/pp/;
use Test::More;
use Data::Visitor::Lite;
{

    package T::X01;
    sub new { bless {}, shift }

    sub to_plain_object {
        return { hello => 1, };
    }
}
{

    package T::X02;
    use base qw/T::X01/;
    sub to_plain_object {
        return { hello => 'x02', };
    }
}
{
    my $dbl = Data::Visitor::Lite->new(
        sub {
            my ($target) = @_;
            return $target + 1;
        }
    );

    ::ok $dbl;

    my $result = $dbl->visit(
        {   test  => 1,
            hello => [ 1, 2, 3, 4 ]
        }
    );
    ::is_deeply( $result, { hello => [ 2, 3, 4, 5 ], test => 2 } );
}

{
    my $dbl = Data::Visitor::Lite->new(
        [   -implements => ['to_plain_object'] =>
                sub { $_[0]->to_plain_object; }
        ],
        [   -implements => ['to_plain_object'] =>
                sub { $_[0]->to_plain_object; }
        ],
        [ -plain => sub { $_[0] + 1 } ],
    );

    ::ok $dbl;
    ::is $dbl->replace(10), 11;
    ::is_deeply( $dbl->replace( T::X01->new ), { hello => 1 } );
    my $result = $dbl->visit(
        {   test  => 1,
            hello => [ 1, 2, 3, 4 ],
            hoge  => T::X01->new
        }
    );
    ::is_deeply( $result,
        { hello => [ 2, 3, 4, 5 ], hoge => { hello => 1 }, test => 2 },
    );
}
{
    my $dbl = Data::Visitor::Lite->new(
        [   -isa => 'T::X01' =>
                sub { $_[0]->to_plain_object; }
        ],
        [ -plain => sub { $_[0] + 1 } ],
    );

    ::ok $dbl;
    ::is $dbl->replace(10), 11;
    ::is_deeply( $dbl->replace( T::X02->new ), { hello => 'x02' } );
    my $result = $dbl->visit(
        {   test  => 1,
            hello => [ 1, 2, 3, 4 ],
            hoge  => T::X02->new
        }
    );
    ::is_deeply( $result,
        { hello => [ 2, 3, 4, 5 ], hoge => { hello => 'x02' }, test => 2 },
    );
}
{
    my $deep = 10;
    $deep = [$deep] for (1..100);
    my $v = Data::Visitor::Lite->new(sub{$_[0]+10});
    my $result = $v->visit($deep);
    $result = $result->[0] for (1..100);
    is($result,20);
}
{
    my $ref1 = { hello => 1, world => 2};
    my $ref2 = { moga => 3 ,piyo => 4};
    $ref1->{ref} = $ref2;
    $ref2->{ref} = $ref1;
    my $v = Data::Visitor::Lite->new(sub{$_[0]+10});
    my $result =  $v->visit($ref2);
    ::is($result->{moga},$ref2->{moga}+10);
    ::is($result->{piyo},$ref2->{piyo}+10);
    ::is($result->{ref}{hello},$ref2->{ref}{hello}+10);
    ::is($result->{ref}{ref}{piyo},$ref2->{ref}{ref}{piyo}+10);

}
::done_testing;
