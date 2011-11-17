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
    my $dbl = Data::Visitor::Lite->new( [ -number => sub { $_[0] + 1 } ] );

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
        [ -number => sub { $_[0] + 1 } ],
    );

    ::ok $dbl;

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
        [ -instance => 'T::X01' => sub { $_[0]->to_plain_object; } ],
        [ -number   => sub      { $_[0] + 1 } ],
    );

    ::ok $dbl;

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
    $deep = [$deep] for ( 1 .. 100 );
    my $v = Data::Visitor::Lite->new( sub { $_[0] + 10 } );
    my $result = $v->visit($deep);
    $result = $result->[0] for ( 1 .. 100 );
    is( $result, 20 );
}
{
    my $ref1 = { hello => 1, world => 2 };
    my $ref2 = { moga  => 3, piyo  => 4 };
    $ref1->{ref} = $ref2;
    $ref2->{ref} = $ref1;
    my $v = Data::Visitor::Lite->new( [ -number => sub { $_[0] + 10 } ] );

    my $result = $v->visit($ref2);
    ::is( $result->{moga},           $ref2->{moga} + 10 );
    ::is( $result->{piyo},           $ref2->{piyo} + 10 );
    ::is( $result->{ref}{hello},     $ref2->{ref}{hello} + 10 );
    ::is( $result->{ref}{ref}{piyo}, $ref2->{ref}{ref}{piyo} + 10 );
}
our $test;
my $type_and_value = {
    -scalar_ref => do { my $test; \$test },
    -code_ref  => sub { },
    -glob_ref  => \*test,
    -regex_ref => qr/a/,
    -invocant  => 'Data::Visitor::Lite',
    -value     => 'value',
    -number    => 10.1,
    -integer   => 1,
};

{
    for my $type ( keys %$type_and_value ) {
        my $v = Data::Visitor::Lite->new( [ $type => sub {'TRUE'} ] );
        my $r = $v->visit( { test => $type_and_value->{$type} } );
        is_deeply( $r, { test => "TRUE" }, $type );
    }
}
{
    my $v = Data::Visitor::Lite->new(map{[$_ => sub{'TRUE'.$_}]} keys %$type_and_value);
    my $r = $v->visit(
        $type_and_value
    );
    is_deeply(
        $r,
        {   "-code_ref"   => "TRUE-code_ref",
            "-glob_ref"   => "TRUE-glob_ref",
            "-integer"    => "TRUE-integer",
            "-invocant"   => "TRUE-invocant",
            "-number"     => "TRUE-number",
            "-regex_ref"  => "TRUE-regex_ref",
            "-scalar_ref" => "TRUE-scalar_ref",
            "-value"      => "TRUE-value",
        }
    );
}
::done_testing;
