package App::CheckvistMCP::Lists;
use Mojo::Base -base, -signatures;

use App::CheckvistMCP::Error;
use Mojo::URL;
use Mojo::UserAgent;

has base_uri => sub { Mojo::URL->new('https://checkvist.com') };
has ua       => sub { Mojo::UserAgent->new };

sub get_lists ($self, $token, $params = {}) {
  App::CheckvistMCP::Error->throw(
    code    => 'auth_failed',
    message => 'Checkvist token is required'
  ) unless defined $token && length $token;

  my $url = $self->_url_for('checklists.json');
  my %query;
  if ($params->{archived}) {
    $query{archived} = 'true';
  }
  if (defined $params->{order} && length $params->{order}) {
    $query{order} = $params->{order};
  }
  if ($params->{skip_stats}) {
    $query{skip_stats} = 'true';
  }
  $url->query(%query ? \%query : undef);

  my $tx = $self->ua->get($url => {Accept => 'application/json', 'X-Client-Token' => $token});
  my $res = $tx->result;

  unless ($res->is_success) {
    my $status  = $res->code // 500;
    my $message = $res->message // 'unknown error';
    my $code    = ($status && $status =~ /^(?:401|403)$/) ? 'auth_failed' : 'upstream_error';
    App::CheckvistMCP::Error->throw(code => $code, message => "Checkvist returned $message", status => $status);
  }

  my $data = $res->json;
  unless (ref $data eq 'ARRAY') {
    App::CheckvistMCP::Error->throw(
      code    => 'upstream_error',
      message => 'Checkvist returned an unexpected payload',
      status  => 500
    );
  }

  return $data;
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

App::CheckvistMCP::Lists - Fetch Checkvist lists for the authenticated user

=head1 DESCRIPTION

Wraps the C</checklists.json> endpoint and returns decoded JSON data.

=cut
