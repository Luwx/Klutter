## 0.0.2

* Renamed the package from `kwin_blur` to `background_blur_linux`: the Wayland
  blur protocol is no longer KWin-specific.
* Prefer the standardized `ext_background_effect_v1` protocol (KWin Plasma
  6.7+), falling back to the legacy `org_kde_kwin_blur` protocol on older
  compositors. The active backend is chosen at runtime based on the
  compositor's advertised capabilities.
* Whole-window blur (null/empty region) now tracks window resizes on both
  protocols. On `ext_background_effect_v1` it uses an oversized region that the
  compositor clips to the surface, since a null region there removes the effect
  rather than meaning "whole window".

