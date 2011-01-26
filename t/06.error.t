use Test::More tests => 1;
use Tie::Redis;

tie my %r, "Tie::Redis", port => 3; # hopefully nothing running here..
my $x = eval { $r{a} };
like $@, qr/Can't connect Redis server/;

