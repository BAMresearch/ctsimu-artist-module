+ Weiter bei:
	- Source: ComputeSpectrum
	- loading external spectrum files

+ Implement detector properties -> aRTist
	- efficiency (replaces sensitivity?)
	- SNR curve
	- Unsharpness mode, mtf10frequency, MTF file
	- Should a change in the beam current cause a detector-re-generation? (imin/imax mode) No -> be more explicit in JSON scenario documentation.
+ Implement source properties -> aRTist

+ aRTist-specific JSON parameters
+ Flat Field Correction, Dark Field Correction
+ Primary Energies Mode
+ FF correction script
+ Recon Configs & Projection Matrix Generation

+ Scattering: only simulate McRay scatter image every n degrees.

# Future
+ Materials manager / JSON: chemical composition: number fractions vs. mass fractions
+ Replace `json new` by `json` once aRTist has updated rl_json version.