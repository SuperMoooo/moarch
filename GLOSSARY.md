# moarch

A CLI that scaffolds Clean Architecture Flutter apps. These are the words it
uses where a term needs pinning down; the same words mean the same things in
its Python sibling, moarch-py.

## Observability

**Telemetry**:
What a running app reports about itself so the people supporting it can see
what it did: log lines, error reports and traces.
_Avoid_: Events, analytics, monitoring data

**Request ID**:
The ID one call to the backend carries, the same across its retries, that
ties the app's error for it to every line the backend logged for it.
_Avoid_: Correlation ID, trace ID
