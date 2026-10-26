# Ball flight physics (WP5)

`SwingLabCore/BallFlight.swift` simulates **carry** for user-entered launch conditions. Every output is `.simulated`. SwingLab never fills the inputs from video: one iPhone camera does not observe ball speed, launch angle, or spin (v6.0 §2, §12, §13).

## Model

Point mass, RK4 for position/velocity with a 1 ms step; spin decay currently uses a first-order Euler step. Axes: x forward along the target line, y up, z right. API launch angles and spin are explicitly degrees/rpm; typed output metrics use SI (including radians), converted by the renderer.

| Term | Form |
|---|---|
| Gravity | 9.806 65 m/s² |
| Drag | −½ ρ A C_D \|v_rel\| v_rel / m |
| Magnus lift | ½ ρ A C_L \|v_rel\|² (ω̂ × v̂_rel) / m. Only the spin component perpendicular to the airflow contributes. |
| Spin decay | dω/dt = −k ω V / r, with k = 2 × 10⁻⁵ |
| Wind | Uniform with height; v_rel = v − wind |
| Ball | m = 0.045 93 kg, d = 0.042 67 m (USGA mass maximum, diameter minimum) |
| Air density | Moist air as ideal-gas mixture; saturation vapour pressure from the Magnus form (Alduchov & Eskridge 1996): 610.94 · exp(17.625 T / (T + 243.04)) Pa, T in °C |

### Aerodynamic coefficients

With spin ratio S = r ω / V:

- C_D = 0.24 + 0.18 S
- C_L = 0.54 S^0.4

Source: Smits, A. J. & Smith, D. R. (1994), "A new aerodynamic model of a golf ball in flight", *Science and Golf II*, pp. 340–347. The coefficients and the spin-decay constant are as widely quoted in secondary literature. **They have not been checked against the primary paper in this repository.** The original model also includes a Reynolds-number term in drag, which is omitted here.

## Validation

### Integrator

With drag, lift, and decay set to zero (`AeroCoefficients.vacuum`), range, apex, flight time, and landing angle match the closed-form projectile within 1 cm / 2 ms / 0.01° at 10°, 30°, and 45°.

### Reference shots

Reference: the **older** [TrackMan PGA Tour averages table hosted by TrackMan support](https://support.trackmangolf.com/hc/en-us/article_attachments/7349802113051). The official indexed table was checked on 26 October 2026; the web tool could not open the full 20 MB PDF. The indexed rows confirm the launch/carry/apex reference values below and correct the driver's landing angle to **38°**. These are not current tour averages: [TrackMan published an updated dataset in May 2024](https://www.trackman.io/blog/introducing-updated-tour-averages). Simulation conditions: standard atmosphere here (20 °C, 101 325 Pa, 50 % RH), no wind, flat landing. An aggregate of separate averages is not a measured flight with matched atmospheric conditions, so these are regression comparisons, not calibration or proof of accuracy.

| Shot | Inputs | Carry | Apex | Landing angle |
|---|---|---|---|---|
| Driver | 167 mph, 10.9°, 2686 rpm | 273.0 yd vs 275 (**−0.7 %**) | 42.3 yd vs 32 (**+32 %**) | 43.3° vs 38° |
| 7-iron | 120 mph, 16.3°, 7097 rpm | 186.6 yd vs 172 (**+8.5 %**) | 38.1 yd vs 32 (**+19 %**) | 46.2° vs 50° |

**Finding:** this coefficient implementation predicts higher apexes and longer iron carry than these averages. The discrepancy alone does not isolate lift as the cause: omitted drag dependence, ball construction, atmosphere, and averaging can also contribute. The lift-only causal attribution in the reviewer report was not demonstrated.

No single adjustment fixes both clubs. A sensitivity run (not committed as a model) found:

- Scaling C_L by 0.8 fixes the driver apex but drops driver carry by 7 %.
- Adding 0.05 to C_D fixes 7-iron carry but drops driver carry by 12 %.

Fitting coefficients to the same averages used for validation would be circular, so the model is left as cited.

The tests assert:
- driver carry within ±5 %;
- 7-iron carry within ±10 %;
- apex only within a wide bound.

These are documented gaps, not targets.

Other checks: spin-axis symmetry, start direction (lateral ≈ forward · tan 5°), headwind/tailwind/crosswind direction, thinner air → longer carry (≈ 1 600 m and 30 °C: driver 299 yd), humid air is less dense than dry air, dry air at 15 °C is 1.225 kg/m³, uphill/downhill landing, invalid inputs.

## Not modelled

- Roll, bounce, and turf interaction. Carry only.
- Wind shear with height.
- Reynolds-number dependence of drag.
- Spin-axis precession.
- Ball-to-ball manufacturing differences.

## Next steps for review

- Verify the coefficients against the primary Smits & Smith paper.
- Compare with other published C_L(S) and C_D(S, Re) data, such as Bearman & Harvey (1976) wind-tunnel measurements.
- Consider a lift model that saturates at high S.
- Validate against measured launch-monitor flights, not averages.

## Round 3 source assessment

**Partially agree** with leaving coefficients unchanged rather than fitting to the validation averages. The simplified equations remain unverified against the 1994 primary paper; naming this implementation the complete published model overstates the evidence. It is an experimental, secondhand approximation with known omissions, not a validated aerodynamic model.

A better-cited candidate is Lyu, Kensrud, Smith & Tosaya (2018), [*Aerodynamics of Golf Balls in Still Air*, Proceedings 2(6), 238, DOI 10.3390/proceedings2060238](https://pdfs.semanticscholar.org/595d/3d1f91e240cb47e153b8d0ef586b8caa67c4.pdf), §§3.1–3.2: ball-specific piecewise polynomial **C_D(Re)** and quadratic **C_L(S)** fits. The primary paper reports 13 production ball models; lift measurements span 32–91 m/s and 1,500–4,500 rpm. Its text does not tabulate a universal coefficient set. A 7,097 rpm iron launch exceeds the measured spin range; blindly extrapolating a selected quadratic is not justified. A future implementation should obtain the ball-specific fit data and limits, version the selected model, and validate against independent measured flights. No replacement coefficients were invented or fitted this round.

Regression corrections: level/downward launches on a flat landing plane now return immediate contact (zero carry/time), instead of integrating underground for 20 seconds and reporting unreachable landing. Nonfinite/negative custom aerodynamic parameters are rejected. `BallFlightTests.testLevelAndDownwardLaunchTouchFlatGroundImmediately` and `testInvalidOrUnreachableInputsThrow` cover these cases.
