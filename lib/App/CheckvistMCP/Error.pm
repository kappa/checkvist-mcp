package App::CheckvistMCP::Error;
use Mojo::Base -base, -signatures;

has [qw(code message status meta)];

use overload q{""} => sub ($self) { $self->message // '' }, fallback => 1;

sub throw ($class, @args) {
  die $class->new(@args);
}

1;

__END__

=encoding utf8

=head1 NAME

App::CheckvistMCP::Error - Lightweight error object for tool failures

=head1 SYNOPSIS

  use App::CheckvistMCP::Error;

  App::CheckvistMCP::Error->throw(code => 'auth_failed', message => 'Missing token');

=head1 DESCRIPTION

Encapsulates structured error information that can be converted into an MCP
error response.

=cut
