requires 'perl', '5.32.0';
requires 'Mojolicious', '>= 9.0';
requires 'MCP', '>= 0.05';
requires 'JSON::Validator';
recommends 'YAML::XS';

on 'test' => sub {
  requires 'Test::More';
  requires 'Test::Mojo';
};
