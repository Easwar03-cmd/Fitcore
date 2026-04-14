# Architecture Decisions

## ADR-001: Expo Router over React Navigation
**Date:** ...
**Decision:** Use Expo Router v3 for file-based routing
**Reason:** Simpler mental model for solo dev, deep linking works out of the box, aligns with web conventions
**Trade-off:** Less flexibility for complex custom navigators

## ADR-002: WatermelonDB over SQLite directly
**Date:** ...
**Decision:** Use WatermelonDB for local storage
**Reason:** Built-in sync protocol, reactive queries, offline-first by design
**Trade-off:** More complex setup than AsyncStorage, learning curve

(add new decisions here as you make them)