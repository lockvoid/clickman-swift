# Clickman protocol snapshot

This directory contains version 1 of the ClickMan protocol. The [protocol guide](../docs/PROTOCOL.md) defines the wire format and queue rules; `fixtures/` contains examples shared by the language implementations. Keeping a copy here lets the SDK build and test without a server checkout.

Protocol changes start in clickman-server. When updating this snapshot, copy the matching specification, fixtures, and SQL together. From the repository root, run `python3 scripts/queue-schema.py` to regenerate embedded queue schemas, or add `--check` to verify that the committed copies match.
