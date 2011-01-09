package Tie::Redis::List;

sub TIEARRAY {
  my($class, %args) = @_;
  bless \%args, $class;
}

sub _cmd {
  my($self, $cmd, @args) = @_;
  return $self->{redis}->_cmd($cmd, $self->{key}, @args);
}

sub FETCH {
  my($self, $i) = @_;
  $self->_cmd(lindex => $i);
}

sub FETCHSIZE {
  my($self) = @_;
  $self->_cmd("llen");
}

sub PUSH {
  my($self, @elements) = @_;
  $self->_cmd(rpush => $_) for @elements;
}

sub EXTEND {
}

sub STORE {
  my($self, $index, $value) = @_;
  my $len = $self->_cmd("llen");
  if($index >= $len) {
    while($index > $len) {
      $self->_cmd(rpush => "");
      $len++;
    }
    $self->_cmd(rpush => $value);
  } else {
    $self->_cmd(lset => $index, $value);
  }
}

sub CLEAR {
  my($self) = @_;
  $self->_cmd("del");
}

1;

=head1 NAME

Tie::Redis::List - Connect a Redis list to a Perl array

=head1 SYNOPSIS

=cut
