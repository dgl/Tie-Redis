package Tie::Redis::Connection;
# ABSTRACT: Connection to Redis
use strict;
use warnings;
use IO::Socket::IP;
use Protocol::Redis;
use Carp ();

use constant DEBUG => $ENV{TIE_REDIS_DEBUG};
use constant PR_CLASS => eval { require Protocol::Redis::XS; 1 }
    ? "Protocol::Redis::XS" : "Protocol::Redis";

our $AUTOLOAD;

sub new {
  my($class, %args) = @_;

  my $host = delete $args{host} || 'localhost';
  my $port = delete $args{port} || 6379;

  if (my $encoding = $args{encoding}) {
    $args{encoding} = Encode::find_encoding($encoding);
    Carp::croak qq{Encoding "$encoding" not found} unless ref $args{encoding};
  }

  bless {
    _sock => (IO::Socket::IP->new("$host:$port") || return),
    _pr   => PR_CLASS->new(api => 1),
    host  => $host,
    port  => $port,
    %args,
  }, $class;
}

sub DESTROY { }

sub AUTOLOAD {
  my $self = shift;
  (my $method = $AUTOLOAD) =~ s/.*:://;
  $self->_cmd($method, @_);
}

sub _cmd {
  my($self, $cmd, @args) = @_;

  warn "TR>> $cmd @args\n" if DEBUG;

  $self->{_sock}->syswrite(
    $self->{_pr}->encode({type => "*", data => [
      map +{ type => '$', data => $_ }, $cmd, @args
    ]})
  ) or return;
  
  my $message;
  do {
    $self->{_sock}->sysread(my $buf, 8192) or return;
    $self->{_pr}->parse($buf);
    $message = $self->{_pr}->get_message;
  } while not $message;

  if($message->{type} eq '*') {
    warn "TR<< ", (join " ", map $_->{data}, @{$message->{data}}), "\n" if DEBUG;
    [map $_->{data}, @{$message->{data}}];
  } else {
    warn "TR<< $message->{data}\n" if DEBUG;
    $message->{data};
  }
}

1;
