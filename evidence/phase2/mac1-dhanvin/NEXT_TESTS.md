# Pending live tests

The Mac 1 configuration and evidence structure are ready. Do not mark these
tests complete until their real output is captured.

- Start primary DNS with `dns/start-phase2-primary.command`.
- Verify `dig @10.239.23.157 app.dmjl.test` returns `10.239.23.87`, TTL 30.
- Verify Jagruthi's nginx serves trusted HTTPS.
- Record six HTTPS requests showing both Backend A and Backend B.
- Stop primary DNS and prove Lalith's backup DNS handles a normal client lookup.
- Test backend firewall isolation and its rollback.
- Participate in DNS cutover and manual cache-flush tests.

Never replace these checks with invented output. Add results only after running
the live command.
