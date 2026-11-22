#ifndef RUNNER_GPU_PROBE_H_
#define RUNNER_GPU_PROBE_H_

// Prepares rendering before the engine starts. On a GPU of Direct3D feature
// level 10_0 (a GeForce 9800 GT) ANGLE offers only OpenGL ES 2 and Flutter
// draws a black window, so ANGLE is told to allow ES 3 there; other GPUs do
// not use that feature. The GPU's level and the outcome are left in
// NUR_CONNECT_RENDERER_INFO for the app's log.
void PrepareRenderer();

#endif  // RUNNER_GPU_PROBE_H_
