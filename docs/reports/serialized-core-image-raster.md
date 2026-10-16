# Serialized Core Image Raster Evaluation

## Captured Failure

Main CI [38837151979](https://github.com/x96x64/ilyrics/actions/runs/38837151979), at `313a5d340cf4432e69af50054f026a00266dc518`, failed in two native processes on macOS 26.6.2 with Apple Swift 6.3.3 and Xcode 26.6. The FillDepartureTests process terminated with SIGSEGV during the extreme-lead rendering regression. The CLI child in `interruptedRenderLeavesNoPartialFiles` also terminated with SIGSEGV instead of cancellation status 130, leaving a temporary output. Neither failure is a passing cancellation test.

Both captured stacks lead through `objc_msgSend`, `NSData.getBytes`, AppleParavirtGPUMetalIOGPUFamily, MPS temporary-texture allocation, and `CIBlurProcessor`. The test-process caller is `InactiveTiles.init`; the CLI caller is `ArtworkBackdrop.image(at:)` during concurrent export. The stacks identify a shared blur-evaluation path, rather than the earlier Time arithmetic trap. They do not establish ownership of the underlying invalid-memory access or prove that every historical hosted crash had this cause. Raw reports remain outside Git; this record contains only sanitized symbols and environment context.

## Mitigation and Preserved Behavior

Both callers previously created separate Core Image contexts and requested `.useSoftwareRenderer`. [Apple documents](https://developer.apple.com/documentation/coreimage/cicontextoption/usesoftwarerenderer) that this option has no effect on platforms without OpenCL; it is not a platform-independent guarantee that Metal is absent. These captured failures entered the Metal/MPS path despite the existing request. A local comparison of the Gaussian convenience method with the named Gaussian filter produced the same image graphs and pixels, so changing that spelling would not avoid the captured processor path.

Inactive tiles and artwork backgrounds now evaluate through one retained Core Image context guarded by a process-wide lock. Image creation explicitly disables deferred evaluation so raster work completes before the lock is released. The Gaussian graphs, radii, extent and edge policies, encoded-sRGB working and output spaces, RGBA8 output, artwork adaptation, and fitted appearance parameters remain unchanged. Paragraph and frame composition outside these raster requests can still execute concurrently. Timing, input validation, public options, dependency versions, and release behavior are unchanged.

This is a targeted mitigation for overlapping evaluation and context lifetime at the captured boundary, not proof of a repaired virtual-GPU driver. Its effect must be evaluated on the hosted runner. Core Image rendering remains subject to platform behavior; no claim of a new CPU backend or unrestricted driver stability is made.

## Verification

The local environment is Apple silicon, macOS 27.0.1, Apple Swift 6.4, and Command Line Tools. The hosted failure did not reproduce on this physical Mac; that absence alone does not qualify the mitigation.

- Two new native tests pass: 16 raw-pixel comparisons against the preceding independent-context configurations, including clamped/unclamped edges and four blur radii, and 32 concurrent raster requests compared with their sequential results.
- The 11-test departure suite passes, including full-scene initialization, actual rendering, and random-access comparisons for the extreme focus leads.
- Debug and optimized builds, whole-repository formatting, and the diff check pass.
- At report preparation, the complete 232-test supported Swift suite is executing. Its result and subsequent CI evidence belong in the pull-request verification record.

CI isolates the independent legacy-context control from other screen tests, so the control itself does not reintroduce overlapping legacy contexts. The concurrent test still launches 32 requests internally. Both new tests run three times, and the interrupted-render cleanup test receives three additional runs. Every run must pass; a failure stops its step immediately. Existing signal diagnostics remain enabled, and the existing test coverage is retained. The expected CI execution count is 239 test invocations covering 232 distinct Swift tests, plus the unchanged 219 Python tests. These repeated successful-run requirements are stress checks, not retries after a failure.

Original generated images are used for all fixtures. No private reference image, raw diagnostic, or proprietary asset is committed. No version, tag, release workflow, registry publication, or Homebrew change is included.
