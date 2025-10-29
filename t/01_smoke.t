use strict;
use warnings;

use Test::More;

BEGIN {
  eval { require MCP::Server; 1 } or plan skip_all => 'MCP::Server is required for the smoke test';
  eval { require Mojolicious; 1 } or plan skip_all => 'Mojolicious not available';
}

use App::CheckvistMCP;
use Test::Mojo;

my $app = App::CheckvistMCP->new;
isa_ok($app, 'App::CheckvistMCP');

my $config = $app->checkvist_config;
ok(ref $config eq 'HASH', 'config helper returns hashref');

my $t = Test::Mojo->new($app);
$t->get_ok('/mcp')->status_is(401)->json_is('/error/code' => 'unauthorized');

done_testing;
