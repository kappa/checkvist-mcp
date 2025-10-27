package App::CheckvistMCP::Auth;
use Mojo::Base -base, -signatures;

use App::CheckvistMCP::Error;
use Mojo::URL;
use Mojo::UserAgent;

has base_uri => sub { Mojo::URL->new('https://checkvist.com') };
has ua       => sub { Mojo::UserAgent->new };
has auth     => sub { {} };
has token_ttl => 20 * 60 * 60;    # 20 hours cache window
has _token;
has _token_obtained_at => 0;

sub ensure_token ($self) {
  if (my $static = $self->auth->{token}) {
    return $static;
  }

  if (my $cached = $self->_token) {
    my $obtained = $self->_token_obtained_at // 0;
    my $age      = time - $obtained;
    return $cached if $age < $self->token_ttl;
  }

  my $token = $self->_login;
  $self->_token($token);
  $self->_token_obtained_at(time);

  return $token;
}

sub invalidate_cached_token ($self) {
  $self->_token(undef);
  $self->_token_obtained_at(0);
  return;
}

sub _login ($self) {
  my $auth = $self->auth;
  my $username = $auth->{username};
  my $secret   = defined $auth->{remote_key} && length $auth->{remote_key}
    ? {remote_key => $auth->{remote_key}}
    : defined $auth->{password} && length $auth->{password}
    ? {password => $auth->{password}}
    : undef;

  App::CheckvistMCP::Error->throw(
    code    => 'auth_failed',
    message => 'Checkvist username and remote_key/password are required for login'
  ) unless $username && $secret;

  my %form = (username => $username, %{$secret});
  if (defined(my $twofa = $auth->{token2fa}) && length $twofa) {
    $form{token2fa} = $twofa;
  }

  my $url = $self->_url_for('auth/login.json');
  $url->query(version => 2);

  my $tx = $self->ua->post($url => {Accept => 'application/json'} => form => \%form);
  my $res = $tx->result;

  unless ($res->is_success) {
    my $status = $res->code // 500;
    my $message = $status =~ /^(?:401|403)$/ ? 'Failed to authenticate with Checkvist'
      : sprintf 'Checkvist login failed: %s', $res->message // 'unknown error';
    App::CheckvistMCP::Error->throw(code => ($status =~ /^(?:401|403)$/ ? 'auth_failed' : 'upstream_error'), message => $message, status => $status);
  }

  my $data = $res->json;
  unless (ref $data eq 'HASH' && $data->{token}) {
    App::CheckvistMCP::Error->throw(
      code    => 'upstream_error',
      message => 'Checkvist login response did not include a token',
      status  => 500
    );
  }

  return $data->{token};
}

sub _url_for ($self, $path) {
  my $url = $self->base_uri->clone;
  $url->path($path);
  return $url;
}

1;

__END__

=encoding utf8

=head1 NAME

App::CheckvistMCP::Auth - Manage authentication against the Checkvist API

=head1 DESCRIPTION

Handles token acquisition and caching for Checkvist API calls.

=cut
