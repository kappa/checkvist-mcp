package App::CheckvistMCP;
use Mojo::Base 'Mojolicious', -signatures;

use App::CheckvistMCP::Tools;
use Mojo::File      qw(path);
use Mojo::Util      qw(secure_compare);

our $VERSION = '0.01';

sub startup ($self) {
  $self->moniker('checkvist-mcp');

  my $config = $self->_build_config;
  $self->helper(checkvist_config => sub { $config });

  if (my $level = $config->{log_level}) {
    $self->log->level($level);
  }

  my $admin_token = $config->{mcp_admin_token};
  $self->log->warn('MCP_ADMIN_TOKEN is not configured; requests will be rejected')
    unless $admin_token;

  $self->hook(
    before_dispatch => sub ($c) {
      my $path = $c->req->url->path->to_string // '';
      return unless $path =~ m{^/mcp(?:/|\z)};

      my $header = $c->req->headers->authorization // '';
      my ($token) = $header =~ /^Bearer\s+(.+)$/;
      my $authorized = $admin_token && $token && secure_compare($token, $admin_token);

      unless ($authorized) {
        $c->res->headers->www_authenticate('Bearer realm="checkvist-mcp"');
        $c->render(status => 401, json => {
          error => {code => 'unauthorized', message => 'Missing or invalid MCP admin token'}
        });
        $c->rendered;
        return;
      }
    }
  );

  my $server = App::CheckvistMCP::Tools->build_server($self, $config);
  my $action = $server->to_action;
  $self->routes->any('/mcp')->to(cb => sub ($c) { $action->($c) });
}

sub _build_config ($self) {
  my $yaml = $self->_load_yaml_config;

  my $config = {
    base_uri        => 'https://checkvist.com',
    log_level       => $ENV{LOG_LEVEL},
    mcp_admin_token => $ENV{MCP_ADMIN_TOKEN},
    auth            => {},
  };

  if ($yaml && ref $yaml eq 'HASH') {
    $config->{base_uri}        = $yaml->{base_uri}        if $yaml->{base_uri};
    $config->{mcp_admin_token} = $yaml->{mcp_admin_token} if $yaml->{mcp_admin_token};
    if (my $auth = $yaml->{auth}) {
      $config->{auth} = { %{$auth} };
    }
  }

  $config->{base_uri} = $ENV{CV_BASE_URI} if $ENV{CV_BASE_URI};

  my $auth = $config->{auth} //= {};
  for my $key (
    [token      => 'CV_TOKEN'],
    [username   => 'CV_USERNAME'],
    [remote_key => 'CV_REMOTE_KEY'],
    [password   => 'CV_PASSWORD'],
    [token2fa   => 'CV_2FA_TOKEN']
  ) {
    my ($field, $env) = @$key;
    $auth->{$field} = $ENV{$env} if defined $ENV{$env};
  }

  $config->{log_level} = lc $config->{log_level} if $config->{log_level};

  return $config;
}

sub _load_yaml_config ($self) {
  my $path = path($self->home, 'config', 'checkvist.yml');
  return {} unless -e $path;

  unless (eval { require YAML::XS; 1 }) {
    $self->log->warn('YAML::XS not available; skipping config/checkvist.yml');
    return {};
  }

  my $data = eval { YAML::XS::LoadFile($path) };
  if (my $err = $@) {
    chomp $err;
    $self->log->error("Failed to load $path: $err");
    return {};
  }

  return $data;
}

1;

__END__

=encoding utf8

=head1 NAME

App::CheckvistMCP - Mojolicious application for the Checkvist MCP server

=head1 DESCRIPTION

L<App::CheckvistMCP> wires the MCP server endpoint into a Mojolicious
application and loads configuration from environment variables or
C<config/checkvist.yml>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2024. Licensed under the same terms as Perl itself.

=cut
