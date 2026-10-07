# W4 result

Pinned JP1.73.0 (`jp-1.73.0-e2baf70e`) extraction is ready. FavorLevelExcel100rows, CafeInteractionExcel276rows, all generated fields retained. Cafe rewards are uniformly ParcelType11=FavorExp / Id0 / Amount15.

ExpType is a long vector of length1, Level1..100. Native metadata has CharacterExcel.FavorLevelupType int. Character7792rows: type0=7131,type1=661; is_playable466rows: type0=143,type1=323. Cafe276IDs all match type1. Repeated positive values support the required-per-level candidate but the reader did not certify raw type1→vector0 or the rank boundary/cumulative formula. Interpretation stays undetermined with two candidates.

ConstCommon exists in pinned JP Excel.zip rather than the decrypted DB. Its22matching scalar properties include dialogue, bubble, charge, summon and sync parameters, with no interaction count/cooldown field. Full metadata inventory:40039types,159642fields, and all properties scanned. Related408types carry method addresses.

The single permitted native function, CafeService.get_InteractCooltime (RVA0x1338160), loads binary64 3.0 from VA0x187351528 (raw0000000000000840), then tailcalls System.TimeSpan.FromHours VA0x1860a79e0. Exact unwind body has14instructions. JP client getter=3hours. Count/server/reset rules remain unconfirmed; no daily count inferred.

Existing20JSONfiles match their frozen hashes. Dependencies were read under approved local execution escalation; the reviewer rejected no action. The first extraction attempt completed HMAC before failing at a missing ConstCommon DB table; new canonical files were published on the continuation. The task-owned plaintext/temp directory was removed, and the cleanup/finalization is documented in evidence. No game execution, network, key disclosure/copy, original client copy, other-project access, shared-store write, or git mutation occurred.

Root owns shared-store import/status, common Python green and W4 commit.
