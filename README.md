# Checkvist MCP Server (Perl)

This project provides a Mojolicious application that exposes a
Model Context Protocol (MCP) server with a single `get_lists` tool for
retrieving a user's Checkvist checklists.

## Getting started

```bash
cpanm --installdeps .
export MCP_ADMIN_TOKEN=supersecret
export CV_TOKEN=your_checkvist_token
morbo bin/mcp-checkvist
```

The MCP endpoint will listen on `/mcp`. Requests must include the header
`Authorization: Bearer $MCP_ADMIN_TOKEN`.

See `config/checkvist.yml.example` for optional file-based configuration.
