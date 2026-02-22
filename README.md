![screenshot](assets/2026-01-01_01.25.04.png)
<sub><sup>Resource pack used: AVPBR Retextured R5</sup></sub>

<font size="6"><h1 align = "center">⭐ zephyr-starlight</h1></font>
<font size="3"><p align = "center">Experimental real-time path traced shaderpack for Minecraft</p></font>

> [!WARNING]
> Disclaimer: This shaderpack is an early work-in-progress so 
> bugs, missing features and performance issues are to be expected.

# Information

* Download: https://modrinth.com/shader/zephyr-starlight
* Minecraft 1.21+ and Iris 1.9+ is recommended. OptiFine is not supported
* For suggestions, ideas and discussions related to this shaderpack, head over to the `#zephyr-starlight-kirilpro` channel in the [shaderLABS](https://discord.gg/RpzWN9S) Discord server.
* You can support me by becoming a patron: https://www.patreon.com/Kirilpro6284

## Features

* Accurate ray-geometry intersection
* Path traced diffuse, reflections and sun shadows
* Temporal anti-aliasing and upsampling
* Normal & specular mapping support
* Physically based sky rendering
    * Hillaire multi-scattering approximation
* Sparse irradiance cache for diffuse multi-bounce approximation
* Reflection motion vector calculation (no TAA ghosting on reflections)
* Spatiotemporal denoising
* Camera effects: motion blur & depth of field
* Post-processing: auto exposure & chromatic aberration

## Acknowledgements

* [lucysir](https://github.com/kadir014) - Blue noise sampling for path tracing
* [jbritain](https://github.com/jbritain) - AMD support, blue noise texture (https://discordapp.com/channels/237199950235041794/525510804494221312/1416364500591837216)
* [agentclone8](https://github.com/agentclone8) - BRDF Function
* [sixthsurge](https://github.com/sixthsurge) - Text rendering for debugging
* [Player2950](https://github.com/ArslanShakirov) - Playtesting

## Compatibility / Mod Support

* GPUs: NVIDIA, AMD
* Minecraft - version 1.21 and above
* Iris - version 1.8.0 and above
* Optifine - not supported
* Distant Horizons/Voxy - not supported (planned)
* OrthoCamera - supported but still broken in a few cases
* macOS - not supported

## Performance Tips

* Sample count: This directly affects the quality of the lighting. Higher sample counts show less noise and more detailed lighting/reflections at the cost of performance. Keep this at 1 for the best performance.
* Diffuse Lighting > Denoising Passes: The amount of passes used for diffuse lighting denoising. Even though not as high as sample count, this has a performance impact too. You can still get decent lighting with just 6 passes most of the time, but a pass count of 8 is recommended for the best lighting. You can set this to 0 if you're fine with the noise.
* If you are in a completely closed room with no outdoor light entering it, set Shadow Samples to 0. This will disable sunlight.
* Irradiance Cache > Update Interval: The maximum amount of frames that are allowed to pass between updates of the same part of the irradiance cache. Lower values cost more performance, but result in more responsive lighting and less noise in reflections.

## TODO / Known Issues

* ~~TAAU looks *very* bad currently. I don't recommend using it unless you really need FPS.~~
* ~~Currently, you need a labPBR resource pack enabled for this shaderpack to function properly.~~
* Rain particles are not rendered.
* Reflections (especially mirror-like ones) show a lot of noise and flickering. Lowering Irradiance Cache -> Update Interval and increasing reflection samples in path tracing settings can improve it.
* The shaderpack takes very long to load on first use, but it should be faster on subsequent loads.
* Normal maps don't show up in reflections.
* Breaking blocks in caves shows light leaking for a split second. This is unavoidable now.
* In some cases, parts of the terrain will fail to voxelize. Increasing Triangle and Voxel Array Size usually fixes it.
* ~~TAA produces a lot of ghosting on smooth reflections in movement. It might be possible to improve on this by using a reflection virtual depth buffer for TAA reprojection.~~

## License

* This project is available under the [Creative Commons BY-NC-SA 4.0 International](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.en) license. [View full license text](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.txt)
