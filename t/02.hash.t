use Test::More;
use t::Redis;

test_redis {
  my($port) = @_;

  # Use two connections, to ensure we aren't caching locally (very unlikely, we
  # don't cache yet).
  tie my %r_w, "Tie::Redis", port => $port;
  tie my %r_r, "Tie::Redis", port => $port;

  # Top level scalar value
  $r_w{foo} = 42;
  is $r_r{foo}, 42;

  # Hash value
  $r_w{hash} = { a => 16 };
  is $r_r{hash}{a}, 16;

  is_deeply [keys %{$r_r{hash}}], ["a"];

  # List value
  $r_w{list} = [ 1 .. 10 ];
  is_deeply $r_r{list}, [ 1 .. 10];
};
