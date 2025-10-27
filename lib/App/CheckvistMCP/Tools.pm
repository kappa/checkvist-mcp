package App::CheckvistMCP::Tools;
use Mojo::Base -strict, -signatures;

use App::CheckvistMCP::Auth;
use App::CheckvistMCP::Error;
use App::CheckvistMCP::Lists;
use MCP::Server;
use Mojo::JSON qw(true);
use Mojo::URL;
use Mojo::UserAgent;
use Scalar::Util qw(blessed);

sub build_server ($class, $app, $config) {
  my $base_uri = Mojo::URL->new($config->{base_uri} // 'https://checkvist.com');

  my $ua = Mojo::UserAgent->new;
  $ua->connect_timeout(5);
  $ua->request_timeout(20);
  $ua->inactivity_timeout(20);
  $ua->max_redirects(0);
  $ua->transactor->name('checkvist-mcp');

  my $auth = App::CheckvistMCP::Auth->new(
    base_uri => $base_uri,
    ua       => $ua,
    auth     => { %{ $config->{auth} // {} } },
  );

  my $lists = App::CheckvistMCP::Lists->new(
    base_uri => $base_uri,
    ua       => $ua,
  );

  my $server = MCP::Server->new(
    name    => 'checkvist-mcp',
    version => ($App::CheckvistMCP::VERSION // '0.01'),
  );

  $server->tool(
    name        => 'get_lists',
    description => q{Retrieve the authenticated user's Checkvist checklists.},
    input_schema => {
      type       => 'object',
      properties => {
        archived => {type => 'boolean', description => 'If true, return archived lists.'},
        order    => {
          type        => 'string',
          enum        => ['id:asc', 'id:desc', 'updated_at:asc'],
          description => 'Override default sorting.'
        },
        skip_stats => {type => 'boolean', description => 'Faster, omit users/tasks stats.'},
      },
    },
    output_schema => {
      type       => 'object',
      properties => {
        lists => {
          type  => 'array',
          items => {
            type       => 'object',
            properties => {
              id             => {type => 'integer'},
              name           => {type => 'string'},
              public         => {type => 'boolean'},
              role           => {type => 'integer', description => '1=author,2=writer,3=reader'},
              updated_at     => {type => 'string'},
              task_count     => {type => 'integer'},
              task_completed => {type => 'integer'},
              read_only      => {type => 'boolean'},
              archived       => {type => 'boolean'},
              tags           => {type => 'object', additionalProperties => {type => 'boolean'}},
              tags_as_text   => {type => 'string'},
            },
            required => ['id', 'name'],
            additionalProperties => true,
          },
        },
      },
      required => ['lists'],
    },
    code => sub ($tool, $args) {
      $args //= {};

      my $lists_data;
      my $attempt = 0;
      while (1) {
        $attempt++;
        my $token = eval { $auth->ensure_token };
        if (my $err = $@) {
          return _tool_error($tool, $err, $app);
        }

        my $res = eval { $lists->get_lists($token, $args) };
        if (my $err = $@) {
          if (blessed($err) && $err->isa('App::CheckvistMCP::Error') && $err->code eq 'auth_failed' && !$auth->auth->{token} && $attempt < 2) {
            $auth->invalidate_cached_token;
            next;
          }
          return _tool_error($tool, $err, $app);
        }

        $lists_data = $res;
        last;
      }

      return $tool->structured_result({lists => $lists_data});
    }
  );

  return $server;
}

sub _tool_error ($tool, $err, $app) {
  if (blessed($err) && $err->isa('App::CheckvistMCP::Error')) {
    my %payload = (
      code    => $err->code // 'error',
      message => $err->message // 'Tool error',
    );
    $payload{status} = $err->status if defined $err->status;
    $payload{meta}   = $err->meta   if $err->meta;
    return $tool->structured_result({error => \%payload}, 1);
  }

  my $message = $err;
  $message =~ s{\s+}{ }g if defined $message;
  $app->log->error("Unhandled get_lists error: $message");

  return $tool->structured_result({
    error => {
      code    => 'internal_error',
      message => 'Unexpected error while fulfilling get_lists',
    }
  }, 1);
}

1;

__END__

=encoding utf8

=head1 NAME

App::CheckvistMCP::Tools - Register MCP tools for the Checkvist server

=head1 DESCRIPTION

Builds the MCP server instance and registers the C<get_lists> tool.

=cut
