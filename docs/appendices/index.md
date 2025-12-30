# Appendices

Additional reference material for Sellia.

## Overview

This section contains supplementary information, reference tables, and resources that don't fit in the main documentation sections.

## Appendices

### [Glossary](glossary.md)

Terms and definitions used throughout the Sellia documentation.

### [Protocol Specification](../developer/architecture/protocol.md)

Detailed specification of the Sellia protocol over WebSocket.

### [Configuration Reference](config-reference.md)

Complete reference for all configuration options.

### [Error Codes](error-codes.md)

List of error codes and their meanings.

### [Environment Variables](env-vars.md)

Complete list of supported environment variables.

## Resources

### Official Resources

- **Website:** [sellia.me](https://sellia.me)
- **GitHub:** [github.com/watzon/sellia](https://github.com/watzon/sellia)
- **Documentation:** [docs.sellia.me](https://docs.sellia.me) (coming soon)
- **Issues:** [github.com/watzon/sellia/issues](https://github.com/watzon/sellia/issues)

### Community

- **Discussions:** [github.com/watzon/sellia/discussions](https://github.com/watzon/sellia/discussions)
- **Discord:** (coming soon)

### Related Projects

- **Crystal Language:** [crystal-lang.org](https://crystal-lang.org)
- **MessagePack:** [msgpack.org](https://msgpack.org)
- **WebSocket:** [websockets.spec](https://websockets.spec.whatwg.org/)

## Legal

### License

Sellia is released under the MIT License. See [LICENSE](https://github.com/watzon/sellia/blob/main/LICENSE) for details.

### Third-Party Licenses

Sellia uses the following third-party libraries:

- **Crystal** - Apache 2.0
- **MessagePack-Crystal** - MIT
- **WebSocket-Crystal** - MIT
- **React** - MIT
- **Vite** - MIT

See `shard.yml` and `web/package.json` for complete list.

### Trademarks

Sellia is a trademark of Chris Watson. Other product and company names mentioned herein may be the trademarks of their respective owners.

## Support

### Getting Help

If you need help with Sellia:

1. **Documentation** - Start with the user guide
2. **Issues** - Search existing issues on GitHub
3. **Discussions** - Ask questions in GitHub Discussions
4. **New Issue** - Create a new issue if you found a bug

### Professional Support

Professional support options are coming soon.

## Contributing

Want to contribute? See:

- [Contributing Guide](../developer/contributing/)
- [Development Setup](../developer/development/)
- [Architecture](../developer/architecture/)

## Version History

See [CHANGELOG.md](https://github.com/watzon/sellia/blob/main/CHANGELOG.md) for version history.

## Quick Reference

### Common Commands

**Tunnel:**
```bash
sellia http 3000 --subdomain myapp
```

**With auth:**
```bash
sellia http 3000 --auth user:pass
```

**Start from config:**
```bash
sellia start
```

### Common Ports

| Port | Usage |
|------|-------|
| 3000 | Default local port for forwarding |
| 4040 | Default inspector port |
| 5173 | Vite dev server (development) |

### File Locations

| File | Location |
|------|----------|
| Config | `~/.config/sellia/sellia.yml`, `~/.sellia.yml`, or `./sellia.yml` |
| Database | Platform-dependent (see [Defaults](./defaults.md)) |
| Binary | `sellia` (installed via Homebrew, Scoop, or built from source) |

### Default Values

| Setting | Default |
|---------|---------|
| Local port | 3000 |
| Inspector port | 4040 |
| Local host | localhost |
| Server | https://sellia.me |

## Next Steps

- **New Users:** [Getting Started](../user/getting-started/)
- **Troubleshooting:** [Troubleshooting](../user/troubleshooting/)
- **Contributing:** [Contributing](../developer/contributing/)
