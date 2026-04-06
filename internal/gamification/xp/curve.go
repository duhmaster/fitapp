package xp

import "encoding/json"

// Curve is loaded from gamification_settings.xp_curve (admin-tunable).
type Curve struct {
	VolumeDivisor   float64 `json:"volume_divisor"`
	CompletionBonus int     `json:"completion_bonus"`
	VolumeMax       int     `json:"volume_max"`
}

// DefaultCurve matches Flutter XpCalculationService defaults.
func DefaultCurve() Curve {
	return Curve{VolumeDivisor: 50, CompletionBonus: 10, VolumeMax: 500}
}

// CurveFromJSON unmarshals settings JSON; invalid fields fall back to defaults.
func CurveFromJSON(raw []byte) Curve {
	d := DefaultCurve()
	if len(raw) == 0 {
		return d
	}
	var c Curve
	if err := json.Unmarshal(raw, &c); err != nil {
		return d
	}
	if c.VolumeDivisor <= 0 {
		c.VolumeDivisor = d.VolumeDivisor
	}
	if c.CompletionBonus < 0 {
		c.CompletionBonus = d.CompletionBonus
	}
	if c.VolumeMax <= 0 {
		c.VolumeMax = d.VolumeMax
	}
	return c
}

// DeltaFromVolume applies volume divisor, clamp, and completion bonus (same semantics as Flutter preview).
func DeltaFromVolume(totalVolumeKg float64, c Curve) int {
	bonus := c.CompletionBonus
	if totalVolumeKg <= 0 {
		return bonus
	}
	div := c.VolumeDivisor
	if div <= 0 {
		div = 50
	}
	base := int(totalVolumeKg / div)
	if base < 1 {
		base = 1
	}
	if base > c.VolumeMax {
		base = c.VolumeMax
	}
	return base + bonus
}
