# Separate service and client milestones

These remain part of the requested full product, not features of the current local Mac build. No content transmission, accounts, cloud dependencies or implicit sync exist. The next Mac milestones (rich content, migration, script trust, expansion forms, transaction adapters and on-device usage controls) can proceed independently of these infrastructure decisions.

## Personal encrypted sync

Scope: optional per-library sync, local-first offline edits, explicit device enrollment, encrypted snapshots/revisions, conflict review, deletion tombstones and recovery export. Assets include snippet bodies, attachments, field schemas, revision history and membership. The service may see library identifiers, ciphertext size, device membership and timing; this leakage must be disclosed. No raw keypress stream or resolved fill-in history may be transmitted.

Before any network client is enabled, choose the service operator, hosting region, account authentication and recovery policy. Define a versioned encryption envelope using audited platform cryptography, per-library keys held in Keychain and authenticated encrypted data bound to library ID/schema/revision. Use explicit device pairing and encrypted key envelopes. Never derive content encryption solely from an account password. Supply an offline recovery export before enrollment. Document the limits of revocation: an already enrolled device may retain plaintext it previously decrypted. Rotate keys on device revocation and bound offline write authorization; tombstones require acknowledgement/retention to prevent deleted content reappearing.

Acceptance: new enrollment, wrong key/device denial, lost-device recovery, revoked-device writes, replay/tampering tests, concurrent edits without silent last-writer loss, offline deletion/edit conflicts, key rotation during offline use, network interruption, schema compatibility and complete disabling/export/deletion. Sync is initially off, has visible per-library state and makes no requests before explicit enrollment.

## Shared libraries and organization administration

Scope: owner/admin/editor/user roles, invitation acceptance, explicit per-library membership, read-only copies, audited signed writes, team key distribution/revocation, conflict review, curated libraries, requests and approval workflows. Server authorization must enforce every operation; the client must not treat a hidden control as access enforcement. Access to an organization's library must never implicitly grant access to personal libraries.

Prerequisites: identity provider/domain policy, organization billing/ownership decisions, service data retention and incident response, key custodianship/recovery model and administrator threat model. Organization recovery keys have different privacy consequences from personal device-only keys and need an explicit product decision. Define invitation expiry, role downgrade behavior, member offboarding, ownership transfer, export restrictions and audit retention before launch. Public snippet links need a separate opt-in publication boundary and revocation semantics.

Acceptance: role/tenant isolation, expired invites, role changes with offline clients, signed author attribution, revoked-device writes, unauthorized export, request approval races, audit tampering, key rotation on removal and ownership recovery. Permissions must be tested through the service API, not only the app UI.

## Cross-platform clients

Windows, browser and mobile are separate codebases with shared versioned library/template contracts and immutable compatibility fixtures. They must report unsupported macros instead of dropping content on import. Each needs platform-specific consent, secure-field exclusion, target adapters, keyboard/IME acceptance, package signing and updates. Browser inline recommendations and public/team sharing are separately tracked capabilities in current TextExpander research, not claimed by Quill's local command palette.

Prerequisites: decide first platform, supported OS/editor matrix, distribution channel and ownership of shared protocol fixtures. Acceptance includes offline round trips across each client, schema-forward rejection, Unicode/IME/secure-input behavior, attachment fidelity, capability loss reports and permission revocation. A universal Mac binary does not establish any of these clients.
