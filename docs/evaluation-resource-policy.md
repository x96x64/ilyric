# Evaluation Resource Policy

## Current Limits and Accounting Scope

Effective October 9, 2026, the explicitly approved cumulative local evaluation-storage ceiling is **15,000,000,000 bytes (15 GB; approximately 13.970 GiB)**. The cumulative download ceiling remains **2,000,000,000 bytes**. Increasing storage does not authorize any new transfer, checkpoint, dependency installation, dataset, or unrelated experiment. Existing licensing, isolation, privacy, and explicit provisioning conditions remain applicable.

Charge the complete `artifacts/` and `reference-private/` trees, including historical visual diagnostics and original media, the working checkout's `.build/`, and every retained iLyric public-verification checkout. Do not count overlapping subdirectories twice or exclude a relevant directory to obtain compliance. Shared system Python executables and the Apple toolchain are existing platform dependencies rather than dedicated evaluation copies; the three virtual-environment interpreter symlinks occupy their own directory entries, not copies of those shared executables. Record any additional dedicated cache or external evaluation directory when introduced.

Use allocated directory storage, reported by `du -sk` in 1,024-byte units. Report both decimal GB (`bytes / 1,000,000,000`) and binary GiB (`bytes / 1,073,741,824`). Directory charges are conservative budget accounting; APFS shared extents are not a unique-physical-block measurement. Filesystem available space is a separate constraint, not authorization to exceed the ceiling.

## Initial Reconciliation and Approval

The complete initial inventory was **13,147,078,656 bytes (13.147 GB; 12.244 GiB)**, exceeding the original 10-GB proposal by **3,147,078,656 bytes**. The user subsequently approved 15,000,000,000 bytes with this complete scope. Reverification reproduced the same total, leaving 1,852,921,344 bytes of budget headroom before this gate. No file was deleted and no accounting exclusion was introduced.

The user's approximately 4.0-GiB `artifacts/` and 4.5-GiB `reference-private/` measurements agree with this inventory. The historical 5.515-GB report counted alignment-specific artifacts, private alignment research, and five alignment verification checkouts. It omitted other visual artifacts, most private reference/analysis storage, the current build directory, and two earlier verification checkouts. That historical record remains unchanged; this policy supersedes its accounting scope prospectively.

Approximately **37,928,960,000 bytes (37.929 GB; 35.324 GiB)** were available on the filesystem at intake. At resumption, available capacity was 40,181,760,000 bytes (40.182 GB; 37.422 GiB). Both filesystem capacity and the approved budget permit bounded verification and preparation; allocation must still be checked before each operation. Historical download totals are still approximate; retain the existing 1.50-GB conservative planning charge and separately recorded approved transfers rather than presenting them as an exact ledger. This gate performs no downloads or installations.

## Subsequent Inventory and Preservation

Reinventory the named roots before allocating a verification checkout or evaluation output, and after verification. Include temporary installation/output peaks in any future provisioning request. Retained checkouts and historical diagnostics remain charged even when no longer active. Cleanup requires a separate, specific authorization; none is granted here. Original recordings, annotations, models, historical evidence, and backup references must be preserved.

The [storage and annotation report](evaluation-storage-annotation-readiness.md) records the current reconciliation and annotation readiness. Earlier measurements and approvals remain historical evidence. The unsent permission-inquiry documents remain deferred to the existing documentation-cleanup milestone; developer contact is not required by the current local-research workflow.
