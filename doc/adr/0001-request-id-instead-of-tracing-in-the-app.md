# A request ID, not OpenTelemetry, links the app to the backend

A generated app ties a failure to the backend's record of it with an
`X-Request-ID` on every Dio call, which moarch-py logs and returns. It does
not trace with OpenTelemetry: the Dart SDK for it is not mature enough to
generate into other people's apps, and starting traces with hand-made
`traceparent` headers would send the backend traces whose root span never
arrives. A team that wants traces end to end ticks Sentry, whose `sentry_dio`
starts real spans and sends trace headers the backend can continue.

The cost is that without Sentry the link is one ID to search for, not a trace
to open. If OpenTelemetry for Flutter matures, the request ID stays: it is
what a user can read out in a bug report.
