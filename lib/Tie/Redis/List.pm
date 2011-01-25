package Tie::Redis::List;
# ABSTRACT: Connect a Redis list to a Perl array

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

sub POP {
  my($self) = @_;
  $self->_cmd("rpop");
}

sub SHIFT {
  my($self) = @_;
  $self->_cmd("lpop");
}

sub UNSHIFT {
  my($self, $value) = @_;
  $self->_cmd(lpush => $value);
}

sub SPLICE {
  my($self, $offset, $length, @list) = @_;

  my @items = $length == 0 ? () : $self->_cmd(lrange => $offset, $length - 1);
  $self->_cmd(ltrim => $offset, $offset + $length - 1) if $length > 0;
  # XXX
}

sub CLEAR {
  my($self) = @_;
  $self->_cmd("del");
}

1;

=head1 SYNOPSIS

=cut
