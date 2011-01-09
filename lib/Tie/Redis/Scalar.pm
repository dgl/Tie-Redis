package Tie::Redis::Scalar;

# Consider using overload instead of this maybe, could then implement things
# like ++ in terms of Redis commands.

sub TIESCALAR {
  my($class, %args) = @_;
  bless \%args, $class;
}

sub _cmd {
  my($self, $cmd, @args) = @_;
  return $self->{redis}->_cmd($cmd, $self->{key}, @args);
}

sub FETCH {
  my($self) = @_;
  $self->_cmd("get");
}

sub STORE {
  my($self, $value) = @_;
  $self->_cmd("set", $value);
}

1;

=head1 NAME

Tie::Redis::Scalar - Connect a Redis key to a Perl scalar

=head1 SYNOPSIS

=cut
