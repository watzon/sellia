# Suggesting Features

This guide explains how to suggest new features for Sellia effectively.

## Table of Contents

- [Before Suggesting](#before-suggesting)
- [How to Suggest](#how-to-suggest)
- [Feature Request Template](#feature-request-template)
- [What Makes a Good Request](#what-makes-a-good-request)
- [Feature Categories](#feature-categories)
- [After Submitting](#after-submitting)

## Before Suggesting

### Check for Existing Requests

Search [existing issues](https://github.com/watzon/sellia/issues) to avoid duplicates:

1. Use the search bar with keywords
2. Check both open and closed issues
3. Review the [ROADMAP](../../../ROADMAP.md) for planned features

**Search terms to try:**
- Feature name or concept
- Related component (e.g., "TCP tunnel", "custom domain")
- Use case (e.g., "database access", "SSH tunneling")

### Review the Roadmap

Check the [ROADMAP](../../../ROADMAP.md) to see:
- What's already planned
- Current development priorities
- What's in scope for the open-source project

Note: Multi-tenancy, billing, and enterprise SaaS features are explicitly out of scope for the open-source version.

### Consider Self-Hosting

Some requests may be better addressed by self-hosting:

- **Custom configuration** - May be possible with config files
- **Integrations** - May be achievable with custom scripts
- **Deployment** - May be solved with Docker or custom orchestration

### Think Through the Problem

Before requesting, consider:
- What problem are you trying to solve?
- How would this feature help?
- Who would benefit from this feature?
- Are there alternative solutions?

## How to Suggest

### Create a GitHub Issue

1. Go to [github.com/watzon/sellia/issues](https://github.com/watzon/sellia/issues)
2. Click "New Issue"
3. Choose "Feature Request" template (if available)
4. Fill in the required information
5. Submit the issue

### Use a Clear Title

A good title explains the feature and its benefit:

**Good titles:**
- "Add TCP tunnel support for database connections"
- "Implement custom domain support for production deployments"
- "Add request replay functionality to inspector UI"

**Poor titles:**
- "Feature request"
- "Please add this"
- "I need help with..."

## Feature Request Template

Use this template when suggesting features:

```markdown
### Feature Description

A clear and concise description of the feature you'd like to see added.

### Problem Statement

What problem does this feature solve? What limitation does it address?

### Proposed Solution

How do you envision this feature working? Provide details about:
- User-facing behavior
- Configuration options
- API changes (if applicable)

### Alternatives Considered

What alternative solutions or workarounds have you considered?
Why are they insufficient?

### Use Cases

Describe specific scenarios where this feature would be useful:
- Use case 1: ...
- Use case 2: ...

### Benefits

Who would benefit from this feature and how?
- End users
- Developers
- Operators

### Drawbacks/Risks

Any potential downsides, risks, or concerns:
- Performance impact
- Complexity increase
- Breaking changes

### Implementation Details (Optional)

If you have thoughts on implementation:
- Technical approach
- Areas of codebase affected
- Dependencies required
- Rough effort estimate

### Examples/Mockups (Optional)

Screenshots, mockups, or examples:
- UI mockups
- Example config files
- API usage examples

### Additional Context

Add any other context, screenshots, or examples about the feature request.
```

## What Makes a Good Request

### 1. Clear Problem Statement

Explain **what problem** you're trying to solve:

```markdown
### Problem Statement

I need to expose my PostgreSQL database to remote developers for
collaboration and debugging. Currently, I can only tunnel HTTP services,
which doesn't work for database connections that use the PostgreSQL protocol.
```

### 2. Proposed Solution

Describe **how** the feature should work:

```markdown
### Proposed Solution

Add a new command similar to `sellia http` for TCP tunnels:

```bash
sellia tcp 5432 --subdomain my-db
```

This would:
- Create a TCP tunnel to the local PostgreSQL database
- Assign a subdomain:port combo (e.g., my-db.127.0.0.1.nip.io:3000)
- Forward raw TCP traffic (not HTTP)
```

### 3. Use Cases

Provide **concrete examples** of how you'd use it:

```markdown
### Use Cases

**Use Case 1: Remote Database Access**
Developers working remotely need direct access to the development database.
With TCP tunnels, they can connect using standard PostgreSQL tools:

```bash
psql -h myapp-db.127.0.0.1.nip.io -p 3000 -U devuser -d myapp_dev
```

**Use Case 2: Redis Debugging**
When debugging Redis caching issues, I need to connect to the local Redis
instance from remote machines for inspection.

**Use Case 3: SSH Tunneling**
For maintenance tasks, I need to SSH into servers behind NAT/firewalls.
```

### 4. Alternatives Considered

Show you've **thought about alternatives**:

```markdown
### Alternatives Considered

**Alternative 1: VPN**
- Pros: Full network access
- Cons: Complex setup, requires client software, not portable
- Why insufficient: Overkill for simple database access

**Alternative 2: ngrok's TCP tunnels**
- Pros: Already supports TCP
- Cons: Not self-hosted, usage limits, cost
- Why insufficient: We need to self-host for compliance reasons

**Alternative 3: SSH tunneling**
- Pros: Built into SSH
- Cons: Requires SSH access, manual setup per developer
- Why insufficient: Want something more user-friendly
```

### 5. Implementation Ideas

If you have **technical thoughts**, share them:

```markdown
### Implementation Details

**Protocol:**
The protocol already supports arbitrary byte streams over WebSocket.
Would need to add:
- `RegisterTcpTunnel` message type
- TCP port allocation in server
- TCP forwarding handler (similar to HTTP ingress)

**Port Allocation:**
- Suggest configurable port ranges (e.g., 5000-6000 for TCP tunnels)
- Track allocations in tunnel registry

**Complexity:**
- Medium complexity
- Similar to existing HTTP tunnel flow
- Main risk: port exhaustion
```

## Feature Categories

### Core Tunneling Features

For enhancements to tunneling capabilities:

```markdown
### Feature: UDP Protocol Support

**Problem:**
Need to tunnel UDP-based services like DNS, syslog, or game servers.

**Proposed Solution:**
Add UDP tunnel support similar to TCP/HTTP tunnels.

**Use Cases:**
- DNS server debugging
- Log aggregation
- Real-time game development
```

### Inspector UI Features

For improvements to the web inspector:

```markdown
### Feature: Request/Response Modification

**Problem:**
When debugging webhook handlers, I need to test different payloads
without modifying the sending application.

**Proposed Solution:**
Add "Edit & Resend" feature in inspector UI that allows modifying
request body/headers and replaying the request.

**Use Cases:**
- Testing webhook handlers with different payloads
- Trying different authentication headers
- Debugging API edge cases
```

### CLI Features

For command-line interface improvements:

```markdown
### Feature: Tunnels Profile Management

**Problem:**
I work on multiple projects and constantly switch between different
tunnel configurations. Typing all the flags each time is tedious.

**Proposed Solution:**
Add profile management:

```bash
sellia profile save project1 --port 3000 --subdomain myapp
sellia profile use project1  # Starts tunnel with saved config
sellia profile list          # Lists all profiles
```

**Use Cases:**
- Quick switching between projects
- Sharing tunnel configs with team
- Version control tunnel configurations
```

### Server Features

For server-side functionality:

```markdown
### Feature: IP Allowlisting

**Problem:**
I want to expose internal tools to specific office locations but
keep them private from the rest of the internet.

**Proposed Solution:**
Add IP allowlisting per tunnel or globally:

```bash
sellia http 3000 --allow 192.168.1.0/24 --allow 10.0.0.0/8
```

**Use Cases:**
- Restricting internal tools to office networks
- Compliance requirements for data access
- Multi-tenant deployments with access controls
```

### DevOps/Deployment

For deployment and operations improvements:

```markdown
### Feature: Kubernetes Deployment Manifests

**Problem:**
We deploy everything on Kubernetes and would like to run Sellia
in our cluster.

**Proposed Solution:**
Provide Helm charts or Kubernetes manifests for deployment.

**Use Cases:**
- Self-hosting in Kubernetes
- Horizontal scaling of tunnel servers
- Integration with existing K8s infrastructure
```

### Developer Experience

For improvements to developer workflows:

```markdown
### Feature: Language Client Libraries

**Problem:**
Integrating Sellia into applications requires implementing the
WebSocket protocol manually.

**Proposed Solution:**
Provide official client libraries for popular languages (Python, Go, Rust).

**Use Cases:**
- Programmatic tunnel creation from applications
- Testing frameworks that need temporary tunnels
- Custom tooling
```

## Evaluation Criteria

Features are evaluated based on:

### 1. Alignment with Project Goals

- Does it fit the self-hosted ngrok alternative use case?
- Is it within scope (not enterprise/SaaS features)?
- Does it benefit the target audience?

### 2. Demand and Use Cases

- How many people would use it?
- Are the use cases compelling and realistic?
- Is there significant community interest?

### 3. Implementation Feasibility

- Can it be implemented reasonably?
- What's the complexity and effort required?
- Are there technical blockers?

### 4. Maintenance Burden

- Will it significantly increase maintenance?
- Does it add dependencies or complexity?
- Can it be tested effectively?

### 5. Breaking Changes

- Does it require breaking existing functionality?
- Is migration possible for existing users?
- What's the impact on the ecosystem?

## What Happens Next

### Issue Triage

After submission:

1. **Labeling** - Issue will be tagged (enhancement, needs-discussion, etc.)
2. **Discussion** - Community and maintainers will discuss
3. **Evaluation** - We'll evaluate against criteria above
4. **Decision** - Accepted, deferred, or rejected

### Possible Outcomes

**Accepted:**
- Added to roadmap
- Prioritized for upcoming milestone
- Assigned to a milestone

**Needs Discussion:**
- Community discussion encouraged
- Clarifying questions asked
- May result in refined proposal

**Deferred:**
- Good idea but not right now
- May be reconsidered later
- Added to "Future Considerations"

**Rejected:**
- Doesn't align with project goals
- Out of scope (e.g., enterprise features)
- Technical blockers
- You'll receive explanation

## Contributing the Feature

If your feature request is accepted:

### 1. Design Discussion

We'll work through the design together:
- API surface
- Configuration options
- User experience
- Implementation approach

### 2. Implementation

You can contribute the implementation:
- See [Contributing Workflow](workflow.md)
- Follow [Code Style](code-style.md)
- Write [Tests](../development/testing.md)

### 3. Review and Merge

- Submit as a PR when ready
- We'll review together
- Iterate based on feedback
- Merge when complete

## Examples of Good Feature Requests

### Example 1: Complete and Thoughtful

```markdown
### Add TCP tunnel support for database and SSH connections

**Problem Statement:**
Our team needs to access development databases and internal servers
that are behind NAT/firewalls. HTTP-only tunneling doesn't work for
PostgreSQL, MySQL, SSH, or other TCP-based protocols.

**Proposed Solution:**
Implement TCP tunneling similar to `ngrok tcp`:

```bash
sellia tcp 5432 --subdomain my-db
# Returns: TCP tunnel available at my-db.127.0.0.1.nip.io:5000
```

**Protocol Design:**
1. Client opens WebSocket to server
2. Sends `RegisterTcpTunnel` message with requested port
3. Server allocates port from configured range (e.g., 5000-6000)
4. Server listens on allocated port
5. Incoming TCP connections on server port are forwarded via WebSocket
6. Client forwards to local TCP service

**Configuration:**
```yaml
# sellia-server config
tcp_port_range: "5000-6000"
max_tcp_tunnels: 100
```

**Use Cases:**
- **Database Access:** Remote PostgreSQL/MySQL access for developers
- **SSH Tunneling:** Access servers behind NAT
- **Redis Debugging:** Connect to local Redis from remote
- **Custom Protocols:** Any TCP-based service (LDAP, RDP, etc.)

**Alternatives Considered:**
- **VPN:** Too complex, requires client software
- **SSH port forwarding:** Manual, not user-friendly
- **ngrok:** Not self-hosted, usage limits

**Benefits:**
- Expands Sellia beyond HTTP/HTTPS
- Enables new use cases (databases, SSH)
- Competitive feature with ngrok

**Drawbacks:**
- Increases complexity
- Port management challenges
- Security considerations (exposing raw TCP)

**Implementation Effort:**
- Medium complexity (~2-3 weeks)
- Requires:
  - Protocol message for TCP registration
  - TCP server component
  - Port allocation logic
  - TCP forwarding over WebSocket

**References:**
- ngrok's TCP implementation
- SSH tunneling as reference
```

### Example 2: Focused and Specific

```markdown
### Add `--log-level` flag to control verbosity

**Problem:**
Debug logging is all-or-nothing with `LOG_LEVEL=debug`. There's no
way to get warnings/errors without verbose debug output.

**Proposed Solution:**
Add log level flag:

```bash
sellia http 3000 --log-level warn
```

Levels: error, warn, info, debug

**Use Cases:**
- Production deployments want only errors
- Development wants debug
- Testing wants info

**Benefits:**
- Better production logs
- Reduced log volume
- Industry-standard approach

**Simple Implementation:**
Just add standard log levels to existing logger.
```

## Best Practices

### DO:

- **Search first** - Check for duplicates and roadmap
- **Be specific** - Provide concrete use cases and examples
- **Think big picture** - Consider the broader ecosystem
- **Consider alternatives** - Show you've thought of other approaches
- **Stay engaged** - Participate in the discussion
- **Be open to feedback** - Your idea may evolve

### DON'T:

- **Demand immediate implementation** - We're volunteers
- **Request enterprise features** - Billing, multi-tenancy, etc. are out of scope
- **Be vague** - "Make it better" isn't helpful
- **Ignore the roadmap** - Check what's already planned
- **Forget the why** - Explain the problem, not just the solution

## After Submitting

What to expect after you open a feature request:

- Maintainers may ask clarifying questions
- The request may be tagged and triaged against the roadmap
- If accepted, it may be scheduled for a future milestone
- You are welcome to contribute an implementation

## Related Resources

- [Roadmap](../../../ROADMAP.md) - See what's planned
- [Contributing Workflow](workflow.md) - Implement the feature
- [Reporting Bugs](reporting-bugs.md) - Report issues instead
- [Existing Issues](https://github.com/watzon/sellia/issues) - Search and discuss

## Next Steps

- [Contributing Workflow](workflow.md) - Start implementing
- [Development Setup](../development/prerequisites.md) - Set up environment
- [Code Style](code-style.md) - Write clean code
