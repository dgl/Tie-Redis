package Tie::Redis;
# ABSTRACT: Connect perl data structures to Redis
use strict;
use parent qw(AnyEvent::Redis);
use Carp ();

use Tie::Redis::Hash;
use Tie::Redis::List;
use Tie::Redis::Scalar;

sub TIEHASH {
  my($class, %args) = @_;
  my $serialize = delete $args{serialize};

  my $self = $class->AnyEvent::Redis::new(%args);
  $self->{serialize} = $self->_serializer($serialize);

  return $self;
}

sub _serializer {
  my($self, $serialize) = @_;

  my %serializers = (
    json => [
      sub { require JSON },
      \&JSON::to_json,
      \&JSON::from_json
    ],
    storable => [
      sub { require Storable },
      \&Storable::nfreeze,
      \&Storaable::thaw
    ],
    msgpack => [
    ],
  );

  my $serializer = $serializers{$serialize} || [undef, (sub {
    Carp::croak("No serializer specified for Tie::Redis; unable to handle nested structures");
  }) x 2];

  # Load; will error if required module isn't present
  $serializer->[0] && $serializer->[0]->();

  return $serializer;
}

sub _cmd {
  my($self, $cmd, @args) = @_;

  if($self->{prefix} && defined $args[0]) {
    $args[0] = "$self->{prefix}$args[0]";
  }

  if($self->{use_recv}) {
    $self->$cmd(@args)->recv;
  } else {
    my $ok = 0;
    my $ret;
    $self->$cmd(@args, sub { $ok = 1; $ret = $_[0] });

    # We need to block, but using ->recv won't work if the program is using
    # ->recv at a higher level, so we do this slight hack.
    # XXX: How to handle errors?
    AnyEvent->one_event until $ok;
    $ret;
  }
}

sub STORE {
  my($self, $key, $value) = @_;

  if(!ref $value) {
    $self->_cmd(set => $key, $value);

  } elsif(ref $value eq 'HASH') {
    # TODO: Should pipeline somehow
    $self->_cmd("multi");
    $self->_cmd(del => $key);
    $self->_cmd(hmset => $key,
          map +($_ => $value->{$_}), keys %$value);
    $self->_cmd("exec");
    $self->{_type_cache}->{$key} = 'hash';

  } elsif(ref $value eq 'ARRAY') {
    $self->_cmd("multi");
    $self->_cmd(del => $key);
    for my $v(@$value) {
      $self->_cmd(rpush => $key, $v);
    }
    $self->_cmd("exec");
    $self->{_type_cache}->{$key} = 'list';

  } elsif(ref $value) {
    $self->_cmd(set => $key, $self->{serialize}->[1]->($value));
  }
}

sub FETCH {
  my($self, $key) = @_;
  my $type = exists $self->{_type_cache}->{$key}
    ? $self->{_type_cache}->{$key}
    : $self->_cmd(type => $key);

  if($type eq 'hash') {
    tie my %h, "Tie::Redis::Hash", redis => $self, key => $key;
    return \%h;
  } elsif($type eq 'list') {
    tie my @l, "Tie::Redis::List", redis => $self, key => $key;
    return \@l;
  } elsif($type eq 'set') {
    die "Sets yet to be implemented...";
  } elsif($type eq 'zset') {
    die "Zsets yet to be implemented...";
  } elsif($type eq 'string') {
    $self->_cmd(get => $key);
  } else {
    return undef;
  }
}

sub FIRSTKEY {
  my($self) = @_;
  my $keys = $self->_cmd(keys => "*");
  $self->{keys} = $keys;
  $self->NEXTKEY;
}

sub NEXTKEY {
  my($self) = @_;
  shift @{$self->{keys}};
}

sub EXISTS {
  my($self, $key) = @_;
  $self->_cmd(exists => $key);
}

sub DELETE {
  my($self, $key) = @_;
  $self->_cmd(del => $key);
}

sub CLEAR {
  my($self, $key) = @_;
  if($self->{prefix}) {
    $self->_cmd(del => $self->_cmd(keys => "*"));
  } else {
    $self->_cmd("flushdb");
  }
}

sub SCALAR {
  my($self) = @_;
  $self->_cmd("dbsize");
}

1;

=head1 SYNOPSIS

 use Tie::Redis;
 tie my %r, "Tie::Redis";

=head1 DESCRIPTION

This allows basic access to Redis from Perl using tie, so it looks just like a
a hash or array.

B<Please> think carefully before using this, the tie interface has quite a
performance overhead and the error handling is not that great. Using
L<AnyEvent::Redis> or L<Redis> directly is recommended.

=head1 SEE ALSO

L<App::redisp> -- a redis shell in Perl and the main reason I wrote this
module. L<AnyEvent::Redis> -- the API this uses to access Redis. L<Redis> --
another Redis API.

=cut

