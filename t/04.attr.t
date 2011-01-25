use t::Redis;
use Test::More;

BEGIN {
  plan skip_all => "Needs Perl >= 5.10.1" unless $^V >= v5.10.1;
  plan tests => 2;
}

BEGIN {
  use_ok "Tie::Redis::Attribute";
}

our $port;
test_redis {
  ($port) = @_;

  tie my %r, "Tie::Redis", port => $port;
  my %special : Redis(port => $port);

  for(1 .. 100) {
    $special{$_} = rand;
  }

  is_deeply \%special, $r{(keys %r)[0]};
};
