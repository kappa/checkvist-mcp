use strict;
use warnings;
use lib 'lib';

use Test::More;

BEGIN {
  eval { require Mojolicious; 1 } or plan skip_all => 'Mojolicious not available';
  eval { require Mojo::JSON; 1 } or plan skip_all => 'Mojo::JSON not available';
  eval { require Mojo::URL; 1 } or plan skip_all => 'Mojo::URL not available';
  eval { require Mojo::UserAgent; 1 } or plan skip_all => 'Mojo::UserAgent not available';
}

use App::CheckvistMCP::Auth;
use App::CheckvistMCP::Error;
use App::CheckvistMCP::Lists;
use Mojo::JSON;
use Mojo::URL;
use Mojo::UserAgent;

subtest 'lists retrieval' => sub {
  my $app = Mojolicious->new;
  $app->routes->get('/checklists.json' => sub ($c) {
    is $c->req->headers->header('X-Client-Token'), 'test-token', 'token header present';
    is $c->req->url->query->param('archived'), 'true', 'archived flag set';
    is $c->req->url->query->param('skip_stats'), undef, 'skip_stats omitted when false';
    is $c->req->url->query->param('order'), 'id:asc', 'order propagated';
    $c->render(json => [
      {id => 1, name => 'Inbox', public => Mojo::JSON->false},
    ]);
  });

  my $ua = Mojo::UserAgent->new;
  $ua->server->app($app);
  my $service = App::CheckvistMCP::Lists->new(
    base_uri => Mojo::URL->new($ua->server->url),
    ua       => $ua,
  );

  my $result = $service->get_lists('test-token', {archived => 1, skip_stats => 0, order => 'id:asc'});
  is_deeply $result, [{id => 1, name => 'Inbox', public => Mojo::JSON->false}], 'lists returned';
};

subtest 'lists error mapping' => sub {
  my $app = Mojolicious->new;
  $app->routes->get('/checklists.json' => sub ($c) {
    $c->render(status => 403, json => {error => 'Forbidden'});
  });

  my $ua = Mojo::UserAgent->new;
  $ua->server->app($app);
  my $service = App::CheckvistMCP::Lists->new(
    base_uri => Mojo::URL->new($ua->server->url),
    ua       => $ua,
  );

  my $ok = eval { $service->get_lists('token', {}) };
  ok !$ok, 'call failed';
  my $error = $@;
  isa_ok $error, 'App::CheckvistMCP::Error';
  is $error->code, 'auth_failed', 'auth error propagated';
};

subtest 'auth login flow' => sub {
  my $app = Mojolicious->new;
  my $calls = 0;
  $app->routes->post('/auth/login.json' => sub ($c) {
    $calls++;
    is $c->param('username'), 'demo', 'username used';
    is $c->param('remote_key'), 'remote123', 'remote key used';
    $c->render(json => {token => 'abc123'});
  });

  my $ua = Mojo::UserAgent->new;
  $ua->server->app($app);

  my $auth = App::CheckvistMCP::Auth->new(
    base_uri  => Mojo::URL->new($ua->server->url),
    ua        => $ua,
    auth      => {username => 'demo', remote_key => 'remote123'},
    token_ttl => 3600,
  );

  my $token1 = $auth->ensure_token;
  is $token1, 'abc123', 'token returned';
  my $token2 = $auth->ensure_token;
  is $token2, 'abc123', 'token cached';
  is $calls, 1, 'login called only once';
};

subtest 'auth rejects missing credentials' => sub {
  my $auth = App::CheckvistMCP::Auth->new(auth => {username => 'demo'});
  my $ok = eval { $auth->ensure_token };
  ok !$ok, 'ensure_token failed';
  isa_ok $@, 'App::CheckvistMCP::Error';
  is $@->code, 'auth_failed', 'missing secret triggers auth_failed';
};

subtest 'lists require token' => sub {
  my $service = App::CheckvistMCP::Lists->new;
  my $ok = eval { $service->get_lists('', {}) };
  ok !$ok, 'missing token rejected';
  isa_ok $@, 'App::CheckvistMCP::Error';
  is $@->code, 'auth_failed', 'code signals auth';
};

done_testing;
